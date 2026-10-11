import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:screenshot/screenshot.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

class MainReceipt {
  // [FIX] We use a single ScreenshotController to capture the ENTIRE Arabic portion of the receipt at once.
  // Previously, capturing 15 micro-screenshots caused extreme lag and produced blank images if 
  // the context was obstructed. 
  static final ScreenshotController _screenshotController = ScreenshotController();

  static Future<List<int>> generate(
    Map<String, dynamic> data,
    String orderId, {
    BuildContext? context,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // Data Extraction
    final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    double cashAmount = (data['cashAmount'] as num?)?.toDouble() ?? 0.0;
    double creditAmount = (data['creditAmount'] as num?)?.toDouble() ?? 0.0;
    final double balance = (data['balance'] as num?)?.toDouble() ?? 0.0;

    // [FIX] For customer app orders (printed from order_page), cashAmount/creditAmount 
    // are not explicitly stored in the order document. If both are zero, determine 
    // payment method (cash vs card/credit) and assign totalAmount accordingly so cash isn't shown as zero.
    if (cashAmount == 0 && creditAmount == 0 && totalAmount > 0) {
      final String paymentMethod =
          (data['paymentMethod']?.toString().toLowerCase() ?? '');
      if (paymentMethod.contains('card') ||
          paymentMethod.contains('credit') ||
          paymentMethod.contains('online')) {
        creditAmount = totalAmount;
      } else {
        cashAmount = totalAmount; // Default to Cash (e.g. Cash on Delivery)
      }
    }
    final List<dynamic> items = data['items'] ?? [];
    final String orderType = data['orderType'] ?? 'Takeaway';
    final int? tokenNumber = data['tokenNumber'] != null ? int.tryParse(data['tokenNumber'].toString()) : null;
    final String tableId = data['tableId']?.toString() ?? '';
    final String customerName = data['customerName']?.toString() ?? '';
    final String phone = data['phone']?.toString() ?? '';
    final String address = data['address']?.toString() ?? '';
    
    DateTime orderDate = DateTime.now();
    if (data['createdAt'] != null) {
      try {
        orderDate = data['createdAt'].toDate();
      } catch (_) {
        if (data['createdAt'] is String) {
          orderDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
        }
      }
    }

    // 1. Logo
    await _addLogo(bytes);

    // 2. English/Native Text Details
    if (tokenNumber != null) {
       bytes += generator.text('Token: #$tokenNumber', styles: const PosStyles(bold: true, align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
       bytes += generator.emptyLines(1);
    }
    
    bytes += generator.text('Order ID: $orderId', styles: const PosStyles(bold: true));
    bytes += generator.text('Type: $orderType', styles: const PosStyles(bold: true));
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(orderDate)}');

    if (customerName.isNotEmpty) bytes += generator.text('Customer: $customerName', styles: const PosStyles(bold: true));
    if (phone.isNotEmpty) bytes += generator.text('Phone: $phone', styles: const PosStyles(bold: true));
    if (address.isNotEmpty) bytes += generator.text('Address: $address', styles: const PosStyles(bold: true));
    if (tableId.isNotEmpty && orderType == 'Dine In') bytes += generator.text('Table: $tableId', styles: const PosStyles(bold: true));

    bytes += generator.feed(1);

    // 3. Arabic & Graphic Content (Rendered as a single image to guarantee font/Riyal icon support)
    final Widget receiptWidget = _buildPrinterCanvas(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'RECEIPT\nإيصال',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, height: 1.2),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.black, thickness: 2),
          Row(
            children: const [
              Expanded(flex: 3, child: Text('Item / الصنف', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))),
              Expanded(flex: 1, child: Text('Qty / الكمية', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))),
              Expanded(flex: 2, child: Text('Price / السعر', textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))),
            ],
          ),
          const Divider(color: Colors.black, thickness: 2),
          ...items.map((item) {
            // [FIX] Extracted exactly matching the original web_project data structure (e.g. pdtname instead of nameEn).
            // Without these exact keys, everything resulted in "Unknown Item".
            final String titleEn = item['pdtname'] ?? item['nameEn'] ?? item['title'] ?? 'Unknown Item';
            final String titleAr = item['arabicName'] ?? item['nameAr'] ?? item['titleAr'] ?? '';
            final int qty = (double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0).toInt();

            // [FIX] Base price plus all positive and negative modifier prices exactly like old code
            // PLUS dynamically adding POS addon Map prices since they aren't in 'addOnPrice'
            double rate = (double.tryParse(item['price']?.toString() ?? '0') ?? 0) +
                (double.tryParse((item['addOnPrice'] ?? 0).toString()) ?? 0) +
                (double.tryParse((item['addMorePrice'] ?? 0).toString()) ?? 0) -
                (double.tryParse((item['addLessPrice'] ?? 0).toString()) ?? 0) -
                (double.tryParse((item['removePrice'] ?? 0).toString()) ?? 0);

            // Dynamically sum the prices from POS format Add-on Maps
            List rawAddonsPrice = item['addons'] ?? item['selectedAddons'] ?? [];
            for (var a in rawAddonsPrice) {
              if (a is Map) {
                rate += double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
              }
            }
            
            final double finalPrice = rate * qty;

            // [FIX] Extracted Add-ons properly handling BOTH the POS app's structure (Maps) and Online structure (Strings)
            List<String> unifiedAddonsEn = [];
            List<String> unifiedAddonsAr = [];

            // 1. POS Format (List of Maps)
            List rawAddons = item['addons'] ?? item['selectedAddons'] ?? [];
            for (var a in rawAddons) {
              if (a is Map) {
                String en = (a['nameEn']?.toString() ?? a['name']?.toString() ?? '').trim();
                String ar = (a['nameAr']?.toString() ?? a['arabicName']?.toString() ?? '').trim();
                // Strip any leading or trailing '+' signs already in the database
                en = en.replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), '');
                ar = ar.replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), '');
                if (en.isNotEmpty) unifiedAddonsEn.add(en);
                if (ar.isNotEmpty) unifiedAddonsAr.add(ar);
              } else if (a is String && a.trim().isNotEmpty) {
                String str = a.trim().replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), '');
                if (str.isNotEmpty) unifiedAddonsEn.add(str);
              }
            }

            // 2. Online Format (List of Strings)
            List pdtAddOn = item['addOns'] ?? [];
            List pdtChoice = item['choice'] ?? [];
            List pdtOnlyOne = item['onlyOne'] ?? [];
            List pdtRemove = item['remove'] ?? [];
            List pdtAddMore = item['addMore'] ?? [];
            List pdtAddLess = item['addLess'] ?? [];

            List pdtAddOnAr = item['addOnArabic'] ?? [];
            List pdtChoiceAr = item['choiceArabic'] ?? [];
            List pdtOnlyOneAr = item['onlyOneArabic'] ?? [];
            List pdtRemoveAr = item['removeArabic'] ?? [];
            List pdtAddMoreAr = item['addMoreArabic'] ?? [];
            List pdtAddLessAr = item['addLessArabic'] ?? [];

            if (pdtAddOn.isNotEmpty) unifiedAddonsEn.add(pdtAddOn.join(", "));
            if (pdtChoice.isNotEmpty) unifiedAddonsEn.add(pdtChoice.join(", "));
            if (pdtOnlyOne.isNotEmpty) unifiedAddonsEn.add(pdtOnlyOne.join(", "));
            if (pdtRemove.isNotEmpty) unifiedAddonsEn.add("- ${pdtRemove.join(", ")}");
            // Do not prefix with '+' since items are already joined by ' + '
            if (pdtAddMore.isNotEmpty) unifiedAddonsEn.add(pdtAddMore.join(", "));
            if (pdtAddLess.isNotEmpty) unifiedAddonsEn.add("- ${pdtAddLess.join(", ")}");

            if (pdtAddOnAr.isNotEmpty) unifiedAddonsAr.add(pdtAddOnAr.join(", "));
            if (pdtChoiceAr.isNotEmpty) unifiedAddonsAr.add(pdtChoiceAr.join(", "));
            if (pdtOnlyOneAr.isNotEmpty) unifiedAddonsAr.add(pdtOnlyOneAr.join(", "));
            if (pdtRemoveAr.isNotEmpty) unifiedAddonsAr.add("بدون ${pdtRemoveAr.join(", ")}");
            if (pdtAddMoreAr.isNotEmpty) unifiedAddonsAr.add("زيادة ${pdtAddMoreAr.join(", ")}");
            if (pdtAddLessAr.isNotEmpty) unifiedAddonsAr.add("تقليل ${pdtAddLessAr.join(", ")}");

            // Strip any remaining leading/trailing '+' signs from each modifier
            String modsEn = unifiedAddonsEn
                .map((s) => s.trim().replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), ''))
                .where((s) => s.isNotEmpty)
                .join(" + ");
            String modsAr = unifiedAddonsAr
                .map((s) => s.trim().replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), ''))
                .where((s) => s.isNotEmpty)
                .join(" + ");

            // Join English and Arabic with a single '+', and collapse any accidental double '++'
            String allMods = [modsEn, modsAr].where((s) => s.isNotEmpty).join(" + ");
            allMods = allMods.replaceAll(RegExp(r'\s*\+\s*(\+\s*)+'), ' + ').trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titleEn, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, height: 1.0)),
                            if (titleAr.isNotEmpty)
                              Text(titleAr, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
                            if (allMods.isNotEmpty)
                              Text('($allMods)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Image.asset('assets/images/saudi_riyal.png', height: 12, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(finalPrice.toStringAsFixed(2), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(color: Colors.black, thickness: 2),
          _buildTotalRow('Total / الإجمالي', totalAmount, isHuge: true),
          _buildTotalRow('Cash / نقدي', cashAmount),
          if (creditAmount > 0) _buildTotalRow('Credit / بطاقة ائتمان', creditAmount),
          _buildTotalRow('Balance / المتبقي', balance),
          const Divider(color: Colors.black, thickness: 2),
          const SizedBox(height: 8),
          const Text('Thank you for your visit!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('شكراً لزيارتكم!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
        ],
      ),
    );

    // Capture the entire Arabic section as one single image to fix bugs & speed up!
    // Notice we do NOT pass context to prevent UI overlapping/blank screens!
    final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
      receiptWidget,
      delay: const Duration(milliseconds: 100),
    );

    if (imageBytes != null) {
      final img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        bytes.addAll(_imageToEscPosRaster(decoded));
      }
    }

    bytes += generator.feed(2);
    return bytes;
  }

  static Widget _buildTotalRow(String label, double amount, {bool isHuge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: isHuge ? 20 : 16),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/saudi_riyal.png', height: isHuge ? 16 : 12, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  amount.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: isHuge ? 22 : 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPrinterCanvas({required Widget child}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.white,
        child: Container(
          width: 384, // 80mm printer
          color: Colors.white,
          child: child,
        ),
      ),
    );
  }

  static Future<void> _addLogo(List<int> bytes) async {
    try {
      final ByteData data = await rootBundle.load('assets/images/rest.jpg');
      final Uint8List imgBytes = data.buffer.asUint8List();
      final img.Image? decodedImage = img.decodeImage(imgBytes);
      if (decodedImage != null) {
        img.Image resized = img.copyResize(decodedImage, width: 250, maintainAspect: true);
        bytes.addAll(_imageToEscPosRaster(resized));
      }
    } catch (e) {
      print("Could not load logo: $e");
    }
  }

  static List<int> _imageToEscPosRaster(img.Image fullImage) {
    List<int> bytes = [];
    int width = fullImage.width;
    int widthBytes = (width + 7) ~/ 8;

    bytes.addAll([27, 97, 1]); // Center alignment
    
    // [FIX] Slice the image into 200px chunks. Thermal printers have small raster buffers.
    // Sending an image taller than 255-500px in a single GS v 0 command causes it to freeze or drop bytes (no cut).
    int chunkHeight = 200; 

    for (int startY = 0; startY < fullImage.height; startY += chunkHeight) {
      int currentHeight = (startY + chunkHeight > fullImage.height) 
          ? (fullImage.height - startY) 
          : chunkHeight;

      bytes.addAll([29, 118, 48, 0, widthBytes % 256, widthBytes ~/ 256, currentHeight % 256, currentHeight ~/ 256]);

      for (int y = startY; y < startY + currentHeight; y++) {
        for (int x = 0; x < widthBytes; x++) {
          int byte = 0;
          for (int bit = 0; bit < 8; bit++) {
            int pixelX = x * 8 + bit;
            if (pixelX < width) {
              img.Pixel pixel = fullImage.getPixel(pixelX, y);
              int r = pixel.r.toInt();
              int g = pixel.g.toInt();
              int b = pixel.b.toInt();
              int luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
              if (luminance < 128) byte |= (1 << (7 - bit));
            }
          }
          bytes.add(byte);
        }
      }
    }
    return bytes;
  }
}

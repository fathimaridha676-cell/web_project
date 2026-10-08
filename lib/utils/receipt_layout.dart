import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:screenshot/screenshot.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

/// This class is responsible ONLY for generating the layout bytes for an Order Receipt.
/// It uses the Generator approach: ultra-fast raw text mixed with screenshots for Arabic.
class OrderReceiptLayout {
  // A static controller used to screenshot Arabic text when needed
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  /// Generates the raw ESC/POS byte array for this specific receipt layout.
  static Future<List<int>> generate(
    Map<String, dynamic> data,
    String orderId, {
    BuildContext? context,
  }) async {
    // 1. Initialize the ESC/POS generator for an 80mm thermal printer
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = []; // This array will hold all our printer commands

    // Reset the printer hardware to its default state to prevent "small text" bugs
    bytes += generator.reset();

    // --- Data Extraction ---
    final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> items = data['items'] ?? [];
    final String orderType = data['orderType'] ?? 'Takeaway';

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

    // --- RECEIPT HEADER ---
    // Sending raw text commands to the printer. This is incredibly fast.
    bytes += generator.text(
      'ORDER RECEIPT',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.feed(1); // Empty line

    bytes += generator.text(
      'Order #: ${orderId.toUpperCase()}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text('Type: $orderType');
    bytes += generator.text(
      'Date: ${DateFormat('MMM d, yyyy h:mm a').format(orderDate)}',
    );
    bytes += generator.hr(); // Draws a horizontal dashed line across the paper

    // --- TABLE HEADERS ---
    // We use generator.row() to mathematically divide the 80mm paper width (total width = 12)
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: 'Price',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    bytes += generator.hr();

    // --- ITEM LIST (The Hybrid Magic) ---
    for (var item in items) {
      final String titleEn = item['nameEn'] ?? item['title'] ?? 'Item';
      final String? titleAr =
          item['nameAr']; // Used if the item has an Arabic translation
      final int qty = item['quantity'] ?? 1;

      final double basePrice = (item['price'] as num?)?.toDouble() ?? 0.0;
      final List<dynamic> addons =
          item['addons'] ?? item['selectedAddons'] ?? [];

      double addonsTotal = 0.0;
      List<String> addonNames = [];
      for (var addon in addons) {
        addonsTotal += (addon['price'] as num?)?.toDouble() ?? 0.0;
        String addonName = addon['nameEn'] ?? addon['title'] ?? 'Addon';
        addonNames.add(addonName);
      }
      final double finalPrice = basePrice + addonsTotal;

      // Print English details instantly as raw text
      bytes += generator.row([
        PosColumn(text: titleEn, width: 6),
        PosColumn(
          text: '$qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: '\$${(finalPrice * qty).toStringAsFixed(2)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      if (addonNames.isNotEmpty) {
        bytes += generator.text(
          '+ ${addonNames.join(", ")}',
          styles: const PosStyles(), // Removed fontB to keep standard size
        );
      }

      // If there is an Arabic name, capture it as an image and print it underneath!
      if (titleAr != null && titleAr.isNotEmpty) {
        await _addArabicText(titleAr, generator, bytes, context: context);
      }
    }

    bytes += generator.hr();

    // --- TOTALS ---
    bytes += generator.row([
      PosColumn(
        text: 'Total',
        width: 6,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: '\$${totalAmount.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.text(
      'Thank you for your order!',
      styles: const PosStyles(align: PosAlign.center),
    );

    // --- HARDWARE COMMANDS ---
    // Injecting physical hardware commands into the byte stream
    bytes += generator.feed(2); // Pushes paper out past the blade
    bytes += generator.cut(); // Tells the printer to physically cut the paper
    // bytes += generator.drawer(pin: PosDrawer.pin2); // Uncomment this to pop the cash drawer!

    // Return the final compiled list of commands
    return bytes;
  }

  /// Helper function: Converts Arabic text to a widget, takes a screenshot, and adds the image bytes.
  static Future<void> _addArabicText(
    String text,
    Generator generator,
    List<int> bytes, {
    BuildContext? context,
  }) async {
    print("DEBUG: _addArabicText started for text: $text");

    // 1. Build a tiny invisible widget for this single string
    final textWidget = MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: Colors.white,
          child: Container(
            width: 384, // Approximate 80mm pixel width
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              text,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );

    print("DEBUG: Taking screenshot of Arabic text...");
    // 2. Take a screenshot of it
    final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
      textWidget,
      delay: const Duration(milliseconds: 50),
      context: context,
    );
    print("DEBUG: Screenshot completed. bytes == null? ${imageBytes == null}");

    if (imageBytes != null) {
      final img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        // Resize for printer compatibility
        img.Image resized = img.copyResize(
          decoded,
          width: 500,
          maintainAspect: true,
        );

        // Use custom ESC/POS image raster generator to bypass esc_pos_utils_plus bug
        bytes.addAll(_imageToEscPosRaster(resized));
      }
    }
  }

  /// Custom ESC/POS image raster generator to bypass the FixedLengthList exception in esc_pos_utils_plus
  static List<int> _imageToEscPosRaster(img.Image image) {
    List<int> bytes = [];
    int width = image.width;
    int height = image.height;
    int widthBytes = (width + 7) ~/ 8;

    // Center alignment command
    bytes.addAll([27, 97, 1]);

    // GS v 0 (print raster image)
    // 29 = GS, 118 = v, 48 = 0, 0 = normal mode
    bytes.addAll([
      29,
      118,
      48,
      0,
      widthBytes % 256,
      widthBytes ~/ 256,
      height % 256,
      height ~/ 256,
    ]);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < widthBytes; x++) {
        int b = 0;
        for (int k = 0; k < 8; k++) {
          int pixelX = x * 8 + k;
          if (pixelX < width) {
            final pixel = image.getPixel(pixelX, y);
            // Convert to grayscale luminance
            double luminance =
                0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
            // If it's dark, print a black dot
            if (luminance < 128) {
              b |= (1 << (7 - k));
            }
          }
        }
        bytes.add(b);
      }
    }

    // Reset alignment to left
    bytes.addAll([27, 97, 0]);

    return bytes;
  }
}

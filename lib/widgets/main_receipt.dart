import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:screenshot/screenshot.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import '../models/receipt_order_model.dart';
import '../constants/app_images.dart';

class MainReceipt {
  // ScreenshotController instance used to photograph the in-memory widgets
  static final ScreenshotController screenshotController =
      ScreenshotController();

  // Width in thermal dots (576 dots is the standard 80mm head width)
  static const int _printerWidth = 576;

  // Number of items per screenshot chunk, identical to itemCount in mainBillCopy
  static const int _itemsPerImage = 4;

  // Path to the Saudi Riyal currency icon asset from centralized AppIcons/AppImages
  static const String _riyalAsset = AppIcons.saudiRiyal;

  // Cached logo bytes in memory (exact mainBillCopy method)
  static Uint8List? preloadedImage;

  /// Call once at app startup or before printing to preload the logo into RAM
  static Future<void> preloadLogo() async {
    try {
      final ByteData data = await rootBundle.load(AppImages.restaurantLogo);
      preloadedImage = data.buffer.asUint8List();
    } catch (e) {
      print("Could not preload logo: $e");
    }
  }

  /// Primary generate method accepting the strongly-typed ReceiptOrderModel.
  /// Keeps MainReceipt purely responsible for layout, raster byte generation, and paper cutting.
  static Future<List<int>> generate(
    ReceiptOrderModel receiptOrderModel, {
    bool cut =
        true, // Default to true so callers receive a ready-to-print, cut receipt
  }) async {
    // 0. Ensure restaurant logo is loaded into memory if not already cached
    if (preloadedImage == null) {
      await preloadLogo();
    }

    // 1. Initialize printer capability profile and ESC/POS generator
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Send ESC/POS hardware reset command
    bytes += generator.reset();

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1: HEADER CAPTURE ( uses .then() exactly like mainBillCopy)
    // ─────────────────────────────────────────────────────────────────────────
    Uint8List? headerCapture;
    screenshotController
        .captureFromWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.white,
              child: Container(
                width: _printerWidth.toDouble(),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    // Main Receipt bilingual title
                    Text(
                      'RECEIPT\nإيصال',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Divider(color: Colors.black, thickness: 2),
                    // Table header row: Item, Qty, Price
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Item / الصنف',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Qty / الكمية',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Price / السعر',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.black, thickness: 2),
                  ],
                ),
              ),
            ),
          ),
          pixelRatio: 2.0, // 2x resolution to keep Arabic text sharp
          delay: const Duration(milliseconds: 100),
        )
        // Store output via callback without blocking the main execution thread
        .then((value) => headerCapture = value);

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2: ITEMS CHUNKING & CAPTURES (Streamlined with ReceiptItemModel)
    // ─────────────────────────────────────────────────────────────────────────
    List<Widget> itemWidgetsBatch = [];
    List<Uint8List> itemImages = [];
    int itemImageCount = 0; // Tracks expected screenshot count

    for (final item in receiptOrderModel!.items) {
      // Inline Item row widget definition directly using the typed model
      itemWidgetsBatch.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Name Column
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.titleEn,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.0,
                      ),
                    ),
                    if (item.titleAr.isNotEmpty)
                      Text(
                        item.titleAr,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          height: 1.1,
                        ),
                      ),
                    if (item.modifiersText.isNotEmpty)
                      Text(
                        item.modifiersText,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                  ],
                ),
              ),
              // Quantity Column
              Expanded(
                flex: 1,
                child: Text(
                  '${item.qty}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              // Price Column (Riyal icon + total rate)
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(_riyalAsset, height: 16, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      item.finalPrice.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      // Once chunk reaches limit (4 items), capture in background and reset batch
      if (itemWidgetsBatch.length == _itemsPerImage) {
        screenshotController
            .captureFromLongWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: Material(
                  color: Colors.white,
                  child: Container(
                    width: _printerWidth.toDouble(),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        itemWidgetsBatch.length,
                        (index) => itemWidgetsBatch[index],
                      ),
                    ),
                  ),
                ),
              ),
              pixelRatio: 2.0,
              delay: const Duration(milliseconds: 100),
            )
            .then((val) {
              if (val != null) itemImages.add(val);
            });
        itemImageCount++;
        itemWidgetsBatch = [];
      }
    }

    // Capture any remaining items that didn't fill an entire chunk
    if (itemWidgetsBatch.isNotEmpty) {
      screenshotController
          .captureFromLongWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Material(
                color: Colors.white,
                child: Container(
                  width: _printerWidth.toDouble(),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      itemWidgetsBatch.length,
                      (index) => itemWidgetsBatch[index],
                    ),
                  ),
                ),
              ),
            ),
            pixelRatio: 2.0,
            delay: const Duration(milliseconds: 100),
          )
          .then((val) {
            if (val != null) itemImages.add(val);
          });
      itemImageCount++;
      itemWidgetsBatch = [];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 3: FOOTER CAPTURE (Totals + Thank You Messages)
    // ─────────────────────────────────────────────────────────────────────────
    Uint8List? footerCapture;
    screenshotController
        .captureFromWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              color: Colors.white,
              child: Container(
                width: _printerWidth.toDouble(),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(color: Colors.black, thickness: 2),
                    _buildTotalRow(
                      'Total / الإجمالي',
                      receiptOrderModel.totalAmount,
                      isHuge: true,
                    ),
                    _buildTotalRow('Cash / نقدي', receiptOrderModel.cashAmount),
                    if (receiptOrderModel.creditAmount > 0)
                      _buildTotalRow(
                        'Credit / بطاقة ائتمان',
                        receiptOrderModel.creditAmount,
                      ),
                    _buildTotalRow(
                      'Balance / المتبقي',
                      receiptOrderModel.balance,
                    ),
                    const Divider(color: Colors.black, thickness: 2),
                    const SizedBox(height: 8),
                    const Text(
                      'Thank you for your visit!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'شكراً لزيارتكم!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          pixelRatio: 2.0,
          delay: const Duration(milliseconds: 100),
        )
        .then((value) => footerCapture = value);

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 4: THE WHILE LOOP (Waits for all background captures to finish)
    // ─────────────────────────────────────────────────────────────────────────
    while (headerCapture == null ||
        itemImages.length != itemImageCount ||
        footerCapture == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 4: ASSEMBLE BYTES USING imageRaster
    // ─────────────────────────────────────────────────────────────────────────

    // 1. Shop logo (if preloaded)
    if (preloadedImage != null) {
      final img.Image? image = img.decodeImage(preloadedImage!);
      if (image != null) {
        img.Image thumbnail10 = img.copyResize(
          image,
          width: 480,
          height: 200,
          backgroundColor: img.ColorUint8.rgb(255, 255, 255),
          maintainAspect: true,
        );
        bytes += generator.imageRaster(thumbnail10);
        bytes += generator.feed(1);
      }
    }

    // 2. Hardware native English receipt details
    if (receiptOrderModel.tokenNumber != null) {
      bytes += generator.text(
        'Token: #${receiptOrderModel.tokenNumber}',
        styles: const PosStyles(
          bold: true,
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.emptyLines(1);
    }

    bytes += generator.text(
      'Order ID: ${receiptOrderModel.orderId}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      'Type: ${receiptOrderModel.orderType}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      'Date: ${DateFormat('yyyy-MM-dd hh:mm a').format(receiptOrderModel.orderDate)}',
    );

    if (receiptOrderModel.customerName.isNotEmpty) {
      bytes += generator.text(
        'Customer: ${receiptOrderModel.customerName}',
        styles: const PosStyles(bold: true),
      );
    }
    if (receiptOrderModel.phone.isNotEmpty) {
      bytes += generator.text(
        'Phone: ${receiptOrderModel.phone}',
        styles: const PosStyles(bold: true),
      );
    }
    if (receiptOrderModel.address.isNotEmpty) {
      bytes += generator.text(
        'Address: ${receiptOrderModel.address}',
        styles: const PosStyles(bold: true),
      );
    }
    final String printTable = receiptOrderModel.tableNumber.isNotEmpty
        ? receiptOrderModel.tableNumber
        : (receiptOrderModel.tableName.isNotEmpty
            ? receiptOrderModel.tableName
            : receiptOrderModel.tableId);
    if (printTable.isNotEmpty && receiptOrderModel.orderType == 'Dine In') {
      bytes += generator.text(
        'Table: $printTable',
        styles: const PosStyles(bold: true),
      );
    }
    bytes += generator.feed(1);

    // 3. Print Header using imageRaster
    final img.Image? headerDecoded = img.decodeImage(headerCapture!);
    if (headerDecoded != null) {
      img.Image headerResized = img.copyResize(
        headerDecoded,
        width: _printerWidth,
        maintainAspect: true,
      );
      bytes.addAll(generator.imageRaster(headerResized));
    }

    // 4. Print each chunk of items using imageRaster
    for (int i = 0; i < itemImages.length; i++) {
      final img.Image? itemDecoded = img.decodeImage(itemImages[i]);
      if (itemDecoded != null) {
        img.Image itemResized = img.copyResize(
          itemDecoded,
          width: _printerWidth,
          maintainAspect: true,
        );
        bytes.addAll(generator.imageRaster(itemResized));
      }
    }

    // 5. Print Footer using imageRaster
    final img.Image? footerDecoded = img.decodeImage(footerCapture!);
    if (footerDecoded != null) {
      img.Image footerResized = img.copyResize(
        footerDecoded,
        width: _printerWidth,
        maintainAspect: true,
      );
      bytes.addAll(generator.imageRaster(footerResized));
    }

    // Feed paper before cutting
    bytes += generator.feed(2);

    // Encapsulated paper cutting: Executed directly by the receipt widget
    if (cut) {
      bytes += generator.cut();
    }

    // Wrap in List<int>.from to guarantee a growable list
    return List<int>.from(bytes);
  }

  // ──────────────────────── Total Row Builder ────────────────────────
  static Widget _buildTotalRow(
    String label,
    double amount, {
    bool isHuge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: isHuge ? 26 : 20,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  _riyalAsset,
                  height: isHuge ? 20 : 16,
                  color: Colors.black,
                ),
                const SizedBox(width: 4),
                Text(
                  amount.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: isHuge ? 28 : 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


















// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:intl/intl.dart' hide TextDirection;
// import 'package:screenshot/screenshot.dart';
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:image/image.dart' as img;

// /// Main customer receipt, printed the same way as mainBillPrintFunction.
// ///
// /// HOW IT PRINTS NOW (same pipeline as the main bill):
// ///   1. Plain English lines   -> real printer text via generator.text()
// ///   2. Arabic / Riyal parts  -> SEVERAL screenshots (header, item chunks, footer),
// ///                               all started together (parallel), then awaited
// ///   4. Ending                -> (optional) drawer pulse, feed(2), cut()
// ///
// /// Comment tags:
// ///   [KEPT]    identical to the version you sent
// ///   [CHANGED] same job, now done the main-bill way
// ///   [NEW]     did not exist before
// ///   [FIXED]   a bug fixed on the way
// class MainReceipt {
//   // [KEPT] One screenshot "camera" shared by all captures.
//   static final ScreenshotController _screenshotController =
//       ScreenshotController();

//   // [NEW] Printer width in dots. The main bill resizes every picture to 480,
//   // so the receipt does too. (Old receipt: 384, never resized.)
//   // static const int _printerWidth = 480;
//   static const int _printerWidth = 576; // Full 80mm printer width

//   // [NEW] Item rows per screenshot. The main bill does the same with `itemCount`.
//   // Few big captures = fast; many tiny captures = the lag/blank images your old
//   // comment warned about. 4 is a middle ground, raise it if you see blank images.
//   static const int _itemsPerImage = 4;

//   // [KEPT] Old file sliced images into 200px pieces so the printer's small buffer
//   // doesn't freeze. Same rule, now applied before generator.imageRaster().
//   static const int _maxStripHeight = 200;

//   // [NEW] Capture at 2x, shrink to 576 afterwards = sharper Arabic text.
//   static const double _captureScale = 2.0;

//   static const String _riyalAsset = 'assets/images/saudi_riyal.png';

//   static Future<List<int>> generate(
//     Map<String, dynamic> data,
//     String orderId, {
//     BuildContext? context,
//     // [NEW] The main bill always cuts at the end, so the receipt can too.
//     // pos_page.dart ALSO adds its own cut: delete that one (or pass false here),
//     // otherwise the paper is cut twice.
//     // bool cutPaper = false,
//     // [NEW] The main bill always pops the cash drawer. Off by default here so
//     // customer-app orders printed from the orders page don't open it.
//     // bool openDrawer = false,
//   }) async {
//     // [NEW] Preload the Riyal icon so it can't be blank on the first print.
//     // `context` is used ONLY for this, never for the screenshots.
//     if (context != null) {
//       try {
//         await precacheImage(const AssetImage(_riyalAsset), context);
//       } catch (_) {}
//     }

//     // [KEPT] Printer spec sheet + generator for 80mm paper.
//     final profile = await CapabilityProfile.load();
//     final generator = Generator(PaperSize.mm80, profile);
//     List<int> bytes = [];

//     bytes += generator.reset();

//     // ───────────────────────── Data extraction [KEPT] ─────────────────────────
//     final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
//     double cashAmount = (data['cashAmount'] as num?)?.toDouble() ?? 0.0;
//     double creditAmount = (data['creditAmount'] as num?)?.toDouble() ?? 0.0;
//     final double balance = (data['balance'] as num?)?.toDouble() ?? 0.0;

//     // [KEPT] Customer-app orders have no cash/credit saved: put the whole total
//     // under credit (card/online) or cash (cash on delivery).
//     if (cashAmount == 0 && creditAmount == 0 && totalAmount > 0) {
//       final String paymentMethod =
//           (data['paymentMethod']?.toString().toLowerCase() ?? '');
//       if (paymentMethod.contains('card') ||
//           paymentMethod.contains('credit') ||
//           paymentMethod.contains('online')) {
//         creditAmount = totalAmount;
//       } else {
//         cashAmount = totalAmount;
//       }
//     }
//     final List<dynamic> items = data['items'] ?? [];
//     final String orderType = data['orderType'] ?? 'Takeaway';
//     final int? tokenNumber = data['tokenNumber'] != null
//         ? int.tryParse(data['tokenNumber'].toString())
//         : null;
//     final String tableId = data['tableId']?.toString() ?? '';
//     final String customerName = data['customerName']?.toString() ?? '';
//     final String phone = data['phone']?.toString() ?? '';
//     final String address = data['address']?.toString() ?? '';

//     DateTime orderDate = DateTime.now();
//     if (data['createdAt'] != null) {
//       try {
//         orderDate = data['createdAt'].toDate();
//       } catch (_) {
//         if (data['createdAt'] is String) {
//           orderDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
//         }
//       }
//     }

//     // ─────────────── START ALL SCREENSHOTS NOW (parallel) [CHANGED] ───────────
//     // Old: ONE screenshot of everything, taken after the text lines were built.
//     // Now: header + item chunks + footer are all STARTED at the same moment, like
//     // the main bill, and keep running while we build the logo and text lines below.
//     // We do NOT `await` here, we only keep the Futures (the "tickets" for the photos).

//     // Photo 1: "RECEIPT / إيصال" title + column titles.
//     final Future<Uint8List?> headerFuture = _capture(_buildHeaderPart());

//     // Photos 2..N: items, _itemsPerImage rows per photo.
//     final List<Future<Uint8List?>> itemFutures = [];
//     for (int i = 0; i < items.length; i += _itemsPerImage) {
//       final chunk = items.skip(i).take(_itemsPerImage).toList();
//       itemFutures.add(
//         _capture(
//           Column(
//             mainAxisSize: MainAxisSize.min,
//             children: chunk.map(_buildItemRow).toList(),
//           ),
//         ),
//       );
//     }

//     // Last photo: totals + thank-you message.
//     final Future<Uint8List?> footerFuture = _capture(
//       _buildFooterPart(
//         totalAmount: totalAmount,
//         cashAmount: cashAmount,
//         creditAmount: creditAmount,
//         balance: balance,
//       ),
//     );

//     // ──────────────────────── 1. Logo [CHANGED] ───────────────────────────────
//     // pushed bytes with the hand-written raster function.
//     final img.Image? logo = await _loadLogo();
//     if (logo != null) {
//       bytes += _imageToBytes(generator, logo);
//       bytes += generator.feed(1);
//     }

//     // ───────────────── 2. Real printer text (English only) [KEPT] ─────────────
//     // Unchanged: these are real ESC/POS text lines, exactly like the main bill's
//     // "TOKEN NO / INVOICE NO / DATE" lines.
//     if (tokenNumber != null) {
//       bytes += generator.text(
//         'Token: #$tokenNumber',
//         styles: const PosStyles(
//           bold: true,
//           align: PosAlign.center,
//           height: PosTextSize.size2,
//           width: PosTextSize.size2,
//         ),
//       );
//       bytes += generator.emptyLines(1);
//     }

//     bytes += generator.text(
//       'Order ID: $orderId',
//       styles: const PosStyles(bold: true),
//     );
//     bytes += generator.text(
//       'Type: $orderType',
//       styles: const PosStyles(bold: true),
//     );
//     bytes += generator.text(
//       'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(orderDate)}',
//     );

//     if (customerName.isNotEmpty) {
//       bytes += generator.text(
//         'Customer: $customerName',
//         styles: const PosStyles(bold: true),
//       );
//     }
//     if (phone.isNotEmpty) {
//       bytes += generator.text(
//         'Phone: $phone',
//         styles: const PosStyles(bold: true),
//       );
//     }
//     if (address.isNotEmpty) {
//       bytes += generator.text(
//         'Address: $address',
//         styles: const PosStyles(bold: true),
//       );
//     }
//     if (tableId.isNotEmpty && orderType == 'Dine In') {
//       bytes += generator.text(
//         'Table: $tableId',
//         styles: const PosStyles(bold: true),
//       );
//     }

//     bytes += generator.feed(1);

//     // ─────────────── 3. WAIT for every photo [CHANGED] ────────────────────────
//     // Main bill: `while (anyPhotoIsNull) await Future.delayed(200ms)` (could wait forever).
//     // Here: Future.wait does the same "wait until all are done", keeps the results
//     // IN ORDER (header, items 1..N, footer) and gives up after 15 seconds,
//     // so a stuck capture can never freeze printing.
//     final List<Uint8List?> results = await Future.wait<Uint8List?>([
//       headerFuture,
//       ...itemFutures,
//       footerFuture,
//     ]).timeout(const Duration(seconds: 15));

//     // ─────────── 4. Stack the pictures in order [CHANGED] ─────────────────────
//     // Same pattern as the main bill's generateBillBytes():
//     //not using image raster using _imageToBytes function
//     for (final Uint8List? png in results) {
//       final img.Image? picture = _prepare(png);
//       if (picture == null) {
//         print('MainReceipt: one capture was empty, skipped it');
//         continue; // one bad photo no longer blanks the whole receipt
//       }
//       bytes += _imageToBytes(generator, picture);
//     }

//     // ───────────── 5. Ending, same order as the main bill [NEW] ───────────────
//     // Main bill: drawer -> feed(2) -> cut. Old receipt: only feed(2).
//     // if (openDrawer) bytes += generator.drawer(pin: PosDrawer.pin2);
//     bytes += generator.feed(2);
//     // if (cutPaper) bytes += generator.cut();

//     // return bytes;
//     return List<int>.from(bytes);
//   }

//   // ═════════════════════════════ Capture helpers ═══════════════════════════════

//   // [NEW] One place that photographs a widget. captureFromLongWidget (used by the
//   // main bill for its item rows) lets the height grow as tall as needed.
//   // `context` is deliberately NOT passed, so the capture can't clash with the screen.
//   static Future<Uint8List?> _capture(Widget widget) async {
//     try {
//       return await _screenshotController.captureFromLongWidget(
//         _buildPrinterCanvas(child: widget),
//         pixelRatio: _captureScale,
//         delay: const Duration(milliseconds: 100),
//       );
//     } catch (e) {
//       print('MainReceipt capture error: $e');
//       return null;
//     }
//   }

//   // [CHANGED] PNG bytes -> pixels -> exactly 576 wide.

//   static img.Image? _prepare(Uint8List? png) {
//     if (png == null) return null;
//     final img.Image? decoded = img.decodeImage(png);
//     if (decoded == null) return null;
//     return img.copyResize(
//       decoded,
//       width: _printerWidth,
//       maintainAspect: true,
//       interpolation: img.Interpolation.average,
//     );
//   }

//   static List<int> _imageToBytes(Generator generator, img.Image image) {
//     final List<int> out = [];
//     int width = image.width;
//     int widthBytes = (width + 7) ~/ 8;

//     out.addAll([27, 97, 1]); // Center alignment

//     for (int startY = 0; startY < image.height; startY += _maxStripHeight) {
//       int currentHeight = (startY + _maxStripHeight > image.height)
//           ? (image.height - startY)
//           : _maxStripHeight;

//       out.addAll([
//         29,
//         118,
//         48,
//         0,
//         widthBytes % 256,
//         widthBytes ~/ 256,
//         currentHeight % 256,
//         currentHeight ~/ 256,
//       ]);

//       for (int y = startY; y < startY + currentHeight; y++) {
//         for (int x = 0; x < widthBytes; x++) {
//           int byte = 0;
//           for (int bit = 0; bit < 8; bit++) {
//             int pixelX = x * 8 + bit;
//             if (pixelX < width) {
//               img.Pixel pixel = image.getPixel(pixelX, y);
//               int r = pixel.r.toInt();
//               int g = pixel.g.toInt();
//               int b = pixel.b.toInt();
//               int luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
//               if (luminance < 128) byte |= (1 << (7 - bit));
//             }
//           }
//           out.add(byte);
//         }
//       }
//     }
//     return out;
//   }

//   // [CHANGED] Same logo file and size as before, but it now RETURNS the picture
//   // instead of pushing bytes, so it goes through the same _imageToBytes as the rest.
//   static Future<img.Image?> _loadLogo() async {
//     try {
//       final ByteData data = await rootBundle.load('assets/images/rest.jpg');
//       final img.Image? decoded = img.decodeImage(data.buffer.asUint8List());
//       if (decoded == null) return null;
//       return img.copyResize(decoded, width: 250, maintainAspect: true);
//     } catch (e) {
//       print('Could not load logo: $e');
//       return null;
//     }
//   }

//   // ═══════════════════════════ Widgets (photographed) ══════════════════════════

//   // [CHANGED] Top of the old single big widget (title + column titles), now its
//   // own photo. Contents unchanged.
//   static Widget _buildHeaderPart() {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: const [
//         Text(
//           'RECEIPT\nإيصال',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w900,
//             fontSize: 24,
//             height: 1.2,
//           ),
//         ),
//         SizedBox(height: 8),
//         Divider(color: Colors.black, thickness: 2),
//         Row(
//           children: [
//             Expanded(
//               flex: 3,
//               child: Text(
//                 'Item / الصنف',
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontWeight: FontWeight.w900,
//                   fontSize: 20,
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 1,
//               child: Text(
//                 'Qty / الكمية',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontWeight: FontWeight.w900,
//                   fontSize: 20,
//                 ),
//               ),
//             ),
//             Expanded(
//               flex: 2,
//               child: Text(
//                 'Price / السعر',
//                 textAlign: TextAlign.right,
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontWeight: FontWeight.w900,
//                   fontSize: 20,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         Divider(color: Colors.black, thickness: 2),
//       ],
//     );
//   }

//   // [CHANGED] Bottom of the old single big widget (totals + thank you), now its
//   // own photo. Contents unchanged.
//   static Widget _buildFooterPart({
//     required double totalAmount,
//     required double cashAmount,
//     required double creditAmount,
//     required double balance,
//   }) {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         const Divider(color: Colors.black, thickness: 2),
//         _buildTotalRow('Total / الإجمالي', totalAmount, isHuge: true),
//         _buildTotalRow('Cash / نقدي', cashAmount),
//         if (creditAmount > 0)
//           _buildTotalRow('Credit / بطاقة ائتمان', creditAmount),
//         _buildTotalRow('Balance / المتبقي', balance),
//         const Divider(color: Colors.black, thickness: 2),
//         const SizedBox(height: 8),
//         const Text(
//           'Thank you for your visit!',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w900,
//             fontSize: 20,
//           ),
//         ),
//         const SizedBox(height: 4),
//         const Text(
//           'شكراً لزيارتكم!',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.w900,
//             fontSize: 22,
//           ),
//         ),
//         const SizedBox(height: 8),
//       ],
//     );
//   }

//   // [CHANGED] The big `items.map((item) { ... })` block, moved into its own
//   // function so every chunk of items can reuse it.
//   // Logic is the same as your version: only the POS add-on format is read (the
//   // online-order lists block stays removed, as in the file you sent).
//   static Widget _buildItemRow(dynamic item) {
//     // [KEPT] Names: web-project keys first, then the others.
//     final String titleEn =
//         item['pdtname'] ?? item['nameEn'] ?? item['title'] ?? 'Unknown Item';
//     final String titleAr =
//         item['arabicName'] ?? item['nameAr'] ?? item['titleAr'] ?? '';

//     // [FIXED] Old: only item['qty']. The POS cart saves 'quantity', so POS items
//     // printed as qty 1 and the price was not multiplied. Both keys are tried now.
//     final int qty =
//         (double.tryParse(
//                   (item['qty'] ?? item['quantity'])?.toString() ?? '1',
//                 ) ??
//                 1.0)
//             .toInt();

//     // [KEPT] Price per piece = base + add-on + add-more - add-less - remove.
//     double rate = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
//     //  +
//     // (double.tryParse((item['addOnPrice'] ?? 0).toString()) ?? 0) +
//     // (double.tryParse((item['addMorePrice'] ?? 0).toString()) ?? 0) -
//     // (double.tryParse((item['addLessPrice'] ?? 0).toString()) ?? 0) -
//     // (double.tryParse((item['removePrice'] ?? 0).toString()) ?? 0);

//     // [KEPT] POS add-ons are Maps carrying their own price: add those too.
//     List rawAddonsPrice = item['addons'] ?? item['selectedAddons'] ?? [];
//     for (var a in rawAddonsPrice) {
//       if (a is Map) {
//         rate += double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
//       }
//     }

//     final double finalPrice = rate * qty;

//     // [KEPT] Add-on text from the POS format (list of Maps, or plain strings).
//     List<String> unifiedAddonsEn = [];
//     List<String> unifiedAddonsAr = [];

//     // [CHANGED] The same RegExp was written out 6 times; now it is made once.
//     // It strips a leading or trailing '+' left in the database names.
//     final RegExp plusEdges = RegExp(r'^\s*\+\s*|\s*\+\s*$');

//     List rawAddons = item['addons'] ?? item['selectedAddons'] ?? [];
//     for (var a in rawAddons) {
//       if (a is Map) {
//         String en = (a['nameEn']?.toString() ?? a['name']?.toString() ?? '')
//             .trim();
//         String ar =
//             (a['nameAr']?.toString() ?? a['arabicName']?.toString() ?? '')
//                 .trim();
//         en = en.replaceAll(plusEdges, '');
//         ar = ar.replaceAll(plusEdges, '');
//         if (en.isNotEmpty) unifiedAddonsEn.add(en);
//         if (ar.isNotEmpty) unifiedAddonsAr.add(ar);
//       } else if (a is String && a.trim().isNotEmpty) {
//         String str = a.trim().replaceAll(plusEdges, '');
//         if (str.isNotEmpty) unifiedAddonsEn.add(str);
//       }
//     }

//     // [KEPT] Join each language with " + ", then both together, and collapse "++".
//     String modsEn = unifiedAddonsEn
//         .map((s) => s.trim().replaceAll(plusEdges, ''))
//         .where((s) => s.isNotEmpty)
//         .join(" + ");
//     String modsAr = unifiedAddonsAr
//         .map((s) => s.trim().replaceAll(plusEdges, ''))
//         .where((s) => s.isNotEmpty)
//         .join(" + ");

//     String allMods = [modsEn, modsAr].where((s) => s.isNotEmpty).join(" + ");
//     allMods = allMods.replaceAll(RegExp(r'\s*\+\s*(\+\s*)+'), ' + ').trim();

//     // [KEPT] One row: name block | qty | Riyal icon + price.
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 6.0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 3,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   titleEn,
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.w900,
//                     fontSize: 22,
//                     height: 1.0,
//                   ),
//                 ),
//                 if (titleAr.isNotEmpty)
//                   Text(
//                     titleAr,
//                     style: const TextStyle(
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 22,
//                       height: 1.1,
//                     ),
//                   ),
//                 if (allMods.isNotEmpty)
//                   Text(
//                     '($allMods)',
//                     style: const TextStyle(
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 18,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: Text(
//               '$qty',
//               textAlign: TextAlign.center,
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontWeight: FontWeight.w900,
//                 fontSize: 22,
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 Image.asset(_riyalAsset, height: 12, color: Colors.black),
//                 const SizedBox(width: 4),
//                 Text(
//                   finalPrice.toStringAsFixed(2),
//                   style: const TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.w900,
//                     fontSize: 22,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // [KEPT] One totals line: label left, Riyal icon + amount right.
//   static Widget _buildTotalRow(
//     String label,
//     double amount, {
//     bool isHuge = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               label,
//               style: TextStyle(
//                 color: Colors.black,
//                 fontWeight: FontWeight.w900,
//                 fontSize: isHuge ? 26 : 20,
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Image.asset(
//                   _riyalAsset,
//                   height: isHuge ? 20 : 16,
//                   color: Colors.black,
//                 ),
//                 const SizedBox(width: 4),
//                 Text(
//                   amount.toStringAsFixed(2),
//                   textAlign: TextAlign.right,
//                   style: TextStyle(
//                     color: Colors.black,
//                     fontWeight: FontWeight.w900,
//                     fontSize: isHuge ? 28 : 22,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // [CHANGED] White canvas is 480 wide (was 384) to match the main bill's printer
//   // width, so the resize step has nothing to stretch.
//   static Widget _buildPrinterCanvas({required Widget child}) {
//     return Directionality(
//       textDirection: TextDirection.ltr,
//       child: Material(
//         color: Colors.white,
//         child: Container(
//           width: _printerWidth.toDouble(),
//           color: Colors.white,
//           child: child,
//         ),
//       ),
//     );
//   }
// }

























// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:intl/intl.dart' hide TextDirection;
// import 'package:screenshot/screenshot.dart';
// import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// import 'package:image/image.dart' as img;

// class MainReceipt {
//   // [FIX] We use a single ScreenshotController to capture the ENTIRE Arabic portion of the receipt at once.
//   // Previously, capturing 15 micro-screenshots caused extreme lag and produced blank images if
//   // the context was obstructed.
//   static final ScreenshotController _screenshotController = ScreenshotController();

//   static Future<List<int>> generate(
//     Map<String, dynamic> data,
//     String orderId, {
//     BuildContext? context,
//   }) async {
//     final profile = await CapabilityProfile.load();
//     final generator = Generator(PaperSize.mm80, profile);
//     List<int> bytes = [];

//     bytes += generator.reset();

//     // Data Extraction
//     final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
//     double cashAmount = (data['cashAmount'] as num?)?.toDouble() ?? 0.0;
//     double creditAmount = (data['creditAmount'] as num?)?.toDouble() ?? 0.0;
//     final double balance = (data['balance'] as num?)?.toDouble() ?? 0.0;

//     // [FIX] For customer app orders (printed from order_page), cashAmount/creditAmount
//     // are not explicitly stored in the order document. If both are zero, determine
//     // payment method (cash vs card/credit) and assign totalAmount accordingly so cash isn't shown as zero.
//     if (cashAmount == 0 && creditAmount == 0 && totalAmount > 0) {
//       final String paymentMethod =
//           (data['paymentMethod']?.toString().toLowerCase() ?? '');
//       if (paymentMethod.contains('card') ||
//           paymentMethod.contains('credit') ||
//           paymentMethod.contains('online')) {
//         creditAmount = totalAmount;
//       } else {
//         cashAmount = totalAmount; // Default to Cash (e.g. Cash on Delivery)
//       }
//     }
//     final List<dynamic> items = data['items'] ?? [];
//     final String orderType = data['orderType'] ?? 'Takeaway';
//     final int? tokenNumber = data['tokenNumber'] != null ? int.tryParse(data['tokenNumber'].toString()) : null;
//     final String tableId = data['tableId']?.toString() ?? '';
//     final String customerName = data['customerName']?.toString() ?? '';
//     final String phone = data['phone']?.toString() ?? '';
//     final String address = data['address']?.toString() ?? '';

//     DateTime orderDate = DateTime.now();
//     if (data['createdAt'] != null) {
//       try {
//         orderDate = data['createdAt'].toDate();
//       } catch (_) {
//         if (data['createdAt'] is String) {
//           orderDate = DateTime.tryParse(data['createdAt']) ?? DateTime.now();
//         }
//       }
//     }

//     // 1. Logo
//     await _addLogo(bytes);

//     // 2. English/Native Text Details
//     if (tokenNumber != null) {
//        bytes += generator.text('Token: #$tokenNumber', styles: const PosStyles(bold: true, align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2));
//        bytes += generator.emptyLines(1);
//     }

//     bytes += generator.text('Order ID: $orderId', styles: const PosStyles(bold: true));
//     bytes += generator.text('Type: $orderType', styles: const PosStyles(bold: true));
//     bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(orderDate)}');

//     if (customerName.isNotEmpty) bytes += generator.text('Customer: $customerName', styles: const PosStyles(bold: true));
//     if (phone.isNotEmpty) bytes += generator.text('Phone: $phone', styles: const PosStyles(bold: true));
//     if (address.isNotEmpty) bytes += generator.text('Address: $address', styles: const PosStyles(bold: true));
//     if (tableId.isNotEmpty && orderType == 'Dine In') bytes += generator.text('Table: $tableId', styles: const PosStyles(bold: true));

//     bytes += generator.feed(1);

//     // 3. Arabic & Graphic Content (Rendered as a single image to guarantee font/Riyal icon support)
//     final Widget receiptWidget = _buildPrinterCanvas(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text(
//             'RECEIPT\nإيصال',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, height: 1.2),
//           ),
//           const SizedBox(height: 8),
//           const Divider(color: Colors.black, thickness: 2),
//           Row(
//             children: const [
//               Expanded(flex: 3, child: Text('Item / الصنف', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))),
//               Expanded(flex: 1, child: Text('Qty / الكمية', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))),
//               Expanded(flex: 2, child: Text('Price / السعر', textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14))),
//             ],
//           ),
//           const Divider(color: Colors.black, thickness: 2),
//           ...items.map((item) {
//             // [FIX] Extracted exactly matching the original web_project data structure (e.g. pdtname instead of nameEn).
//             // Without these exact keys, everything resulted in "Unknown Item".
//             final String titleEn = item['pdtname'] ?? item['nameEn'] ?? item['title'] ?? 'Unknown Item';
//             final String titleAr = item['arabicName'] ?? item['nameAr'] ?? item['titleAr'] ?? '';
//             final int qty = (double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0).toInt();

//             // [FIX] Base price plus all positive and negative modifier prices exactly like old code
//             // PLUS dynamically adding POS addon Map prices since they aren't in 'addOnPrice'
//             double rate = (double.tryParse(item['price']?.toString() ?? '0') ?? 0) +
//                 (double.tryParse((item['addOnPrice'] ?? 0).toString()) ?? 0) +
//                 (double.tryParse((item['addMorePrice'] ?? 0).toString()) ?? 0) -
//                 (double.tryParse((item['addLessPrice'] ?? 0).toString()) ?? 0) -
//                 (double.tryParse((item['removePrice'] ?? 0).toString()) ?? 0);

//             // Dynamically sum the prices from POS format Add-on Maps
//             List rawAddonsPrice = item['addons'] ?? item['selectedAddons'] ?? [];
//             for (var a in rawAddonsPrice) {
//               if (a is Map) {
//                 rate += double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
//               }
//             }

//             final double finalPrice = rate * qty;

//             // [FIX] Extracted Add-ons properly handling BOTH the POS app's structure (Maps) and Online structure (Strings)
//             List<String> unifiedAddonsEn = [];
//             List<String> unifiedAddonsAr = [];

//             // 1. POS Format (List of Maps)
//             List rawAddons = item['addons'] ?? item['selectedAddons'] ?? [];
//             for (var a in rawAddons) {
//               if (a is Map) {
//                 String en = (a['nameEn']?.toString() ?? a['name']?.toString() ?? '').trim();
//                 String ar = (a['nameAr']?.toString() ?? a['arabicName']?.toString() ?? '').trim();
//                 // Strip any leading or trailing '+' signs already in the database
//                 en = en.replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), '');
//                 ar = ar.replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), '');
//                 if (en.isNotEmpty) unifiedAddonsEn.add(en);
//                 if (ar.isNotEmpty) unifiedAddonsAr.add(ar);
//               } else if (a is String && a.trim().isNotEmpty) {
//                 String str = a.trim().replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), '');
//                 if (str.isNotEmpty) unifiedAddonsEn.add(str);
//               }
//             }

//             // Strip any remaining leading/trailing '+' signs from each modifier
//             String modsEn = unifiedAddonsEn
//                 .map((s) => s.trim().replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), ''))
//                 .where((s) => s.isNotEmpty)
//                 .join(" + ");
//             String modsAr = unifiedAddonsAr
//                 .map((s) => s.trim().replaceAll(RegExp(r'^\s*\+\s*|\s*\+\s*$'), ''))
//                 .where((s) => s.isNotEmpty)
//                 .join(" + ");

//             // Join English and Arabic with a single '+', and collapse any accidental double '++'
//             String allMods = [modsEn, modsAr].where((s) => s.isNotEmpty).join(" + ");
//             allMods = allMods.replaceAll(RegExp(r'\s*\+\s*(\+\s*)+'), ' + ').trim();

//             return Padding(
//               padding: const EdgeInsets.only(bottom: 6.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Expanded(
//                         flex: 3,
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(titleEn, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, height: 1.0)),
//                             if (titleAr.isNotEmpty)
//                               Text(titleAr, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
//                             if (allMods.isNotEmpty)
//                               Text('($allMods)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
//                           ],
//                         ),
//                       ),
//                       Expanded(
//                         flex: 1,
//                         child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
//                       ),
//                       Expanded(
//                         flex: 2,
//                         child: Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             Image.asset('assets/images/saudi_riyal.png', height: 12, color: Colors.black),
//                             const SizedBox(width: 4),
//                             Text(finalPrice.toStringAsFixed(2), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//           const Divider(color: Colors.black, thickness: 2),
//           _buildTotalRow('Total / الإجمالي', totalAmount, isHuge: true),
//           _buildTotalRow('Cash / نقدي', cashAmount),
//           if (creditAmount > 0) _buildTotalRow('Credit / بطاقة ائتمان', creditAmount),
//           _buildTotalRow('Balance / المتبقي', balance),
//           const Divider(color: Colors.black, thickness: 2),
//           const SizedBox(height: 8),
//           const Text('Thank you for your visit!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
//           const SizedBox(height: 4),
//           const Text('شكراً لزيارتكم!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
//           const SizedBox(height: 8),
//         ],
//       ),
//     );

//     // Capture the entire Arabic section as one single image to fix bugs & speed up!
//     // Notice we do NOT pass context to prevent UI overlapping/blank screens!
//     final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
//       receiptWidget,
//       delay: const Duration(milliseconds: 100),
//     );

//     if (imageBytes != null) {
//       final img.Image? decoded = img.decodeImage(imageBytes);
//       if (decoded != null) {
//         bytes.addAll(_imageToEscPosRaster(decoded));
//       }
//     }

//     bytes += generator.feed(2);
//     return bytes;
//   }

//   static Widget _buildTotalRow(String label, double amount, {bool isHuge = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Expanded(
//             flex: 2,
//             child: Text(
//               label,
//               style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: isHuge ? 20 : 16),
//             ),
//           ),
//           Expanded(
//             flex: 3,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Image.asset('assets/images/saudi_riyal.png', height: isHuge ? 16 : 12, color: Colors.black),
//                 const SizedBox(width: 4),
//                 Text(
//                   amount.toStringAsFixed(2),
//                   textAlign: TextAlign.right,
//                   style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: isHuge ? 22 : 16),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   static Widget _buildPrinterCanvas({required Widget child}) {
//     return Directionality(
//       textDirection: TextDirection.ltr,
//       child: Material(
//         color: Colors.white,
//         child: Container(
//           width: 384, // 80mm printer
//           color: Colors.white,
//           child: child,
//         ),
//       ),
//     );
//   }

//   static Future<void> _addLogo(List<int> bytes) async {
//     try {
//       final ByteData data = await rootBundle.load('assets/images/rest.jpg');
//       final Uint8List imgBytes = data.buffer.asUint8List();
//       final img.Image? decodedImage = img.decodeImage(imgBytes);
//       if (decodedImage != null) {
//         img.Image resized = img.copyResize(decodedImage, width: 250, maintainAspect: true);
//         bytes.addAll(_imageToEscPosRaster(resized));
//       }
//     } catch (e) {
//       print("Could not load logo: $e");
//     }
//   }

//   static List<int> _imageToEscPosRaster(img.Image fullImage) {
//     List<int> bytes = [];
//     int width = fullImage.width;
//     int widthBytes = (width + 7) ~/ 8;

//     bytes.addAll([27, 97, 1]); // Center alignment

//     // [FIX] Slice the image into 200px chunks. Thermal printers have small raster buffers.
//     // Sending an image taller than 255-500px in a single GS v 0 command causes it to freeze or drop bytes (no cut).
//     int chunkHeight = 200;

//     for (int startY = 0; startY < fullImage.height; startY += chunkHeight) {
//       int currentHeight = (startY + chunkHeight > fullImage.height)
//           ? (fullImage.height - startY)
//           : chunkHeight;

//       bytes.addAll([29, 118, 48, 0, widthBytes % 256, widthBytes ~/ 256, currentHeight % 256, currentHeight ~/ 256]);

//       for (int y = startY; y < startY + currentHeight; y++) {
//         for (int x = 0; x < widthBytes; x++) {
//           int byte = 0;
//           for (int bit = 0; bit < 8; bit++) {
//             int pixelX = x * 8 + bit;
//             if (pixelX < width) {
//               img.Pixel pixel = fullImage.getPixel(pixelX, y);
//               int r = pixel.r.toInt();
//               int g = pixel.g.toInt();
//               int b = pixel.b.toInt();
//               int luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
//               if (luminance < 128) byte |= (1 << (7 - bit));
//             }
//           }
//           bytes.add(byte);
//         }
//       }
//     }
//     return bytes;
//   }
// }

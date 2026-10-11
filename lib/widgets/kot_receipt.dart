import 'package:intl/intl.dart' hide TextDirection;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class KotReceipt {
  /// Generates the raw ESC/POS byte array for a Kitchen Order Ticket (KOT).
  /// Uses PURE NATIVE TEXT ONLY (No Arabic, no screenshots) for maximum speed.
  static Future<List<int>> generate(
    Map<String, dynamic> data,
    String orderId, {
    dynamic context, // Ignored, but kept to prevent compilation errors from pos_page.dart
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // Data Extraction
    final List<dynamic> items = data['items'] ?? [];
    final String orderType = data['orderType'] ?? 'Walk-In';
    final String tableId = data['tableId']?.toString() ?? '';

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

    // --- NATIVE HEADER ---
    bytes += generator.text(
      '*** KITCHEN ORDER ***',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.emptyLines(1);

    bytes += generator.text('Order #: ${orderId.toUpperCase()}', styles: const PosStyles(bold: true));
    bytes += generator.text('Type: $orderType');

    if (orderType == 'Dine In' && tableId.isNotEmpty) {
      bytes += generator.text('Table: $tableId', styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    }

    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(orderDate)}');
    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: 'Item', width: 9, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 3, styles: const PosStyles(bold: true, align: PosAlign.center)),
    ]);
    bytes += generator.hr();

    // --- ITEMS SECTION (Pure Native Text) ---
    for (var item in items) {
      final String titleEn = item['pdtname'] ?? item['nameEn'] ?? item['title'] ?? 'Unknown Item';
      final int qty = (double.tryParse(item['qty']?.toString() ?? '1') ?? 1.0).toInt();

      List<String> unifiedAddonsEn = [];

      // 1. POS Format (List of Maps)
      List rawAddons = item['addons'] ?? item['selectedAddons'] ?? [];
      for (var a in rawAddons) {
        if (a is Map) {
          unifiedAddonsEn.add(a['nameEn']?.toString() ?? a['name']?.toString() ?? '');
        }
      }

      // 2. Online Format (List of Strings)
      List pdtAddOn = item['addOns'] ?? [];
      List pdtChoice = item['choice'] ?? [];
      List pdtOnlyOne = item['onlyOne'] ?? [];
      List pdtRemove = item['remove'] ?? [];
      List pdtAddMore = item['addMore'] ?? [];
      List pdtAddLess = item['addLess'] ?? [];

      if (pdtAddOn.isNotEmpty) unifiedAddonsEn.add(pdtAddOn.join(", "));
      if (pdtChoice.isNotEmpty) unifiedAddonsEn.add(pdtChoice.join(", "));
      if (pdtOnlyOne.isNotEmpty) unifiedAddonsEn.add(pdtOnlyOne.join(", "));
      if (pdtRemove.isNotEmpty) unifiedAddonsEn.add("- ${pdtRemove.join(", ")}");
      if (pdtAddMore.isNotEmpty) unifiedAddonsEn.add("+ ${pdtAddMore.join(", ")}");
      if (pdtAddLess.isNotEmpty) unifiedAddonsEn.add("- ${pdtAddLess.join(", ")}");

      String modsEn = unifiedAddonsEn.where((s) => s.isNotEmpty).join(" + ");

      bytes += generator.row([
        PosColumn(text: titleEn, width: 9, styles: const PosStyles(bold: true)),
        PosColumn(text: 'x$qty', width: 3, styles: const PosStyles(bold: true, align: PosAlign.center, width: PosTextSize.size2)),
      ]);

      if (modsEn.isNotEmpty) {
        bytes += generator.text('  $modsEn', styles: const PosStyles(bold: true));
      }
      
      bytes += generator.feed(1);
    }

    bytes += generator.hr();
    bytes += generator.emptyLines(1);

    bytes += generator.text('--- END OF ORDER ---', styles: const PosStyles(align: PosAlign.center));
    
    // Explicit Cut Command for the KOT
    bytes += generator.feed(2);
    bytes += generator.cut(); 

    return bytes;
  }
}

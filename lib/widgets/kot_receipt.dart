import 'package:intl/intl.dart' hide TextDirection;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
// Import the centralized ReceiptOrderModel
import '../models/receipt_order_model.dart';

class KotReceipt {
  /// Generates the raw ESC/POS byte array for a Kitchen Order Ticket (KOT)
  /// directly from the strongly-typed ReceiptOrderModel.
  /// Uses PURE NATIVE TEXT ONLY (No Arabic, no offscreen screenshots) for maximum printing speed.
  /// Encapsulates paper feeding and cutting commands so callers receive a ready-to-print payload.
  static Future<List<int>> generate(
    ReceiptOrderModel receiptOrderModel, {
    bool cut = true, // Default to true for a complete kitchen ticket with physical paper cut
  }) async {
    // 1. Initialize printer capability profile and ESC/POS generator for 80mm paper
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // Hardware reset command to ensure printer buffer is clean
    bytes += generator.reset();

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 1: NATIVE KITCHEN TICKET HEADER
    // ─────────────────────────────────────────────────────────────────────────
    // Bold centered title in double size
    bytes += generator.text(
      '*** KITCHEN ORDER ***',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.emptyLines(1);

    // Order ID (e.g. ORDTKW0012) in bold
    bytes += generator.text(
      'Order #: ${_safeText(receiptOrderModel.orderId.toUpperCase())}',
      styles: const PosStyles(bold: true),
    );

    // Order Type (Dine In, Takeaway, Delivery, etc.)
    bytes += generator.text('Type: ${_safeText(receiptOrderModel.orderType)}');

    // If Dine In, highlight Table number in double size for kitchen staff visibility
    if (receiptOrderModel.orderType == 'Dine In' && receiptOrderModel.tableId.isNotEmpty) {
      final safeTable = _safeText(receiptOrderModel.tableId);
      if (safeTable.isNotEmpty) {
        bytes += generator.text(
          'Table: $safeTable',
          styles: const PosStyles(
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
      }
    }

    // Timestamp formatted for kitchen log
    bytes += generator.text(
      'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(receiptOrderModel.orderDate)}',
    );
    bytes += generator.hr(); // Horizontal line divider

    // Table Column Headers: Item (Width 9), Qty (Width 3)
    bytes += generator.row([
      PosColumn(text: 'Item', width: 9, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Qty',
        width: 3,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
    ]);
    bytes += generator.hr();

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 2: ITEMS & MODIFIERS (Using typed ReceiptItemModel)
    // ─────────────────────────────────────────────────────────────────────────
    for (final item in receiptOrderModel.items) {
      final String safeTitle = _safeText(item.titleEn);
      // Print English Item Title and Quantity (double width on quantity for quick kitchen glance)
      bytes += generator.row([
        PosColumn(
          text: safeTitle.isNotEmpty ? safeTitle : 'Item',
          width: 9,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'x${item.qty}',
          width: 3,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.center,
            width: PosTextSize.size2,
          ),
        ),
      ]);

      // Print any English modifiers/addons (e.g. Extra Cheese + No Onion) if present
      // Fallback safely stripped to ensure zero Unicode/Arabic crashes the ESC/POS text encoder
      final String rawMods =
          item.modifiersEn.isNotEmpty ? item.modifiersEn : item.modifiersText;
      final String safeMods = _safeText(rawMods);
      if (safeMods.isNotEmpty) {
        bytes += generator.text(
          '  $safeMods',
          styles: const PosStyles(bold: true),
        );
      }

      bytes += generator.feed(1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 3: FOOTER & PAPER CUTTING
    // ─────────────────────────────────────────────────────────────────────────
    bytes += generator.hr();
    bytes += generator.emptyLines(1);

    bytes += generator.text(
      '--- END OF ORDER ---',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Feed paper lines to clear printer cutter head
    bytes += generator.feed(2);

    // Send physical paper cut command
    if (cut) {
      bytes += generator.cut();
    }

    return bytes;
  }

  /// Sanitizes text to ensure all characters are ASCII (32-126) encodable by native ESC/POS printers.
  /// Replaces fancy quotes/dashes, strips non-ASCII/Arabic characters, and cleans up empty formatting remnants.
  static String _safeText(String input) {
    if (input.isEmpty) return '';
    String sanitized = input
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .trim();
    if (sanitized == '()' ||
        sanitized == '( )' ||
        sanitized == '+' ||
        sanitized == '(+)') {
      return '';
    }
    return sanitized;
  }
}

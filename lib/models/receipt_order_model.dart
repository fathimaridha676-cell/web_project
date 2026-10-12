/// Receipt Order & Item Models
/// Encapsulates all data extraction, price calculations, and string
/// sanitization in one place, keeping MainReceipt strictly focused
/// on layout and ESC/POS raster generation.
class ReceiptItemModel {
  final String titleEn;
  final String titleAr;
  final int qty;
  final double finalPrice;
  final String modifiersText;

  ReceiptItemModel({
    required this.titleEn,
    required this.titleAr,
    required this.qty,
    required this.finalPrice,
    required this.modifiersText,
  });

  /// Factory constructor to safely parse an item map from Firestore or POS
  factory ReceiptItemModel.fromMap(Map<String, dynamic> item) {
    // 1. Resolve product title in both English and Arabic
    final String titleEn =
        item['pdtname'] ?? item['nameEn'] ?? item['title'] ?? 'Unknown Item';
    final String titleAr =
        item['arabicName'] ?? item['nameAr'] ?? item['titleAr'] ?? '';

    // 2. Resolve quantity (support string, int, double from various collections)
    final int qty = (double.tryParse(
              (item['qty'] ?? item['quantity'])?.toString() ?? '1',
            ) ??
            1.0)
        .toInt();

    // 3. Calculate unit rate + any dynamic POS add-on prices
    double rate = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
    final List rawAddonsPrice =
        item['addons'] ?? item['selectedAddons'] ?? [];
    for (var a in rawAddonsPrice) {
      if (a is Map) {
        rate += double.tryParse(a['price']?.toString() ?? '0') ?? 0.0;
      }
    }
    final double finalPrice = rate * qty;

    // 4. Extract, normalize, and format modifiers / add-on strings
    final List<String> unifiedAddonsEn = [];
    final List<String> unifiedAddonsAr = [];
    final RegExp plusEdges = RegExp(r'^\s*\+\s*|\s*\+\s*$');

    final List rawAddons = item['addons'] ?? item['selectedAddons'] ?? [];
    for (var a in rawAddons) {
      if (a is Map) {
        String en =
            (a['nameEn']?.toString() ?? a['name']?.toString() ?? '').trim();
        String ar =
            (a['nameAr']?.toString() ?? a['arabicName']?.toString() ?? '')
                .trim();
        en = en.replaceAll(plusEdges, '');
        ar = ar.replaceAll(plusEdges, '');
        if (en.isNotEmpty) unifiedAddonsEn.add(en);
        if (ar.isNotEmpty) unifiedAddonsAr.add(ar);
      } else if (a is String && a.trim().isNotEmpty) {
        String str = a.trim().replaceAll(plusEdges, '');
        if (str.isNotEmpty) unifiedAddonsEn.add(str);
      }
    }

    final String modsEn =
        unifiedAddonsEn.where((s) => s.isNotEmpty).join(' + ');
    final String modsAr =
        unifiedAddonsAr.where((s) => s.isNotEmpty).join(' + ');
    String allMods = [modsEn, modsAr].where((s) => s.isNotEmpty).join(' + ');
    allMods = allMods.replaceAll(RegExp(r'\s*\+\s*(\+\s*)+'), ' + ').trim();

    return ReceiptItemModel(
      titleEn: titleEn,
      titleAr: titleAr,
      qty: qty,
      finalPrice: finalPrice,
      modifiersText: allMods.isNotEmpty ? '($allMods)' : '',
    );
  }
}

/// Represents the complete order/bill payload passed to the receipt printer
class ReceiptOrderModel {
  final String orderId;
  final int? tokenNumber;
  final String orderType;
  final String tableId;
  final String customerName;
  final String phone;
  final String address;
  final DateTime orderDate;
  final double totalAmount;
  final double cashAmount;
  final double creditAmount;
  final double balance;
  final List<ReceiptItemModel> items;

  ReceiptOrderModel({
    required this.orderId,
    this.tokenNumber,
    required this.orderType,
    required this.tableId,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.orderDate,
    required this.totalAmount,
    required this.cashAmount,
    required this.creditAmount,
    required this.balance,
    required this.items,
  });

  /// Factory constructor to convert raw Firestore maps into a typed ReceiptOrderModel
  factory ReceiptOrderModel.fromMap(
    Map<String, dynamic> data,
    String orderId,
  ) {
    // 1. Safely extract and parse date
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

    // 2. Parse items list safely
    final List rawItems = data['items'] as List? ?? [];
    final List<ReceiptItemModel> items = rawItems
        .map((e) =>
            ReceiptItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ReceiptOrderModel(
      orderId: orderId,
      tokenNumber: data['tokenNumber'] != null
          ? int.tryParse(data['tokenNumber'].toString())
          : null,
      orderType: data['orderType']?.toString() ?? 'Takeaway',
      tableId: data['tableId']?.toString() ?? '',
      customerName: data['customerName']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      orderDate: orderDate,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      cashAmount: (data['cashAmount'] as num?)?.toDouble() ?? 0.0,
      creditAmount: (data['creditAmount'] as num?)?.toDouble() ?? 0.0,
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      items: items,
    );
  }
}

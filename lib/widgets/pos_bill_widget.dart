import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget that displays a professional point of sale (POS) bill.
/// Designed specifically for Thermal Printers:
/// - Uses STRICTLY Colors.black and bold fonts (No greys!)
/// - Avoids transparency to prevent dithering (faint printing)
/// - Bilingual Arabic/English layout
class PosBillWidget extends StatelessWidget {
  /// The order data containing items, totals, dates, etc.
  final Map<String, dynamic> data;

  /// The unique identifier for the order.
  final String orderId;

  /// The token number for the order, if applicable.
  final int? tokenNumber;

  /// Constructor for PosBillWidget
  const PosBillWidget({
    super.key,
    required this.data,
    required this.orderId,
    this.tokenNumber,
  });

  @override
  Widget build(BuildContext context) {
    // Extract basic information from the data map.
    final String orderType = data['orderType'] ?? 'Takeaway';
    final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final double cashAmount = (data['cashAmount'] as num?)?.toDouble() ?? 0.0;
    final double creditAmount =
        (data['creditAmount'] as num?)?.toDouble() ?? 0.0;
    final double balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> items = data['items'] ?? [];

    // Parse the order date safely.
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

    // Main Container: Pure white background, strict width
    return Container(
      color: Colors.white, // MUST be pure white for thermal printers
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display the restaurant logo at the top
          Center(
            child: Image.asset(
              'assets/images/rest.jpg',
              width: 120, // Increased logo size for better visibility
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.restaurant, size: 80, color: Colors.black),
            ),
          ),

          const SizedBox(height: 6), // Reduced gap
          // Title
          const Center(
            child: Text(
              'RECEIPT\nإيصال',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black, // PURE BLACK
                fontWeight: FontWeight.w900, // EXTRA BOLD
                fontSize: 18,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 6), // Reduced gap
          // Header Information
          if (tokenNumber != null)
            _buildInfoRow('Token / رقم الرمز', '#$tokenNumber', isLarge: true),

          _buildInfoRow('Order ID / رقم الطلب', orderId),
          _buildInfoRow('Type / نوع الطلب', orderType),
          _buildInfoRow(
            'Date / التاريخ',
            DateFormat('yyyy-MM-dd HH:mm').format(orderDate),
          ),

          const SizedBox(height: 4), // Reduced gap
          const _SolidDivider(),
          const SizedBox(height: 4), // Reduced gap
          // Table Headers (Item | Qty | Price)
          Row(
            children: const [
              Expanded(
                flex: 3,
                child: Text(
                  'Item / الصنف',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
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
                    fontSize: 14,
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
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4), // Reduced gap
          const _SolidDivider(),
          const SizedBox(height: 6), // Reduced gap
          // Item List
          ...items.map((item) {
            final String titleEn = item['nameEn'] ?? item['title'] ?? 'Item';
            final String? titleAr = item['nameAr'];
            final int qty = item['quantity'] ?? 1;
            final double basePrice = (item['price'] as num?)?.toDouble() ?? 0.0;
            final List<dynamic> addons =
                item['addons'] ?? item['selectedAddons'] ?? [];

            double addonsTotal = 0.0;
            for (var addon in addons) {
              addonsTotal += (addon['price'] as num?)?.toDouble() ?? 0.0;
            }
            final double finalPrice = (basePrice + addonsTotal) * qty;

            return Padding(
              padding: const EdgeInsets.only(
                bottom: 6.0,
              ), // Reduced gap from 12.0
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Name
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleEn,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                height:
                                    1.0, // <-- Added to reduce gap below English name
                              ),
                            ),
                            if (titleAr != null && titleAr.isNotEmpty)
                              Text(
                                titleAr,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  height:
                                      1.1, // <-- Added to reduce gap above Arabic name
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Quantity
                      Expanded(
                        flex: 1,
                        child: Text(
                          '$qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      // Price
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildCurrencyText(finalPrice, size: 16),
                        ),
                      ),
                    ],
                  ),

                  // Addons
                  if (addons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                      child: Row(
                        // changed here from column to row
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: addons.map((addon) {
                          final String addonEn =
                              addon['nameEn'] ?? addon['title'] ?? 'Addon';
                          final String addonAr = addon['nameAr'] ?? '';
                          final String displayName = addonAr.isNotEmpty
                              ? '$addonEn / $addonAr'
                              : addonEn;

                          return Text(
                            '+ $displayName',
                            style: const TextStyle(
                              color: Colors.black, // MUST BE BLACK
                              fontWeight: FontWeight.bold, // BOLD FOR PRINTER
                              fontSize: 14,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 4), // Reduced gap
          const _SolidDivider(isThick: true),
          const SizedBox(height: 4), // Reduced gap
          // Totals Section
          _buildTotalRow('Total / الإجمالي', totalAmount, isHuge: true),
          const SizedBox(height: 4), // Reduced gap
          _buildTotalRow('Cash / نقدي', cashAmount),
          _buildTotalRow('Credit / بطاقة ائتمان', creditAmount),
          _buildTotalRow('Balance / المتبقي', balance),

          const SizedBox(height: 8), // Reduced gap
          const _SolidDivider(),
          const SizedBox(height: 8), // Reduced gap
          // Footer
          const Text(
            'Thank you for your visit!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'شكراً لزيارتكم!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),

          // Add extra padding at the bottom so the printer cuts properly
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Builds the information rows with strict black styling
  Widget _buildInfoRow(String label, String value, {bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Reduced gap
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: isLarge ? 16 : 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: isLarge ? 20 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the total rows using pure black
  Widget _buildTotalRow(String label, double amount, {bool isHuge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Reduced gap
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: isHuge ? 20 : 16,
            ),
          ),
          _buildCurrencyText(amount, size: isHuge ? 22 : 16),
        ],
      ),
    );
  }

  /// Builds the currency text with the image icon
  Widget _buildCurrencyText(double amount, {required double size}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/saudi_riyal.png',
          height: size * 0.8, // Dynamic scale based on text size
          color: Colors
              .black, // Forces the image to be pure black (if it's a transparent PNG)
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(
            'SAR',
            style: TextStyle(
              color: Colors.black,
              fontSize: size * 0.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 4), // Reduced spacing slightly
        Text(
          amount.toStringAsFixed(2),
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: size,
          ),
        ),
      ],
    );
  }
}

/// A custom widget to draw a solid divider for printers
class _SolidDivider extends StatelessWidget {
  final bool isThick;
  const _SolidDivider({this.isThick = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isThick ? 3.0 : 1.5,
      color: Colors.black, // Solid black line prints best on thermal
    );
  }
}

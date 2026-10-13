import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:cloud_firestore/cloud_firestore.dart';
// Hardware printer service for managing connections (Android BLE/USB & Windows USB)
import '../services/printer_service.dart';
// Main receipt layout generator responsible for ESC/POS raster byte generation
import '../widgets/main_receipt.dart';
// Strongly-typed model for parsing, sanitizing, and calculating receipt order data
import '../models/receipt_order_model.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String _selectedSource = 'All';
  String _selectedOrderType = 'All';

  // Tracks which specific sale is actively generating/printing to show a loading spinner
  String? _printingSaleId;

  final List<String> _sources = ['All', 'POS', 'customer app'];
  final List<String> _orderTypes = [
    'All',
    'Dine In',
    'Takeaway',
    'Delivery',
    'Drive Through',
  ];

  String _formatDate(DateTime d) =>
      DateFormat('MMM dd, yyyy - h:mm a').format(d);

  IconData _getIconForOrderType(String type) {
    switch (type) {
      case 'Takeaway':
        return Icons.shopping_bag;
      case 'Drive Through':
        return Icons.directions_car;
      case 'Delivery':
        return Icons.local_shipping;
      case 'Dine In':
      default:
        return Icons.table_restaurant;
    }
  }

  /// Handles fetching order line items if needed, and dispatching the raw
  /// ESC/POS payload directly from the typed ReceiptOrderModel.
  Future<void> _printSale(ReceiptOrderModel sale) async {
    // 1. Verify that a thermal printer is configured on the device (BLE/USB on Android or USB on Windows)
    final bool hasPrinter = await PrinterService.hasConfiguredPrinter();
    if (!hasPrinter) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No printer configured! Please set it up on the Home Page.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2. Activate the loading indicator specifically for this sale item
    setState(() {
      _printingSaleId = sale.orderId;
    });

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sending Sale #${sale.displayOrderId} to printer...'),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // 3. Generate 80mm ESC/POS raster byte array directly using typed ReceiptOrderModel
      final List<int> printBytes = await MainReceipt.generate(sale);

      // 6. Dispatch byte buffer to the physical printer via PrinterService
      final String? errorMsg = await PrinterService.printBytes(printBytes);

      // 7. Provide immediate visual feedback to the operator
      if (mounted) {
        if (errorMsg == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt printed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Print Failed: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Print exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 8. Reset loading state once the print job concludes
      if (mounted) {
        setState(() {
          _printingSaleId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime oneDayAgo = DateTime.now().subtract(
      const Duration(hours: 24),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Sales History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Header & Dropdowns
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'All Sales (Last 24h)',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                Row(
                  children: [
                    _buildDropdown(
                      'Source',
                      _sources,
                      _selectedSource,
                      (v) => setState(() => _selectedSource = v!),
                    ),
                    const SizedBox(width: 16),
                    _buildDropdown(
                      'Order Type',
                      _orderTypes,
                      _selectedOrderType,
                      (v) => setState(() => _selectedOrderType = v!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // List View
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sales')
                  .where('timestamp', isGreaterThanOrEqualTo: oneDayAgo)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading sales: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No sales found in the last 24 hours.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                // 1. Map all documents to strongly-typed ReceiptOrderModel instances
                final allSales = snapshot.data!.docs.map((doc) {
                  return ReceiptOrderModel.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                }).toList();

                // 2. Filter using clean, type-safe model getters
                final filteredSales = allSales.where((sale) {
                  bool sourceMatches =
                      _selectedSource == 'All' ||
                      sale.source.toLowerCase() ==
                          _selectedSource.toLowerCase();
                  bool typeMatches =
                      _selectedOrderType == 'All' ||
                      sale.orderType == _selectedOrderType;

                  return sourceMatches && typeMatches;
                }).toList();

                if (filteredSales.isEmpty) {
                  return const Center(
                    child: Text(
                      'No sales match the selected filters.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                // 3. Render clean list items using typed model getters
                return ListView.separated(
                  padding: const EdgeInsets.all(32),
                  itemCount: filteredSales.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.grey.shade300, height: 1),
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];

                    return Container(
                      color: const Color(0xFFFBF9FA), // light pinkish grey
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          // Left Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForOrderType(sale.orderType),
                              color: Colors.teal,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Center Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      sale.orderType == 'Dine In'
                                          ? 'Table: ${sale.tableName.isNotEmpty ? sale.tableName : (sale.tableId.isNotEmpty ? sale.tableId : 'N/A')}'
                                          : 'Order: ${sale.displayOrderId}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        sale.orderType,
                                        style: const TextStyle(
                                          color: Colors.teal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        sale.source.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatDate(sale.orderDate),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cash: \$${sale.cashAmount.toStringAsFixed(2)} • Credit: \$${sale.creditAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right Total
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '\$${sale.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),

                          // Print Action Button for this individual sale
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: _printingSaleId == sale.orderId
                                // Show progress spinner while this specific sale is generating/printing
                                ? const Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  )
                                // Standard print icon button
                                : IconButton(
                                    icon: const Icon(
                                      Icons.print_rounded,
                                      color: Colors.teal,
                                    ),
                                    tooltip: 'Print Receipt',
                                    onPressed: _printingSaleId != null
                                        ? null // Prevent duplicate clicks while another print is in progress
                                        : () => _printSale(sale),
                                  ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> items,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  String _selectedSource = 'All';
  String _selectedOrderType = 'All';

  final List<String> _sources = ['All', 'POS', 'customer app'];
  final List<String> _orderTypes = [
    'All',
    'Dine In',
    'Takeaway',
    'Delivery',
    'Drive Through',
  ];

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String month = months[d.month - 1];
    String day = d.day.toString().padLeft(2, '0');
    int h = d.hour;
    String ampm = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    String min = d.minute.toString().padLeft(2, '0');
    return '$month $day, ${d.year} - $h:$min $ampm';
  }

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

                // Local Filtering
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final source = data['source']?.toString().toLowerCase() ?? '';
                  final orderType = data['orderType']?.toString() ?? '';

                  bool sourceMatches =
                      _selectedSource == 'All' ||
                      source == _selectedSource.toLowerCase();
                  bool typeMatches =
                      _selectedOrderType == 'All' ||
                      orderType == _selectedOrderType;

                  return sourceMatches && typeMatches;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No sales match the selected filters.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(32),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.grey.shade300, height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    String type = data['orderType'] ?? 'Unknown';
                    String source = data['source'] ?? 'Unknown';
                    String table = data['tableName']?.toString() ?? 'N/A';

                    double total =
                        double.tryParse(
                          data['totalAmount']?.toString() ?? '0',
                        ) ??
                        0;
                    double cash =
                        double.tryParse(
                          data['cashAmount']?.toString() ?? '0',
                        ) ??
                        0;
                    double credit =
                        double.tryParse(
                          data['creditAmount']?.toString() ?? '0',
                        ) ??
                        0;

                    Timestamp? ts = data['timestamp'] as Timestamp?;
                    DateTime date = ts != null ? ts.toDate() : DateTime.now();

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
                              _getIconForOrderType(type),
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
                                      type == 'Dine In'
                                          ? 'Table: $table'
                                          : 'Order: ${data['displayOrderId'] ?? 'N/A'}',
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
                                        type,
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
                                        source.toUpperCase(),
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
                                  _formatDate(date),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cash: \$${cash.toStringAsFixed(2)} • Credit: \$${credit.toStringAsFixed(2)}',
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
                                '\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
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

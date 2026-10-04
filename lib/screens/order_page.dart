import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateOrderStatus(DocumentReference docRef, String newStatus) async {
    await docRef.update({'status': newStatus});
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor ?? Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(String? filterStatus) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collectionGroup('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading orders: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var orders = snapshot.data!.docs.toList();
        
        if (filterStatus != null) {
          orders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] as String?)?.toLowerCase() ?? 'pending';
            return status == filterStatus.toLowerCase();
          }).toList();
        }

        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); 
        });

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final data = orderDoc.data() as Map<String, dynamic>;
            
            final String rawStatus = data['status'] ?? 'pending';
            final String displayStatus = rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();
            
            final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
            final List<dynamic> items = data['items'] ?? [];
            
            DateTime? createdAt;
            if (data['createdAt'] != null) {
              createdAt = (data['createdAt'] as Timestamp).toDate();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Area
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(rawStatus).withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade100, width: 1.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                                child: Icon(Icons.receipt_long, color: Theme.of(context).primaryColor, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${orderDoc.id.substring(0, 8).toUpperCase()}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAt != null ? DateFormat('MMM d, yyyy - h:mm a').format(createdAt) : 'Unknown time',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _getStatusColor(rawStatus).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 10, color: _getStatusColor(rawStatus)),
                                const SizedBox(width: 8),
                                Text(
                                  displayStatus,
                                  style: TextStyle(
                                    color: _getStatusColor(rawStatus),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content Area
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Customer Details Column
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.person, size: 20, color: Colors.teal),
                                      SizedBox(width: 8),
                                      Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(Icons.badge_outlined, data['customerName'] ?? 'N/A'),
                                  _buildInfoRow(Icons.phone_outlined, data['phone'] ?? 'N/A'),
                                  _buildInfoRow(Icons.location_on_outlined, data['address'] ?? 'N/A'),
                                  _buildInfoRow(Icons.credit_card_outlined, data['paymentMethod'] ?? 'N/A'),
                                  if (data['note'] != null && data['note'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.orange.shade200),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.note_alt_outlined, size: 18, color: Colors.orange.shade800),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              data['note'], 
                                              style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w500)
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // Order Items Column
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.fastfood_outlined, size: 20, color: Colors.teal),
                                      SizedBox(width: 8),
                                      Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  ...items.map((item) {
                                    final title = item['title'] ?? 'Item';
                                    final qty = item['quantity'] ?? 1;
                                    final price = item['price'] ?? 0;
                                    final addons = (item['selectedAddons'] as List<dynamic>?) ?? [];
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('${qty}x', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                if (addons.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text('+ ${addons.join(", ")}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          
                          // Total Column
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Total Amount', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    Text(
                                      '\$${totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Action Buttons Area
                    if (filterStatus != null && filterStatus != 'all' && rawStatus.toLowerCase() != 'delivered' && rawStatus.toLowerCase() != 'rejected') ...[
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        color: Colors.grey.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: _buildActionButtons(orderDoc.reference, rawStatus),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 64, color: Colors.teal.shade300),
          ),
          const SizedBox(height: 24),
          Text(
            'No orders found',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 8),
          Text(
            'Incoming orders will appear here.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'preparing':
        return Colors.blue.shade600;
      case 'ready':
        return Colors.purple.shade600;
      case 'delivered':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  List<Widget> _buildActionButtons(DocumentReference docRef, String status) {
    if (status.toLowerCase() == 'pending') {
      return [
        TextButton.icon(
          onPressed: () => _updateOrderStatus(docRef, 'rejected'),
          icon: const Icon(Icons.close),
          label: const Text('Reject Order'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(docRef, 'preparing'),
          icon: const Icon(Icons.restaurant),
          label: const Text('Accept & Prepare'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ];
    } else if (status.toLowerCase() == 'preparing') {
      return [
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(docRef, 'ready'),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Mark as Ready'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ];
    } else if (status.toLowerCase() == 'ready') {
      return [
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(docRef, 'delivered'),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Mark as Delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          toolbarHeight: 80,
          title: const Text('Manage Orders', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: TabBar(
                isScrollable: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.teal,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                tabs: const [
                  Tab(text: '   All Orders   '),
                  Tab(text: '   Pending   '),
                  Tab(text: '   Preparing   '),
                  Tab(text: '   Ready   '),
                  Tab(text: '   Delivered   '),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(null),
            _buildOrderList('pending'),
            _buildOrderList('preparing'),
            _buildOrderList('ready'),
            _buildOrderList('delivered'),
          ],
        ),
      ),
    );
  }
}

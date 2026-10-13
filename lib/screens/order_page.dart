import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Used to check if platform is Windows/Android
import '../services/printer_service.dart'; // Used to fetch the saved printer config
import '../widgets/main_receipt.dart';
import '../widgets/kot_receipt.dart';
import '../models/receipt_order_model.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _updateOrderStatus(
    DocumentReference docRef,
    String newStatus, [
    //optional data parameter used for passing order data to the receipt generator
    // it will be used when reciving order from customer app
    Map<String, dynamic>? orderData,
  ]) async {
    // If the customer app status delivered, calculate payment breakdown (cash vs credit)
    if (newStatus == 'delivered' && orderData != null) {
      final double totalAmount =
          (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final String paymentMethod =
          (orderData['paymentMethod']?.toString().toLowerCase() ?? '');
      bool isCash = paymentMethod.contains('cash');

      // ─────────────────────────────────────────────────────────────────
      // CONTINUOUS SALE NUMBER FLOW (Intertwined with POS sales)
      // ─────────────────────────────────────────────────────────────────
      // Check if this order already has a saleNumber assigned to avoid double-incrementing
      String saleNumber = orderData['saleNumber']?.toString() ?? '';
      if (saleNumber.isEmpty) {
        final settingsRef =
            _firestore.collection('settings').doc('pos_counters');
        final settingsDoc = await settingsRef.get();
        final int currentTotal =
            (settingsDoc.data()?['totalTokens'] as num?)?.toInt() ?? 0;
        final int nextTotal = currentTotal + 1;

        // Uses the exact same SAL001, SAL002 sequence format as POS
        saleNumber = 'SAL${nextTotal.toString().padLeft(3, '0')}';

        // Increment the shared counter in settings so the next sale (POS or Customer App) continues seamlessly
        await settingsRef.set({
          'totalTokens': nextTotal,
        }, SetOptions(merge: true));
      }

      // Update the order doc with status, continuous saleNumber, and payment breakdown so receipts print correctly
      await docRef.update({
        'status': newStatus,
        'saleNumber': saleNumber,
        'cashAmount': isCash ? totalAmount : 0.0,
        'creditAmount': isCash ? 0.0 : totalAmount,
        'balance': 0.0,
      });

      final salesData = {
        'orderId': docRef.id,
        'displayOrderId': docRef.id,
        'saleNumber': saleNumber, // <── Continuous SAL00X sequence shared with POS
        'tokenNumber': orderData['tokenNumber'],
        'source': 'Customer App',
        'orderType': orderData['orderType'] ?? 'Delivery',
        'tableId': orderData['tableId'] ?? 'N/A',
        'tableName': orderData['tableName'] ?? 'N/A',
        'customerName': orderData['customerName'] ?? '',
        'phone': orderData['phone'] ?? '',
        'address': orderData['address'] ?? '',
        'items': orderData['items'] ?? [],
        'totalAmount': totalAmount,
        'cashAmount': isCash ? totalAmount : 0.0,
        'creditAmount': isCash ? 0.0 : totalAmount,
        'balance': 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('sales').doc(docRef.id).set(salesData);
    } else {
      // Normal status update (e.g. pending, in-progress, etc.)
      await docRef.update({'status': newStatus});
    }
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
          return Center(
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        //to not show the pos orders in order page

        var orders = snapshot.data!.docs.toList();
        orders = orders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['source'] != 'POS';
        }).toList();

        if (filterStatus != null) {
          orders = orders.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status =
                (data['status'] as String?)?.toLowerCase() ?? 'pending';
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
            final String displayStatus =
                rawStatus[0].toUpperCase() +
                rawStatus.substring(1).toLowerCase();

            final String displayOrderId =
                (data['orderId'] ?? data['displayOrderId'] ?? orderDoc.id)
                    .toString();

            final double totalAmount =
                (data['totalAmount'] as num?)?.toDouble() ?? 0;
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(rawStatus).withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade100,
                            width: 1.5,
                          ),
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
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${displayOrderId.toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAt != null
                                        ? DateFormat(
                                            'MMM d, yyyy - h:mm a',
                                          ).format(createdAt)
                                        : 'Unknown time',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Conditionally display the print icon if the app is running on Windows or Android
                              if (defaultTargetPlatform ==
                                      TargetPlatform.windows ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.android)
                                IconButton(
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    color: Colors.grey,
                                  ),
                                  tooltip: 'Print Order',
                                  onPressed: () async {
                                    // Check if ANY printer is configured
                                    bool hasPrinter =
                                        await PrinterService.hasConfiguredPrinter();

                                    if (context.mounted) {
                                      if (hasPrinter) {
                                        // Show loading indicator in a SnackBar
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Sending Order #${displayOrderId.toUpperCase()} to printer...',
                                            ),
                                          ),
                                        );

                                        // Trigger the print job via the centralized service
                                        final String status =
                                            data['status'] ?? 'pending';

                                        // 1. Generate strongly-typed receipt model
                                        final receiptModel =
                                            ReceiptOrderModel.fromMap(
                                              data,
                                              displayOrderId,
                                            );

                                        // 2. Generate receipt bytes based on order status
                                        final List<int> printBytes =
                                            (status == 'delivered')
                                                ? await MainReceipt.generate(
                                                  receiptModel,
                                                )
                                                : await KotReceipt.generate(
                                                  receiptModel,
                                                );

                                        // 2. Dispatch to centralized PrinterService
                                        // PrinterService automatically handles device discovery and platform routing (Android BLE/USB vs Windows).
                                        final String? errorMsg =
                                            await PrinterService.printBytes(
                                              printBytes,
                                            );

                                        if (context.mounted) {
                                          if (errorMsg == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Print job sent successfully!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed: $errorMsg',
                                                ),
                                                backgroundColor: Colors.red,
                                                duration: const Duration(
                                                  seconds: 5,
                                                ), // Keep it on screen longer to read
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        // Show error if printer is not configured
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No printer configured! Please set it up on the Home Page.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    rawStatus,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: _getStatusColor(rawStatus),
                                    ),
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
                                      Icon(
                                        Icons.person,
                                        size: 20,
                                        color: Colors.teal,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Customer Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  _buildInfoRow(
                                    Icons.badge_outlined,
                                    data['customerName'] ?? 'N/A',
                                  ),
                                  _buildInfoRow(
                                    Icons.phone_outlined,
                                    data['phone'] ?? 'N/A',
                                  ),
                                  _buildInfoRow(
                                    Icons.location_on_outlined,
                                    data['address'] ?? 'N/A',
                                  ),
                                  _buildInfoRow(
                                    Icons.credit_card_outlined,
                                    data['paymentMethod'] ?? 'N/A',
                                  ),
                                  if (data['note'] != null &&
                                      data['note']
                                          .toString()
                                          .trim()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.note_alt_outlined,
                                            size: 18,
                                            color: Colors.orange.shade800,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              data['note'],
                                              style: TextStyle(
                                                color: Colors.orange.shade900,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
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
                                      Icon(
                                        Icons.fastfood_outlined,
                                        size: 20,
                                        color: Colors.teal,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Order Items',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  ...items.map((item) {
                                    final title =
                                        item['nameEn'] ??
                                        item['title'] ??
                                        item['name'] ??
                                        'Item';
                                    final qty = (item['quantity'] is num)
                                        ? (item['quantity'] as num).toInt()
                                        : (item['qty'] is num)
                                            ? (item['qty'] as num).toInt()
                                            : int.tryParse(
                                                item['quantity']?.toString() ??
                                                    item['qty']?.toString() ??
                                                    '1',
                                              ) ??
                                              1;
                                    final double basePrice =
                                        (item['price'] is num)
                                            ? (item['price'] as num).toDouble()
                                            : double.tryParse(
                                                  item['price']?.toString() ??
                                                      '0',
                                                ) ??
                                                0.0;
                                    final List<dynamic> addons =
                                        (item['addons'] is List)
                                            ? item['addons']
                                            : (item['selectedAddons'] is List)
                                                ? item['selectedAddons']
                                                : (item['addOns'] is List)
                                                    ? item['addOns']
                                                    : [];

                                    double addonsTotal = 0.0;
                                    List<String> addonNames = [];
                                    for (var addon in addons) {
                                      if (addon is Map) {
                                        addonsTotal +=
                                            (addon['price'] as num?)?.toDouble() ??
                                            double.tryParse(addon['price']?.toString() ?? '0') ??
                                            0.0;
                                        String addonName =
                                            addon['nameEn']?.toString() ??
                                            addon['title']?.toString() ??
                                            addon['name']?.toString() ??
                                            'Addon';
                                        if (addonName.isNotEmpty) {
                                          addonNames.add(addonName);
                                        }
                                      } else if (addon != null && addon.toString().trim().isNotEmpty) {
                                        addonNames.add(addon.toString().trim());
                                      }
                                    }

                                    final double finalPrice =
                                        basePrice + addonsTotal;

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${qty}x',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal.shade800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (addonNames.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      '+ ${addonNames.join(", ")}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '\$${finalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total Amount',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '\$${totalAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
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
                    if (filterStatus != null &&
                        filterStatus != 'all' &&
                        rawStatus.toLowerCase() != 'delivered' &&
                        rawStatus.toLowerCase() != 'rejected') ...[
                      const Divider(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        color: Colors.grey.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: _buildActionButtons(
                            orderDoc.reference,
                            rawStatus,
                            data,
                          ),
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
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.teal.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
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

  List<Widget> _buildActionButtons(
    DocumentReference docRef,
    String status,
    Map<String, dynamic> data,
  ) {
    if (status.toLowerCase() == 'pending') {
      return [
        TextButton.icon(
          onPressed: () => _updateOrderStatus(docRef, 'rejected'),
          icon: const Icon(Icons.close),
          label: const Text('Reject Order'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ];
    } else if (status.toLowerCase() == 'ready') {
      return [
        ElevatedButton.icon(
          onPressed: () => _updateOrderStatus(docRef, 'delivered', data),
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Mark as Delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          title: const Text(
            'Manage Orders',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.teal,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
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

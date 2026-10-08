import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/table_model.dart';
import '../models/category_model.dart';
// Assuming you have a ProductModel, if not we will read maps
// import '../models/product_model.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TableModel? _selectedTable;
  String _selectedOrderType = 'Takeaway';
  final List<String> _orderTypes = [
    'Takeaway',
    'Dine In',
    'Drive Through',
    'Delivery',
  ];

  int _currentToken = 1;
  int _totalTokens = 0;

  late final Stream<QuerySnapshot> _tablesStream;
  late final Stream<QuerySnapshot> _categoriesStream;
  late final Stream<QuerySnapshot> _allProductsStream;

  @override
  void initState() {
    super.initState();
    _tablesStream = _firestore.collection('tables').snapshots();
    _categoriesStream = _firestore
        .collection('category')
        .where('isDeleted', isEqualTo: false)
        .orderBy('serialNumber')
        .snapshots();
    _allProductsStream = _firestore
        .collection('product')
        .where('isDeleted', isEqualTo: false)
        .snapshots();
    _initSettings();
  }

  Future<void> _initSettings() async {
    final settingsRef = _firestore.collection('settings').doc('pos_counters');
    final doc = await settingsRef.get();
    if (!doc.exists) {
      await settingsRef.set({'currentToken': 1, 'totalTokens': 0});
    } else {
      setState(() {
        _currentToken = doc.data()?['currentToken'] ?? 1;
        _totalTokens = doc.data()?['totalTokens'] ?? 0;
      });
    }
  }

  Future<void> _resetToken() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Token?'),
        content: const Text(
          'Do you want to reset the daily token number back to 1?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('settings').doc('pos_counters').update({
        'currentToken': 1,
      });
      setState(() => _currentToken = 1);
    }
  }

  Future<void> _addTableDirectly() async {
    final TextEditingController tableNumController = TextEditingController();
    final TextEditingController tableNameController = TextEditingController();
    final TextEditingController guestCountController = TextEditingController();

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Quick Table',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tableNumController,
              decoration: InputDecoration(
                labelText: 'Table Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tableNameController,
              decoration: InputDecoration(
                labelText: 'Table Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: guestCountController,
              decoration: InputDecoration(
                labelText: 'Guest Count',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (save == true && tableNumController.text.isNotEmpty) {
      final docRef = _firestore.collection('tables').doc();
      final table = TableModel(
        id: docRef.id,
        tableNumber: tableNumController.text,
        tableName: tableNameController.text,
        guestCount: int.tryParse(guestCountController.text) ?? 0,
        reference: docRef,
        items: [],
      );
      await docRef.set(table.toMap());
    }
  }

  void _addToCart(Map<String, dynamic> productData) async {
    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a table first!')),
      );
      return;
    }

    final tableRef = _selectedTable!.reference!;
    List<dynamic> currentItems = List.from(_selectedTable!.items);

    // Check if product already in cart with NO addons
    int existingIndex = currentItems.indexWhere(
      (item) =>
          item['productId'] == productData['id'] &&
          (item['addons'] as List? ?? []).isEmpty,
    );

    if (existingIndex >= 0) {
      // Increase quantity
      currentItems[existingIndex]['quantity'] += 1;
    } else {
      // Add new
      currentItems.add({
        'productId': productData['id'] ?? productData['productId'],
        'nameEn': productData['nameEn'],
        'nameAr': productData['nameAr'],
        'price': productData['price'] ?? 0.0,
        'quantity': 1,
        'addons': [],
      });
    }
    setState(() {
      _selectedTable!.items = currentItems;
    });
    tableRef.update({'items': currentItems});
  }

  void _updateQuantity(int index, int delta) async {
    if (_selectedTable == null) return;
    List<dynamic> currentItems = List.from(_selectedTable!.items);

    currentItems[index]['quantity'] += delta;
    if (currentItems[index]['quantity'] <= 0) {
      currentItems.removeAt(index);
    }
    setState(() {
      _selectedTable!.items = currentItems;
    });
    _selectedTable!.reference!.update({'items': currentItems});
  }

  Future<void> _openAddons(int cartIndex) async {
    if (_selectedTable == null) return;

    final addonsSnapshot = await _firestore
        .collection('addon')
        .where('isDeleted', isEqualTo: false)
        .get();
    final availableAddons = addonsSnapshot.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    List<dynamic> currentItems = List.from(_selectedTable!.items);
    List<dynamic> selectedAddons = List.from(
      currentItems[cartIndex]['addons'] ?? [],
    );

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Select Add-ons',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 600,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: availableAddons.length,
                  itemBuilder: (context, i) {
                    final addon = availableAddons[i];
                    final isSelected = selectedAddons.any(
                      (a) => a['id'] == addon['id'],
                    );

                    return GestureDetector(
                      onTap: () {
                        setStateSB(() {
                          if (!isSelected) {
                            selectedAddons.add({
                              'id': addon['id'],
                              'nameEn': addon['nameEn'],
                              'nameAr': addon['nameAr'],
                              'price': addon['price'],
                            });
                          } else {
                            selectedAddons.removeWhere(
                              (a) => a['id'] == addon['id'],
                            );
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.orange.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.orange
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            if (!isSelected)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${addon['nameEn']} / ${addon['nameAr']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.orange.shade900
                                          : Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? Colors.orange
                                      : Colors.grey.shade400,
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              '\$${addon['price']}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (save == true) {
      currentItems[cartIndex]['addons'] = selectedAddons;

      final updatedItem = currentItems[cartIndex];

      int duplicateIndex = currentItems.indexWhere((item) {
        if (currentItems.indexOf(item) == cartIndex) return false;
        if (item['productId'] != updatedItem['productId']) return false;

        List a1 = item['addons'] as List? ?? [];
        List a2 = updatedItem['addons'] as List? ?? [];
        if (a1.length != a2.length) return false;

        final ids1 = a1.map((a) => a['id'].toString()).toSet();
        final ids2 = a2.map((a) => a['id'].toString()).toSet();
        return ids1.length == ids2.length && ids1.containsAll(ids2);
      });

      if (duplicateIndex >= 0) {
        currentItems[duplicateIndex]['quantity'] =
            (currentItems[duplicateIndex]['quantity'] as int) +
            (updatedItem['quantity'] as int);
        currentItems.removeAt(cartIndex);
      }

      // We restore the local setState assignment.
      setState(() {
        _selectedTable!.items = currentItems;
      });

      _selectedTable!.reference!.update({'items': currentItems});
    }
  }

  Future<Map<String, double>?> _showPaymentDialog(double totalAmount) async {
    double cashAmount = 0.0;
    double creditAmount = 0.0;
    double balance = totalAmount;

    final TextEditingController cashController = TextEditingController();
    final TextEditingController creditController = TextEditingController();

    bool cashEditable = false;
    bool creditEditable = false;

    return showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            void updateBalance() {
              cashAmount = double.tryParse(cashController.text) ?? 0.0;
              creditAmount = double.tryParse(creditController.text) ?? 0.0;
              balance = totalAmount - cashAmount - creditAmount;
              setStateSB(() {});
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Checkout Payment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: cashController,
                      readOnly: !cashEditable,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Cash',
                        prefixIcon: const Icon(Icons.money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) => updateBalance(),
                      onTap: () {
                        if (!cashEditable) {
                          if (cashController.text.isEmpty && balance > 0) {
                            cashController.text = balance.toStringAsFixed(2);
                            updateBalance();
                          }
                          setStateSB(() => cashEditable = true);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: creditController,
                      readOnly: !creditEditable,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Credit',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (val) => updateBalance(),
                      onTap: () {
                        if (!creditEditable) {
                          if (creditController.text.isEmpty && balance > 0) {
                            creditController.text = balance.toStringAsFixed(2);
                            updateBalance();
                          }
                          setStateSB(() => creditEditable = true);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          balance < 0 ? 'Change Due' : 'Balance',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${balance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: balance <= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: balance <= 0
                      ? () => Navigator.pop(context, {
                          'cash': cashAmount,
                          'credit': creditAmount,
                          'balance': balance,
                        })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.orange.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Complete Order',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkout() async {
    if (_selectedTable == null || _selectedTable!.items.isEmpty) return;

    // Generate Order ID based on type
    String prefix = 'ORD';
    if (_selectedOrderType == 'Takeaway')
      prefix = 'ORDTKW';
    else if (_selectedOrderType == 'Dine In')
      prefix = 'ORDDIN';
    else if (_selectedOrderType == 'Drive Through')
      prefix = 'ORDDRV';
    else if (_selectedOrderType == 'Delivery')
      prefix = 'ORDDEL';

    final saleNumber = 'SAL${(_totalTokens + 1).toString().padLeft(3, '0')}';
    final orderId = '$prefix${(_totalTokens + 1).toString().padLeft(4, '0')}';

    final double totalAmount = _selectedTable!.items.fold(0.0, (sum, item) {
      double addonsTotal = (item['addons'] as List).fold(
        0.0,
        (s, a) => s + (double.tryParse(a['price'].toString()) ?? 0.0),
      );
      double itemPrice = double.tryParse(item['price'].toString()) ?? 0.0;
      return sum + ((itemPrice + addonsTotal) * (item['quantity'] as int));
    });

    final paymentResult = await _showPaymentDialog(totalAmount);
    if (paymentResult == null) return; // User cancelled payment

    final orderData = {
      'orderId': orderId,
      'saleNumber': saleNumber,
      'tokenNumber': _currentToken,
      'source': 'POS',
      'orderType': _selectedOrderType,
      'tableId': _selectedTable!.id,
      'items': _selectedTable!.items,
      'totalAmount': totalAmount,
      'cashAmount': paymentResult['cash'],
      'creditAmount': paymentResult['credit'],
      'balance': paymentResult['balance'],
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save order
    await _firestore.collection('orders').doc(orderId).set(orderData);

    // Save to sales collection
    final salesData = {
      'orderId': orderId,
      'displayOrderId': orderId,
      'saleNumber': saleNumber,
      'source': 'POS',
      'orderType': _selectedOrderType,
      'tableId': _selectedTable!.id,
      'tableName': _selectedTable!.tableNumber,
      'totalAmount': totalAmount,
      'cashAmount': paymentResult['cash'],
      'creditAmount': paymentResult['credit'],
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _firestore.collection('sales').doc(orderId).set(salesData);

    // Update Counters
    final nextToken = _currentToken + 1;
    final nextTotal = _totalTokens + 1;
    await _firestore.collection('settings').doc('pos_counters').update({
      'currentToken': nextToken,
      'totalTokens': nextTotal,
    });

    // Clear cart
    await _selectedTable!.reference!.update({'items': []});

    if (!mounted) return;

    setState(() {
      _currentToken = nextToken;
      _totalTokens = nextTotal;
      _selectedTable!.items = [];
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checkout Complete: $orderId')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'POS System',
          style: TextStyle(color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Row(
        children: [
          // 1. Tables Section (Left)
          Container(
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _addTableDirectly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 40),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _tablesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final tables = snapshot.data!.docs;

                      if (_selectedTable == null && tables.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            final tData =
                                tables.first.data() as Map<String, dynamic>;
                            setState(() {
                              _selectedTable = TableModel.fromMap(
                                tData,
                                tables.first.id,
                                reference: tables.first.reference,
                              );
                            });
                          }
                        });
                      }

                      return ListView.builder(
                        itemCount: tables.length,
                        itemBuilder: (context, index) {
                          final tData =
                              tables[index].data() as Map<String, dynamic>;
                          final table = TableModel.fromMap(
                            tData,
                            tables[index].id,
                            reference: tables[index].reference,
                          );

                          // We intentionally do not auto-sync via toString()
                          // to prevent double-render glitches during local edits.

                          final isSelected = _selectedTable?.id == table.id;
                          return InkWell(
                            onTap: () => setState(() => _selectedTable = table),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  table.tableNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Products & Categories Section (Middle)
          Expanded(
            flex: 3,
            child: StreamBuilder<QuerySnapshot>(
              stream: _categoriesStream,
              builder: (context, catSnapshot) {
                if (catSnapshot.hasError) {
                  print("Category Stream Error: ${catSnapshot.error}");
                  return Center(child: Text('Error: ${catSnapshot.error}'));
                }
                if (!catSnapshot.hasData)
                  return const SizedBox(
                    height: 50,
                    child: Center(child: CircularProgressIndicator()),
                  );
                final categories = catSnapshot.data!.docs;

                if (categories.isEmpty)
                  return const SizedBox(
                    height: 50,
                    child: Center(child: Text('No Categories')),
                  );

                return DefaultTabController(
                  length: categories.length + 1,
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white70,
                          indicatorColor: Colors.white,
                          indicatorWeight: 4,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: [
                            const Tab(
                              child: Text(
                                'All',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            ...categories.map((c) {
                              final data = c.data() as Map<String, dynamic>;
                              return Tab(
                                child: Text(
                                  data['nameEn'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 1. ALL PRODUCTS TAB
                            StreamBuilder<QuerySnapshot>(
                              stream: _allProductsStream,
                              builder: (context, prodSnapshot) {
                                if (prodSnapshot.hasError)
                                  return const Center(
                                    child: Text('Error loading products'),
                                  );
                                if (!prodSnapshot.hasData)
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );

                                final products = prodSnapshot.data!.docs;
                                return _buildProductGrid(products);
                              },
                            ),
                            // 2. CATEGORY SPECIFIC TABS
                            ...categories.map((c) {
                              // Products Grid for this category
                              return StreamBuilder<QuerySnapshot>(
                                stream: _firestore
                                    .collection('product')
                                    .where('categoryId', isEqualTo: c.id)
                                    .where('isDeleted', isEqualTo: false)
                                    .snapshots(),
                                builder: (context, prodSnapshot) {
                                  if (prodSnapshot.hasError) {
                                    print(
                                      "Product Stream Error: ${prodSnapshot.error}",
                                    );
                                    return Center(
                                      child: Text(
                                        'Error: ${prodSnapshot.error}',
                                      ),
                                    );
                                  }
                                  if (!prodSnapshot.hasData)
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  final products = prodSnapshot.data!.docs;
                                  return _buildProductGrid(products);
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. Cart Section (Right)
          Container(
            width: 360,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 15,
                  offset: const Offset(-5, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Area: Order Type & Token info
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Type',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedOrderType,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey[600],
                                  ),
                                  items: _orderTypes
                                      .map(
                                        (type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(
                                            type,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedOrderType = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _resetToken,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Token ID',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 40,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[50],
                                ),
                                child: Text(
                                  '#${_currentToken.toString().padLeft(3, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Order Items Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Items',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTable == null
                                ? '0'
                                : '${_selectedTable!.items.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Table',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTable == null
                                ? '--'
                                : _selectedTable!.tableNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 20,
                  ),
                  child: Divider(color: Colors.grey[200]),
                ),

                // Cart Items List
                Expanded(
                  child: _selectedTable == null || _selectedTable!.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cart is empty',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _selectedTable!.items.length,
                          itemBuilder: (context, index) {
                            final item = _selectedTable!.items[index];
                            final addons = item['addons'] as List? ?? [];
                            double addonsTotal = addons.fold(
                              0.0,
                              (s, a) =>
                                  s +
                                  (double.tryParse(a['price'].toString()) ??
                                      0.0),
                            );
                            double itemPrice =
                                double.tryParse(item['price'].toString()) ??
                                0.0;
                            double finalPrice = itemPrice + addonsTotal;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[100]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.01),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Image placeholder
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.fastfood,
                                            color: Colors.orange,
                                            size: 24,
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
                                              item['nameEn'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item['nameAr'] ?? '',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (addons.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              ...addons.map(
                                                (a) => Text(
                                                  '+ ${a['nameEn']} / ${a['nameAr']} (\$${a['price']})',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Quantity controls
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () =>
                                                _updateQuantity(index, -1),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 16,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 36,
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${item['quantity']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () =>
                                                _updateQuantity(index, 1),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          InkWell(
                                            onTap: () => _openAddons(index),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Total price for this item row
                                      Text(
                                        '\$${(finalPrice * item['quantity']).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Order Summary Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Order Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Calculate totals
                      Builder(
                        builder: (context) {
                          double subTotal = 0.0;
                          if (_selectedTable != null) {
                            for (var item in _selectedTable!.items) {
                              double itemPrice =
                                  double.tryParse(item['price'].toString()) ??
                                  0.0;
                              double addonsTotal =
                                  (item['addons'] as List? ?? []).fold(
                                    0.0,
                                    (s, a) =>
                                        s +
                                        (double.tryParse(
                                              a['price'].toString(),
                                            ) ??
                                            0.0),
                                  );
                              subTotal +=
                                  (itemPrice + addonsTotal) *
                                  (item['quantity'] as int);
                            }
                          }
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sub Total',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '\$${subTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                child: Divider(color: Colors.grey[200]),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    '\$${subTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed:
                            (_selectedTable == null ||
                                _selectedTable!.items.isEmpty)
                            ? null
                            : _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.orange, // matches template's bright orange
                          disabledBackgroundColor: Colors.orange.withOpacity(
                            0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 54),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Checkout',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for rendering the gorgeous product grid
  Widget _buildProductGrid(List<QueryDocumentSnapshot> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No products available.',
              style: TextStyle(color: Colors.grey[500], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final pData = products[index].data() as Map<String, dynamic>;
        pData['id'] = products[index].id;
        return InkWell(
          onTap: () => _addToCart(pData),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.orange.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top placeholder or image area
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.shade50,
                            Colors.orange.shade100,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.fastfood,
                          size: 48,
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  // Bottom Info area
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pData['nameEn'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pData['nameAr'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '\$${pData['price']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

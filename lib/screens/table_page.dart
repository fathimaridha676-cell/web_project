import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/table_model.dart';

class TablePage extends StatefulWidget {
  const TablePage({super.key});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  final CollectionReference _tablesCollection = FirebaseFirestore.instance.collection('tables');

  final TextEditingController _tableNumberController = TextEditingController();
  final TextEditingController _tableNameController = TextEditingController();
  final TextEditingController _guestCountController = TextEditingController();
  String _searchQuery = '';

  Future<void> _addTable() async {
    final String tableNumber = _tableNumberController.text.trim();
    final String tableName = _tableNameController.text.trim();
    final String guestCountText = _guestCountController.text.trim();

    if (tableNumber.isEmpty || tableName.isEmpty || guestCountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final int? guestCount = int.tryParse(guestCountText);
    if (guestCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest count must be a number')),
      );
      return;
    }

    try {
      final docRef = _tablesCollection.doc();
      
      final tableModel = TableModel(
        id: docRef.id,
        tableNumber: tableNumber,
        tableName: tableName,
        guestCount: guestCount,
        reference: docRef,
      );

      await docRef.set(tableModel.toMap());

      _tableNumberController.clear();
      _tableNameController.clear();
      _guestCountController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding table: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteTable(TableModel table) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Table?'),
          content: Text('Are you sure you want to delete table "${table.tableName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await table.reference?.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Table "${table.tableName}" deleted.')),
        );
      }
    }
  }

  Future<void> _editTable(TableModel table) async {
    final TextEditingController editNumController = TextEditingController(text: table.tableNumber);
    final TextEditingController editNameController = TextEditingController(text: table.tableName);
    final TextEditingController editGuestController = TextEditingController(text: table.guestCount.toString());

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Table'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editNumController,
                  decoration: const InputDecoration(labelText: 'Table Number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: editNameController,
                  decoration: const InputDecoration(labelText: 'Table Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: editGuestController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Guest Count'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (save == true) {
      if (editNumController.text.isEmpty || editNameController.text.isEmpty || editGuestController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fields cannot be empty.')),
          );
        }
        return;
      }
      
      int guestCount = int.tryParse(editGuestController.text) ?? 0;
      
      await table.reference?.update({
        'tableNumber': editNumController.text,
        'tableName': editNameController.text,
        'guestCount': guestCount,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table updated successfully!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _tableNameController.dispose();
    _guestCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Tables', style: TextStyle(color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Section
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Table',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _tableNumberController,
                      decoration: InputDecoration(
                        labelText: 'Table Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _tableNameController,
                      decoration: InputDecoration(
                        labelText: 'Table Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _guestCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Guest Count',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _addTable,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Table', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // List Section
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0).copyWith(bottom: 0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tables...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _tablesCollection.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final tName = (data['tableName'] ?? '').toString().toLowerCase();
                        final tNum = (data['tableNumber'] ?? '').toString().toLowerCase();
                        return tName.contains(_searchQuery) || tNum.contains(_searchQuery);
                      }).toList();

                      // Sort numerically if possible
                      docs.sort((a, b) {
                        final numA = (a.data() as Map<String, dynamic>)['tableNumber'] ?? '';
                        final numB = (b.data() as Map<String, dynamic>)['tableNumber'] ?? '';
                        return numA.compareTo(numB);
                      });

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.table_restaurant_outlined, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No Tables found.', style: TextStyle(fontSize: 20, color: Colors.grey[500])),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final table = TableModel.fromMap(data, docs[index].id, reference: docs[index].reference);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(table.tableNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
                              ),
                              title: Text(table.tableName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Guests: ${table.guestCount}', style: TextStyle(color: Colors.grey[700])),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.blue, size: 28),
                                    onPressed: () => _editTable(table),
                                    tooltip: 'Edit',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
                                    onPressed: () => _confirmDeleteTable(table),
                                    tooltip: 'Delete',
                                  ),
                                ],
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
        ],
      ),
    );
  }
}

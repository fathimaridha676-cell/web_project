import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final CollectionReference _categoryCollection = FirebaseFirestore.instance
      .collection('category');

  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _nameArController = TextEditingController();
  String _searchQuery = '';

  Future<void> _saveCategory() async {
    if (_nameEnController.text.isEmpty || _nameArController.text.isEmpty) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Please enter category names.')),
      );
      return;
    }

    int serialNumber = int.tryParse(_serialController.text) ?? 0;

    DocumentReference docRef = _categoryCollection.doc();
    await docRef.set({
      'categoryId': docRef.id,
      'serialNumber': serialNumber,
      'nameEn': _nameEnController.text,
      'nameAr': _nameArController.text,
      'isDeleted': false,
    });

    _serialController.clear();
    _nameEnController.clear();
    _nameArController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Category added successfully!')),
      );
    }
  }

  Future<void> _confirmDeleteCategory(CategoryModel category) async {
    final productsSnapshot = await FirebaseFirestore.instance
        .collection('product')
        .where('categoryId', isEqualTo: category.id)
        .get();

    final associatedDocs = productsSnapshot.docs.where((doc) {
      return (doc.data()['isDeleted'] ?? false) == false;
    }).toList();

    if (!mounted) return;

    final int associatedProductsCount = associatedDocs.length;
    bool deleteAssociatedProducts = false;
    String confirmationName = '';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isNameMatching = confirmationName == category.nameEn;

            return AlertDialog(
              title: const Text('Delete Category?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Are you sure you want to delete "${category.nameEn}"?'),
                  const SizedBox(height: 16),
                  if (associatedProductsCount > 0)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Also delete $associatedProductsCount associated product(s)'),
                      value: deleteAssociatedProducts,
                      onChanged: (value) {
                        setState(() {
                          deleteAssociatedProducts = value ?? false;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  Text('Type "${category.nameEn}" to confirm:'),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: category.nameEn,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        confirmationName = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isNameMatching ? () => Navigator.of(context).pop(true) : null,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      if (deleteAssociatedProducts) {
        for (var doc in associatedDocs) {
          batch.update(doc.reference, {'isDeleted': true});
        }
      }
      
      batch.update(_categoryCollection.doc(category.id), {'isDeleted': true});
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(content: Text('Category "${category.nameEn}" deleted.')),
        );
      }
    }
  }

  Future<void> _editCategory(CategoryModel category) async {
    final TextEditingController editSerialController = TextEditingController(text: category.serialNumber.toString());
    final TextEditingController editNameEnController = TextEditingController(text: category.nameEn);
    final TextEditingController editNameArController = TextEditingController(text: category.nameAr);

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editSerialController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Serial Number'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: editNameEnController,
                  decoration: const InputDecoration(labelText: 'Name (English)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: editNameArController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(labelText: 'Name (Arabic)'),
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
      if (editNameEnController.text.isEmpty || editNameArController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
            const SnackBar(content: Text('Names cannot be empty.')),
          );
        }
        return;
      }
      int serialNumber = int.tryParse(editSerialController.text) ?? 0;
      
      await _categoryCollection.doc(category.id).update({
        'serialNumber': serialNumber,
        'nameEn': editNameEnController.text,
        'nameAr': editNameArController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(content: Text('Category updated successfully!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _serialController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
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
                color: Colors.grey[50],
                border: Border(right: BorderSide(color: Colors.grey[300]!)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create New Category', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _serialController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Serial Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameEnController,
                      decoration: InputDecoration(labelText: 'Category Name (EN)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameArController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(labelText: 'Category Name (AR)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveCategory,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Category', style: TextStyle(fontSize: 16)),
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
                      hintText: 'Search categories...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    stream: _categoryCollection.orderBy('serialNumber').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final nameEn = (data['nameEn'] ?? '').toString().toLowerCase();
                        final nameAr = (data['nameAr'] ?? '').toString().toLowerCase();
                        final matchesSearch = nameEn.contains(_searchQuery) || nameAr.contains(_searchQuery);
                        return data['isDeleted'] != true && matchesSearch;
                      }).toList();

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No Categories found.', style: TextStyle(fontSize: 20, color: Colors.grey[500])),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final category = CategoryModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                          return Card(
                            elevation: 3,
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
                                child: Text('${category.serialNumber}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16)),
                              ),
                              title: Text(category.nameEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Arabic: ${category.nameAr}', style: TextStyle(color: Colors.grey[700])),
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.blue, size: 28),
                                    onPressed: () => _editCategory(category),
                                    tooltip: 'Edit',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
                                    onPressed: () => _confirmDeleteCategory(category),
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

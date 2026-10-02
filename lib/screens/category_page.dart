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

  Future<void> _saveCategory() async {
    if (_nameEnController.text.isEmpty || _nameArController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    });

    _serialController.clear();
    _nameEnController.clear();
    _nameArController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully!')),
      );
    }
  }

  Future<void> _confirmDeleteCategory(CategoryModel category) async {
    final productsSnapshot = await FirebaseFirestore.instance
        .collection('product')
        .where('categoryId', isEqualTo: category.id)
        .get();

    if (!mounted) return;

    final int associatedProductsCount = productsSnapshot.docs.length;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Category?'),
          content: Text(
            'Are you sure you want to delete "${category.nameEn}"?\n\n'
            '${associatedProductsCount > 0 ? 'Warning: This will also delete $associatedProductsCount associated product(s).' : 'This action cannot be undone.'}',
          ),
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
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in productsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_categoryCollection.doc(category.id));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Category "${category.nameEn}" deleted.')),
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
      appBar: AppBar(title: const Text('Categories')),
      body: Column(
        children: [
          // Add Category Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add New Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _serialController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Serial Number',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameEnController,
                            decoration: const InputDecoration(
                              labelText: 'Name (English)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameArController,
                            decoration: const InputDecoration(
                              labelText: 'Name (Arabic)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _saveCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('Save Category'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Categories List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _categoryCollection.orderBy('serialNumber').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('No categories found.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final category = CategoryModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${category.serialNumber}'),
                        ),
                        title: Text(category.nameEn),
                        subtitle: Text(category.nameAr),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Delete Category',
                          onPressed: () => _confirmDeleteCategory(category),
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
    );
  }
}

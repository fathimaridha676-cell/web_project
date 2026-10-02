import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/addon_model.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final CollectionReference _productCollection = FirebaseFirestore.instance
      .collection('product');
  final CollectionReference _categoryCollection = FirebaseFirestore.instance
      .collection('category');
  final CollectionReference _addonCollection = FirebaseFirestore.instance
      .collection('addon');

  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _nameArController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _extraIngredientsController =
      TextEditingController();
  String? _selectedCategoryId;
  Map<String, double> _selectedAddons = {};
  Map<String, TextEditingController> _addonPriceControllers = {};

  List<CategoryModel> _categories = [];
  StreamSubscription<QuerySnapshot>? _categorySubscription;
  
  List<AddonModel> _addons = [];
  StreamSubscription<QuerySnapshot>? _addonSubscription;

  late Stream<QuerySnapshot> _productStream;

  @override
  void initState() {
    super.initState();
    _productStream = _productCollection.snapshots();
    _fetchCategories();
    _fetchAddons();
  }

  void _fetchAddons() {
    _addonSubscription = _addonCollection.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _addons = snapshot.docs
              .where((doc) => (doc.data() as Map<String, dynamic>)['isDeleted'] != true)
              .map((doc) => AddonModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          for (var addon in _addons) {
            if (!_addonPriceControllers.containsKey(addon.id)) {
              _addonPriceControllers[addon.id] = TextEditingController(text: addon.price.toStringAsFixed(2));
            }
          }
        });
      }
    });
  }

  void _fetchCategories() {
    _categorySubscription = _categoryCollection
        .orderBy('serialNumber')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _categories = snapshot.docs
                  .where((doc) {
                    return (doc.data() as Map<String, dynamic>)['isDeleted'] !=
                        true;
                  })
                  .map((doc) {
                    return CategoryModel.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );
                  })
                  .toList();
              if (_selectedCategoryId != null &&
                  !_categories.any((c) => c.id == _selectedCategoryId)) {
                _selectedCategoryId = null;
              }
            });
          }
        });
  }

  Future<void> _saveProduct() async {
    if (_nameEnController.text.isEmpty ||
        _nameArController.text.isEmpty ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a category.'),
        ),
      );
      return;
    }

    double price = double.tryParse(_priceController.text) ?? 0.0;

    DocumentReference docRef = _productCollection.doc();
    await docRef.set({
      'productId': docRef.id,
      'categoryId': _selectedCategoryId,
      'nameEn': _nameEnController.text,
      'nameAr': _nameArController.text,
      'price': price,
      'description': _descriptionController.text,
      'extraIngredients': _extraIngredientsController.text,
      'addonPrices': _selectedAddons,
      'isDeleted': false,
    });

    _nameEnController.clear();
    _nameArController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _extraIngredientsController.clear();
    setState(() {
      _selectedCategoryId = null;
      _selectedAddons.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );
    }
  }

  Future<void> _confirmDeleteProduct(ProductModel product) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product?'),
          content: Text(
            'Are you sure you want to delete "${product.nameEn}"?\n\nThis action cannot be undone.',
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
      await _productCollection.doc(product.id).update({'isDeleted': true});
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(content: Text('Product "${product.nameEn}" deleted.')),
        );
      }
    }
  }

  Future<void> _editProduct(ProductModel product) async {
    final TextEditingController editNameEnController = TextEditingController(
      text: product.nameEn,
    );
    final TextEditingController editNameArController = TextEditingController(
      text: product.nameAr,
    );
    final TextEditingController editPriceController = TextEditingController(
      text: product.price.toString(),
    );
    final TextEditingController editDescriptionController =
        TextEditingController(text: product.description);
    final TextEditingController editExtraIngredientsController =
        TextEditingController(text: product.extraIngredients);
    String? editSelectedCategoryId = product.categoryId;
    Map<String, double> editSelectedAddons = Map.from(product.addonPrices);
    Map<String, TextEditingController> editAddonPriceControllers = {};
    for (var addon in _addons) {
      editAddonPriceControllers[addon.id] = TextEditingController(
        text: editSelectedAddons.containsKey(addon.id) 
              ? editSelectedAddons[addon.id]!.toStringAsFixed(2) 
              : addon.price.toStringAsFixed(2)
      );
    }

    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Product'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value:
                          _categories.any((c) => c.id == editSelectedCategoryId)
                          ? editSelectedCategoryId
                          : null,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.nameEn),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          editSelectedCategoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editNameEnController,
                      decoration: const InputDecoration(
                        labelText: 'Name (English)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editNameArController,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        labelText: 'Name (Arabic)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editDescriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: editExtraIngredientsController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ingredients',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Select Add-ons', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Checkbox(
                          value: editSelectedAddons.length == _addons.length && _addons.isNotEmpty,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                for (var a in _addons) {
                                  editSelectedAddons[a.id] = double.tryParse(editAddonPriceControllers[a.id]!.text) ?? a.price;
                                }
                              } else {
                                editSelectedAddons.clear();
                              }
                            });
                          }
                        ),
                        const Text('Select All'),
                      ],
                    ),
                    Column(
                      children: _addons.map((addon) {
                        final isSelected = editSelectedAddons.containsKey(addon.id);
                        return Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    editSelectedAddons[addon.id] = double.tryParse(editAddonPriceControllers[addon.id]!.text) ?? addon.price;
                                  } else {
                                    editSelectedAddons.remove(addon.id);
                                  }
                                });
                              }
                            ),
                            Expanded(child: Text(addon.nameEn)),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: editAddonPriceControllers[addon.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, prefixText: '\$'),
                                onChanged: (val) {
                                  if (isSelected) {
                                    editSelectedAddons[addon.id] = double.tryParse(val) ?? addon.price;
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
      },
    );

    if (save == true) {
      if (editNameEnController.text.isEmpty ||
          editNameArController.text.isEmpty ||
          editSelectedCategoryId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
            const SnackBar(content: Text('Please fill all fields.')),
          );
        }
        return;
      }
      double price = double.tryParse(editPriceController.text) ?? 0.0;

      await _productCollection.doc(product.id).update({
        'categoryId': editSelectedCategoryId,
        'nameEn': editNameEnController.text,
        'nameAr': editNameArController.text,
        'price': price,
        'description': editDescriptionController.text,
        'extraIngredients': editExtraIngredientsController.text,
        'addonPrices': editSelectedAddons,
      });

      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
      }
    }
  }

  @override
  void dispose() {
    _categorySubscription?.cancel();
    _addonSubscription?.cancel();
    _nameEnController.dispose();
    _nameArController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _extraIngredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
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
                    const Text('Create New Product', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            items: _categories.map((category) {
                              return DropdownMenuItem(value: category.id, child: Text(category.nameEn));
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategoryId = value),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: 'Price', prefixIcon: const Icon(Icons.attach_money), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameEnController,
                      decoration: InputDecoration(labelText: 'Product Name (EN)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameArController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(labelText: 'Product Name (AR)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _extraIngredientsController,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'Ingredients (Line by Line)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Add-ons', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                        const Spacer(),
                        Checkbox(
                          value: _selectedAddons.length == _addons.length && _addons.isNotEmpty,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                for (var a in _addons) {
                                  _selectedAddons[a.id] = double.tryParse(_addonPriceControllers[a.id]!.text) ?? a.price;
                                }
                              } else {
                                _selectedAddons.clear();
                              }
                            });
                          }
                        ),
                        const Text('Select All'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: _addons.map((addon) {
                        final isSelected = _selectedAddons.containsKey(addon.id);
                        return Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAddons[addon.id] = double.tryParse(_addonPriceControllers[addon.id]!.text) ?? addon.price;
                                  } else {
                                    _selectedAddons.remove(addon.id);
                                  }
                                });
                              }
                            ),
                            Expanded(child: Text(addon.nameEn)),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: _addonPriceControllers[addon.id],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(isDense: true, prefixText: '\$'),
                                onChanged: (val) {
                                  if (isSelected) {
                                    _selectedAddons[addon.id] = double.tryParse(val) ?? addon.price;
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveProduct,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Product', style: TextStyle(fontSize: 16)),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Something went wrong'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs.where((doc) {
                  return (doc.data() as Map<String, dynamic>)['isDeleted'] != true;
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fastfood_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No Products found.', style: TextStyle(fontSize: 20, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final product = ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

                    final category = _categories.firstWhere(
                      (c) => c.id == product.categoryId,
                      orElse: () => CategoryModel(id: '', serialNumber: 0, nameEn: 'Unknown', nameAr: 'Unknown'),
                    );

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.fastfood, color: Colors.teal),
                        ),
                        title: Text(product.nameEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('Category: ${category.nameEn}\nPrice: \$${product.price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[700])),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue, size: 28), onPressed: () => _editProduct(product), tooltip: 'Edit'),
                            const SizedBox(width: 8),
                            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 28), onPressed: () => _confirmDeleteProduct(product), tooltip: 'Delete'),
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
    );
  }
}

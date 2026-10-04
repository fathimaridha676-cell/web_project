import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/addon_model.dart';

class AddonPage extends StatefulWidget {
  const AddonPage({super.key});

  @override
  State<AddonPage> createState() => _AddonPageState();
}

class _AddonPageState extends State<AddonPage> {
  final CollectionReference _addonCollection = FirebaseFirestore.instance.collection('addon');
  
  final TextEditingController _nameEnController = TextEditingController();
  final TextEditingController _nameArController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String _searchQuery = '';

  Future<void> _saveAddon() async {
    if (_nameEnController.text.isEmpty || _nameArController.text.isEmpty) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    double price = double.tryParse(_priceController.text) ?? 0.0;
    
    DocumentReference docRef = _addonCollection.doc();
    await docRef.set({
      'addonId': docRef.id,
      'nameEn': _nameEnController.text,
      'nameAr': _nameArController.text,
      'price': price,
      'isDeleted': false,
    });

    _nameEnController.clear();
    _nameArController.clear();
    _priceController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
        const SnackBar(content: Text('Add-on created successfully!')),
      );
    }
  }

  Future<void> _deleteAddon(AddonModel addon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Add-on?'),
        content: Text('Are you sure you want to delete "${addon.nameEn}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _addonCollection.doc(addon.id).update({'isDeleted': true});
    }
  }

  Future<void> _editAddon(AddonModel addon) async {
    final editNameEn = TextEditingController(text: addon.nameEn);
    final editNameAr = TextEditingController(text: addon.nameAr);
    final editPrice = TextEditingController(text: addon.price.toString());

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Add-on'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editNameEn, decoration: const InputDecoration(labelText: 'Name (English)')),
            const SizedBox(height: 8),
            TextField(controller: editNameAr, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'Name (Arabic)')),
            const SizedBox(height: 8),
            TextField(controller: editPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (save == true) {
      await _addonCollection.doc(addon.id).update({
        'nameEn': editNameEn.text,
        'nameAr': editNameAr.text,
        'price': double.tryParse(editPrice.text) ?? 0.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Add-ons'),
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
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
                    const Text('Create New Add-on', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameEnController,
                      decoration: InputDecoration(labelText: 'Add-on Name (EN)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameArController,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(labelText: 'Add-on Name (AR)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Price', prefixIcon: const Icon(Icons.attach_money), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saveAddon,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Add-on', style: TextStyle(fontSize: 16)),
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
                      hintText: 'Search add-ons...',
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
                    stream: _addonCollection.snapshots(),
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
                              Icon(Icons.extension_off, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No Add-ons found.', style: TextStyle(fontSize: 20, color: Colors.grey[500])),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final addon = AddonModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
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
                                child: const Icon(Icons.extension, color: Colors.teal),
                              ),
                              title: Text(addon.nameEn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('Price: \$${addon.price.toStringAsFixed(2)}\nArabic: ${addon.nameAr}', style: TextStyle(color: Colors.grey[700])),
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_note, color: Colors.blue, size: 28),
                                    onPressed: () => _editAddon(addon),
                                    tooltip: 'Edit',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 28),
                                    onPressed: () => _deleteAddon(addon),
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

class ProductModel {
  final String id;
  final String categoryId;
  final String nameEn;
  final String nameAr;
  final double price;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.nameEn,
    required this.nameAr,
    required this.price,
  });

  factory ProductModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ProductModel(
      id: documentId,
      categoryId: data['categoryId'] ?? '',
      nameEn: data['nameEn'] ?? '',
      nameAr: data['nameAr'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': id,
      'categoryId': categoryId,
      'nameEn': nameEn,
      'nameAr': nameAr,
      'price': price,
    };
  }
}

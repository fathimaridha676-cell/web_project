class ProductModel {
  final String id;
  final String categoryId;
  final String nameEn;
  final String nameAr;
  final double price;
  final String description;
  final String extraIngredients;
  final Map<String, double> addonPrices;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.nameEn,
    required this.nameAr,
    required this.price,
    this.description = '',
    this.extraIngredients = '',
    this.addonPrices = const {},
  });

  factory ProductModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ProductModel(
      id: documentId,
      categoryId: data['categoryId'] ?? '',
      nameEn: data['nameEn'] ?? '',
      nameAr: data['nameAr'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      extraIngredients: data['extraIngredients'] ?? '',
      addonPrices: data['addonPrices'] != null
          ? Map<String, double>.from((data['addonPrices'] as Map).map(
              (key, value) => MapEntry(key.toString(), (value as num).toDouble())))
          : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': id,
      'categoryId': categoryId,
      'nameEn': nameEn,
      'nameAr': nameAr,
      'price': price,
      'description': description,
      'extraIngredients': extraIngredients,
      'addonPrices': addonPrices,
    };
  }
}

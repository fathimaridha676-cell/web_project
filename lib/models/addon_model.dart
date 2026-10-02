class AddonModel {
  final String id;
  final String nameEn;
  final String nameAr;
  final double price;

  AddonModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.price,
  });

  factory AddonModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AddonModel(
      id: documentId,
      nameEn: data['nameEn'] ?? '',
      nameAr: data['nameAr'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addonId': id,
      'nameEn': nameEn,
      'nameAr': nameAr,
      'price': price,
    };
  }
}

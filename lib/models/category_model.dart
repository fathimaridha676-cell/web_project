class CategoryModel {
  final String id;
  final int serialNumber;
  final String nameEn;
  final String nameAr;

  CategoryModel({
    required this.id,
    required this.serialNumber,
    required this.nameEn,
    required this.nameAr,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CategoryModel(
      id: documentId,
      serialNumber: data['serialNumber'] ?? 0,
      nameEn: data['nameEn'] ?? '',
      nameAr: data['nameAr'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serialNumber': serialNumber,
      'nameEn': nameEn,
      'nameAr': nameAr,
    };
  }
}

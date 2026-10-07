import 'package:cloud_firestore/cloud_firestore.dart';

class TableModel {
  final String id;
  final String tableNumber;
  final String tableName;
  final int guestCount;
  final DocumentReference? reference;
  List<dynamic> items;

  TableModel({
    required this.id,
    required this.tableNumber,
    required this.tableName,
    required this.guestCount,
    this.reference,
    this.items = const [], // New items field
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'tableName': tableName,
      'guestCount': guestCount,
      'reference': reference,
      'items': items,
    };
  }

  factory TableModel.fromMap(Map<String, dynamic> map, String id, {DocumentReference? reference}) {
    return TableModel(
      id: id,
      tableNumber: map['tableNumber'] ?? '',
      tableName: map['tableName'] ?? '',
      guestCount: map['guestCount'] ?? 0,
      reference: reference ?? map['reference'],
      items: List<dynamic>.from(map['items'] ?? []),
    );
  }
}

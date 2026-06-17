import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCategoryItem {
  const AdminCategoryItem({
    required this.categoryId,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String categoryId;
  final String name;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AdminCategoryItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdRaw = data['createdAt'];
    final updatedRaw = data['updatedAt'];

    return AdminCategoryItem(
      categoryId: (data['categoryId'] as String?)?.trim().isNotEmpty == true
          ? (data['categoryId'] as String).trim()
          : doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Untitled category',
      isActive: data['isActive'] != false,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
      updatedAt: updatedRaw is Timestamp ? updatedRaw.toDate() : null,
    );
  }
}

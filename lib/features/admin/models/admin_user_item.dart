import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserItem {
  const AdminUserItem({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.isBlocked,
    required this.isVerified,
    required this.createdAt,
  });

  final String userId;
  final String name;
  final String email;
  final String role;
  final bool isBlocked;
  final bool isVerified;
  final DateTime? createdAt;

  factory AdminUserItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdRaw = data['createdAt'];

    return AdminUserItem(
      userId: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Unknown user',
      email: (data['email'] as String?)?.trim() ?? '',
      role: (data['role'] as String?)?.trim().toLowerCase() ?? '',
      isBlocked: data['isBlocked'] == true,
      isVerified: data['isVerified'] == true,
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
    );
  }
}

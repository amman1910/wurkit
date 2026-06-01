import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedJobId,
    this.relatedApplicationId,
    this.relatedChatId,
    this.senderId,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? relatedJobId;
  final String? relatedApplicationId;
  final String? relatedChatId;
  final String? senderId;
  final bool isRead;
  final Timestamp? createdAt;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return AppNotification(
      id: doc.id,
      userId: _readString(data['userId']) ?? '',
      type: _readString(data['type']) ?? '',
      title: _readString(data['title']) ?? '',
      body: _readString(data['body']) ?? '',
      relatedJobId: _readString(data['relatedJobId']),
      relatedApplicationId: _readString(data['relatedApplicationId']),
      relatedChatId: _readString(data['relatedChatId']),
      senderId: _readString(data['senderId']),
      isRead: data['isRead'] == true,
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : null,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'relatedJobId': relatedJobId,
      'relatedApplicationId': relatedApplicationId,
      'relatedChatId': relatedChatId,
      'senderId': senderId,
      'isRead': isRead,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

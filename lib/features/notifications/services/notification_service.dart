import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? relatedJobId,
    String? relatedApplicationId,
    String? relatedChatId,
    String? senderId,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedType = type.trim();
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();

    if (trimmedUserId.isEmpty) {
      debugPrint(
        'NotificationService.createNotification skipped: empty userId '
        'type="$trimmedType" title="$trimmedTitle"',
      );
      return;
    }
    if (trimmedType.isEmpty) {
      debugPrint(
        'NotificationService.createNotification skipped: empty type '
        'userId=$trimmedUserId title="$trimmedTitle"',
      );
      return;
    }
    if (trimmedTitle.isEmpty) {
      debugPrint(
        'NotificationService.createNotification skipped: empty title '
        'userId=$trimmedUserId type="$trimmedType"',
      );
      return;
    }
    if (trimmedBody.isEmpty) {
      debugPrint(
        'NotificationService.createNotification skipped: empty body '
        'userId=$trimmedUserId type="$trimmedType" title="$trimmedTitle"',
      );
      return;
    }

    final notificationRef = await _firestore.collection('notifications').add({
      'userId': trimmedUserId,
      'type': trimmedType,
      'title': trimmedTitle,
      'body': trimmedBody,
      'relatedJobId': _trimOrNull(relatedJobId),
      'relatedApplicationId': _trimOrNull(relatedApplicationId),
      'relatedChatId': _trimOrNull(relatedChatId),
      'senderId': _trimOrNull(senderId),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
      'NotificationService.createNotification created '
      'notificationId=${notificationRef.id} userId=$trimmedUserId '
      'type="$trimmedType"',
    );
  }

  Stream<int> watchUnreadCountByTypes({
    required String userId,
    required List<String> types,
  }) {
    final trimmedUserId = userId.trim();
    final trimmedTypes = types
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .take(10)
        .toList();

    if (trimmedUserId.isEmpty || trimmedTypes.isEmpty) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: trimmedUserId)
        .where('isRead', isEqualTo: false)
        .where('type', whereIn: trimmedTypes)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<AppNotification?> watchLatestUnreadNotification(String userId) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: trimmedUserId)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          return AppNotification.fromFirestore(snapshot.docs.first);
        });
  }

  Stream<AppNotification?> watchLatestUnreadNotificationByTypes({
    required String userId,
    required List<String> types,
  }) {
    final trimmedUserId = userId.trim();
    final trimmedTypes = types
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .take(10)
        .toList();

    if (trimmedUserId.isEmpty || trimmedTypes.isEmpty) {
      return Stream.value(null);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: trimmedUserId)
        .where('isRead', isEqualTo: false)
        .where('type', whereIn: trimmedTypes)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          return AppNotification.fromFirestore(snapshot.docs.first);
        });
  }

  Future<void> markNotificationsAsReadByTypes({
    required String userId,
    required List<String> types,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedTypes = types
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .take(10)
        .toList();

    if (trimmedUserId.isEmpty || trimmedTypes.isEmpty) {
      return;
    }

    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: trimmedUserId)
        .where('isRead', isEqualTo: false)
        .where('type', whereIn: trimmedTypes)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  String? get currentUserId => _auth.currentUser?.uid;
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

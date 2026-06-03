import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _isInitializing = false;
  String? _initializedUserId;

  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'PushNotificationService: initialization skipped because user is null',
      );
      return;
    }

    if (_isInitializing) {
      debugPrint('PushNotificationService: initialization already in progress');
      return;
    }

    if (_initializedUserId == user.uid && _tokenRefreshSubscription != null) {
      debugPrint(
        'PushNotificationService: initialization skipped because it already ran '
        'for userId=${user.uid}',
      );
      return;
    }

    _isInitializing = true;

    try {
      final settings = await _messaging.requestPermission();
      debugPrint(
        'PushNotificationService: notification permission status '
        '${settings.authorizationStatus.name}',
      );

      final token = await _messaging.getToken();
      await _saveTokenForUser(userId: user.uid, token: token);

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
        (token) async {
          debugPrint('PushNotificationService: token refresh detected');
          final refreshedUser = _auth.currentUser;
          if (refreshedUser == null) {
            debugPrint(
              'PushNotificationService: token refresh skipped because user is null',
            );
            return;
          }

          await _saveTokenForUser(userId: refreshedUser.uid, token: token);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            'PushNotificationService: token refresh listener error: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      _initializedUserId = user.uid;
    } catch (error, stackTrace) {
      debugPrint('PushNotificationService: initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _saveTokenForUser({
    required String userId,
    required String? token,
  }) async {
    if (token == null || token.trim().isEmpty) {
      debugPrint(
        'PushNotificationService: token save skipped because token is null',
      );
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint(
        'PushNotificationService: token saved successfully userId=$userId',
      );
    } catch (error, stackTrace) {
      debugPrint('PushNotificationService: token save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

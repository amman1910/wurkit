import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../employee_home/screens/employee_main_navigation_page.dart';
import '../../employer_home/screens/employer_main_navigation_page.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  bool _isInitializing = false;
  bool _tapNavigationInitialized = false;
  String? _initializedUserId;
  final Set<String> _handledTapMessageKeys = {};

  Future<void> initialize() async {
    _ensureTapNavigationHandlers();

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

  void _ensureTapNavigationHandlers() {
    if (_tapNavigationInitialized) {
      return;
    }

    _tapNavigationInitialized = true;

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message == null) {
            return;
          }
          debugPrint(
            'PushNotificationService: initial push notification tapped',
          );
          _handlePushNotificationNavigation(message);
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            'PushNotificationService: getInitialMessage failed: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        });

    _messageOpenedSubscription?.cancel();
    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        debugPrint('PushNotificationService: push notification tapped');
        _handlePushNotificationNavigation(message);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'PushNotificationService: onMessageOpenedApp listener error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _handlePushNotificationNavigation(RemoteMessage message) async {
    final messageKey = _messageKey(message);
    if (_handledTapMessageKeys.contains(messageKey)) {
      debugPrint(
        'PushNotificationService: duplicate push tap skipped key=$messageKey',
      );
      return;
    }
    _handledTapMessageKeys.add(messageKey);

    final type = (message.data['type'] ?? '').toString().trim();
    debugPrint('PushNotificationService: notification type detected "$type"');

    final targetTab = _targetTabForNotificationType(type);
    if (targetTab == null) {
      debugPrint('PushNotificationService: unknown notification type "$type"');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint(
        'PushNotificationService: skipped navigation because user is not logged in',
      );
      return;
    }

    String? role;
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      role = (userDoc.data()?['role'] as String?)?.trim();
    } catch (error, stackTrace) {
      debugPrint('PushNotificationService: failed to detect user role: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    debugPrint(
      'PushNotificationService: user role detected "$role" '
      'targetTab=$targetTab',
    );

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint(
        'PushNotificationService: skipped navigation because navigator is unavailable',
      );
      return;
    }

    Widget? page;
    if (role == 'employee') {
      page = EmployeeMainNavigationPage(initialIndex: targetTab);
    } else if (role == 'employer') {
      page = EmployerMainNavigationPage(initialIndex: targetTab);
    }

    if (page == null) {
      debugPrint(
        'PushNotificationService: skipped navigation because role is unknown',
      );
      return;
    }

    debugPrint(
      'PushNotificationService: navigating from push tap '
      'type="$type" targetTab=$targetTab role=$role',
    );

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => page!),
      (route) => false,
    );
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

int? _targetTabForNotificationType(String type) {
  if (type == 'chat_message') {
    return 3;
  }
  if (type == 'match_created' || type.startsWith('application_')) {
    return 2;
  }
  return null;
}

String _messageKey(RemoteMessage message) {
  final notificationId = message.data['notificationId'];
  if (notificationId is String && notificationId.trim().isNotEmpty) {
    return notificationId.trim();
  }
  if (message.messageId != null && message.messageId!.trim().isNotEmpty) {
    return message.messageId!.trim();
  }
  return '${message.sentTime?.millisecondsSinceEpoch ?? 0}_${message.data}';
}

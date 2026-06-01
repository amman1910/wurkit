import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employer_applications_page.dart';
import '../../employer_profile/screens/employer_profile_page.dart';
import '../../jobs/screens/employer_jobs_page.dart';
import '../../messages/screens/chat_detail_page.dart';
import '../../messages/screens/messages_page.dart';
import '../../messages/services/chat_service.dart';
import '../../notifications/models/app_notification.dart';
import '../../notifications/services/notification_service.dart';
import '../../notifications/widgets/in_app_notification_banner.dart';
import 'employer_dashboard_page.dart';

class EmployerMainNavigationPage extends StatefulWidget {
  const EmployerMainNavigationPage({super.key});

  @override
  State<EmployerMainNavigationPage> createState() =>
      _EmployerMainNavigationPageState();
}

class _EmployerMainNavigationPageState
    extends State<EmployerMainNavigationPage> {
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<AppNotification?>? _notificationSubscription;
  StreamSubscription<MessageBannerNotification?>? _messageSubscription;
  Timer? _bannerTimer;
  AppNotification? _activeNotification;
  MessageBannerNotification? _activeMessageNotification;
  bool _notificationListenerInitialized = false;
  bool _messageListenerInitialized = false;
  String? _lastSeenNotificationId;
  String? _lastShownNotificationId;
  String? _lastSeenMessageKey;
  String? _lastShownMessageKey;
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    EmployerDashboardPage(),
    EmployerJobsPage(),
    EmployerApplicationsPage(markNotificationsReadOnOpen: false),
    MessagesPage(role: 'employer'),
    EmployerProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _startNotificationListener();
    _startMessageListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _messageSubscription?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint(
        'EmployerMainNavigationPage: notification listener not started, '
        'no current user',
      );
      return;
    }

    debugPrint(
      'EmployerMainNavigationPage: notification listener started '
      'userId=${user.uid} types=application_created',
    );

    _notificationSubscription?.cancel();
    _notificationListenerInitialized = false;
    _lastSeenNotificationId = null;
    _lastShownNotificationId = null;
    _notificationSubscription = _notificationService
        .watchLatestUnreadNotificationByTypes(
          userId: user.uid,
          types: const ['application_created'],
        )
        .listen(
          _handleNotificationSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'EmployerMainNavigationPage: notification listener error: '
              '$error',
            );
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  void _startMessageListener() {
    debugPrint('EmployerMainNavigationPage: message listener started');

    _messageSubscription?.cancel();
    _messageListenerInitialized = false;
    _lastSeenMessageKey = null;
    _lastShownMessageKey = null;
    _messageSubscription = _chatService
        .watchLatestUnreadIncomingMessage()
        .listen(
          _handleMessageSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'EmployerMainNavigationPage: message stream error: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  void _handleMessageSnapshot(MessageBannerNotification? notification) {
    debugPrint(
      'EmployerMainNavigationPage: message snapshot received '
      'hasMessage=${notification != null}',
    );

    if (!mounted) {
      return;
    }

    if (notification == null) {
      _messageListenerInitialized = true;
      return;
    }

    final eventKey = notification.eventKey;
    debugPrint(
      'EmployerMainNavigationPage: message received chatId=${notification.chatId} '
      'senderId=${notification.senderId} senderName="${notification.senderName}" '
      'eventKey=$eventKey lastMessageAt=${notification.lastMessageAt?.toDate()}',
    );

    if (!_messageListenerInitialized) {
      _lastSeenMessageKey = eventKey;
      _messageListenerInitialized = true;
      debugPrint(
        'EmployerMainNavigationPage: first message snapshot skipped '
        'eventKey=$eventKey',
      );
      return;
    }

    if (eventKey == _lastSeenMessageKey || eventKey == _lastShownMessageKey) {
      debugPrint(
        'EmployerMainNavigationPage: duplicate message skipped '
        'eventKey=$eventKey',
      );
      return;
    }

    debugPrint(
      'EmployerMainNavigationPage: new message detected eventKey=$eventKey',
    );
    _lastSeenMessageKey = eventKey;
    _lastShownMessageKey = eventKey;
    _bannerTimer?.cancel();
    setState(() {
      _activeMessageNotification = notification;
      _activeNotification = null;
    });
    debugPrint(
      'EmployerMainNavigationPage: message banner state set eventKey=$eventKey',
    );
    _bannerTimer = Timer(const Duration(seconds: 7), _dismissBanner);
  }

  void _handleNotificationSnapshot(AppNotification? notification) {
    debugPrint(
      'EmployerMainNavigationPage: notification snapshot received '
      'hasNotification=${notification != null}',
    );

    if (!mounted) {
      return;
    }

    if (notification == null) {
      _notificationListenerInitialized = true;
      return;
    }

    debugPrint(
      'EmployerMainNavigationPage: notification received '
      'id=${notification.id} type=${notification.type} '
      'title="${notification.title}" userId=${notification.userId} '
      'createdAt=${notification.createdAt?.toDate()}',
    );

    if (!_notificationListenerInitialized) {
      _lastSeenNotificationId = notification.id;
      _notificationListenerInitialized = true;
      debugPrint(
        'EmployerMainNavigationPage: first notification snapshot skipped '
        'id=${notification.id}',
      );
      return;
    }

    if (notification.id == _lastSeenNotificationId ||
        notification.id == _lastShownNotificationId) {
      debugPrint(
        'EmployerMainNavigationPage: notification skipped because it was '
        'already seen/shown id=${notification.id}',
      );
      return;
    }

    debugPrint(
      'EmployerMainNavigationPage: new notification detected '
      'id=${notification.id}',
    );
    _lastSeenNotificationId = notification.id;
    _lastShownNotificationId = notification.id;
    _bannerTimer?.cancel();
    setState(() {
      _activeNotification = notification;
      _activeMessageNotification = null;
    });
    debugPrint(
      'EmployerMainNavigationPage: banner state set id=${notification.id}',
    );
    _bannerTimer = Timer(const Duration(seconds: 7), _dismissBanner);
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    if (_activeMessageNotification != null) {
      debugPrint(
        'EmployerMainNavigationPage: message banner dismissed '
        'eventKey=${_activeMessageNotification!.eventKey}',
      );
    }
    if (_activeNotification != null) {
      debugPrint(
        'EmployerMainNavigationPage: banner dismissed '
        'id=${_activeNotification!.id}',
      );
    }
    if (mounted) {
      setState(() {
        _activeNotification = null;
        _activeMessageNotification = null;
      });
    } else {
      _activeNotification = null;
      _activeMessageNotification = null;
    }
  }

  void _openNotification(AppNotification notification) {
    _dismissBanner();
    if (notification.type == 'application_created') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const EmployerApplicationsPage(),
        ),
      );
    }
  }

  String _applicationBannerTitle(AppNotification notification) {
    final title = notification.title.trim();
    if (title.isEmpty || title == 'New application') {
      return 'New application received';
    }
    return title;
  }

  void _openMessageNotification(MessageBannerNotification notification) {
    _dismissBanner();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailPage(chatId: notification.chatId),
      ),
    );
  }

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
    if (index == 2) {
      _markApplicationNotificationsRead();
    }
  }

  Future<void> _markApplicationNotificationsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await _notificationService.markNotificationsAsReadByTypes(
      userId: user.uid,
      types: const ['application_created'],
    );
  }

  Stream<int> _watchApplicationNotificationCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    return _notificationService.watchUnreadCountByTypes(
      userId: user.uid,
      types: const ['application_created'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.navyBg,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.coralAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: _watchApplicationNotificationCount(),
              builder: (context, snapshot) {
                return _ApplicationsNavIcon(
                  unreadCount: snapshot.data ?? 0,
                  isSelected: _selectedIndex == 2,
                );
              },
            ),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: _chatService.watchTotalUnreadCount(),
              builder: (context, snapshot) {
                return _MessageNavIcon(
                  unreadCount: snapshot.data ?? 0,
                  isSelected: _selectedIndex == 3,
                );
              },
            ),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );

    return Stack(
      children: [
        scaffold,
        if (_activeMessageNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: InAppNotificationBanner(
              title: 'New message in your inbox',
              body:
                  '${_activeMessageNotification!.senderName} sent you a message',
              avatarImageUrl: _activeMessageNotification!.senderImageUrl,
              fallbackInitial: _activeMessageNotification!.senderName,
              fallbackIcon: Icons.person_rounded,
              onTap: () =>
                  _openMessageNotification(_activeMessageNotification!),
              onDismiss: _dismissBanner,
            ),
          )
        else if (_activeNotification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: InAppNotificationBanner(
              title: _applicationBannerTitle(_activeNotification!),
              body: _activeNotification!.body,
              avatarImageUrl: _activeNotification!.senderImageUrl,
              fallbackInitial: _activeNotification!.senderName,
              fallbackIcon: Icons.person_rounded,
              showWatermark: false,
              onTap: () => _openNotification(_activeNotification!),
              onDismiss: _dismissBanner,
            ),
          ),
      ],
    );
  }
}

class _ApplicationsNavIcon extends StatelessWidget {
  const _ApplicationsNavIcon({
    required this.unreadCount,
    required this.isSelected,
  });

  final int unreadCount;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return SizedBox(
      height: 30,
      width: 36,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.groups_rounded,
            color: isSelected ? AppColors.coralAccent : Colors.white54,
          ),
          if (hasUnread)
            Positioned(
              top: -3,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.coralAccent,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: AppColors.navyBg,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageNavIcon extends StatelessWidget {
  const _MessageNavIcon({required this.unreadCount, required this.isSelected});

  final int unreadCount;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return SizedBox(
      height: 28,
      width: 34,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: hasUnread ? 28 : 24,
            width: hasUnread ? 34 : 24,
            decoration: BoxDecoration(
              color: hasUnread
                  ? AppColors.coralAccent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              hasUnread
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              color: isSelected ? AppColors.coralAccent : Colors.white54,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            bottom: hasUnread ? -1 : 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: hasUnread ? 4 : 0,
              width: hasUnread ? 4 : 0,
              decoration: const BoxDecoration(
                color: AppColors.coralAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

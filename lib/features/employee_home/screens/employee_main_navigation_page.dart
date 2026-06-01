import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employee_applications_page.dart';
import '../../applications/services/employee_application_service.dart';
import '../../employee_profile/screens/employee_profile_page.dart';
import '../../jobs/screens/employee_jobs_page.dart';
import '../../matches/services/match_service.dart';
import '../../matches/widgets/match_celebration_dialog.dart';
import '../../messages/screens/chat_detail_page.dart';
import '../../messages/screens/messages_page.dart';
import '../../messages/services/chat_service.dart';
import '../../notifications/widgets/in_app_notification_banner.dart';
import 'employee_home_page.dart';

class EmployeeMainNavigationPage extends StatefulWidget {
  const EmployeeMainNavigationPage({super.key});

  @override
  State<EmployeeMainNavigationPage> createState() =>
      _EmployeeMainNavigationPageState();
}

class _EmployeeMainNavigationPageState
    extends State<EmployeeMainNavigationPage> {
  final ChatService _chatService = ChatService();
  final MatchService _matchService = MatchService();
  final EmployeeApplicationService _applicationService =
      EmployeeApplicationService();
  final Set<String> _handledMatchIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _matchSubscription;
  StreamSubscription<MessageBannerNotification?>? _messageSubscription;
  Timer? _messageBannerTimer;
  MessageBannerNotification? _activeMessageNotification;
  bool _messageListenerInitialized = false;
  String? _lastSeenMessageKey;
  String? _lastShownMessageKey;
  int _selectedIndex = 0;
  bool _isShowingMatchDialog = false;

  static const List<Widget> _pages = <Widget>[
    EmployeeHomePage(),
    EmployeeJobsPage(),
    EmployeeApplicationsPage(),
    MessagesPage(role: 'employee'),
    EmployeeProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _matchSubscription = _matchService.watchUnseenEmployeeMatches().listen(
      _handleUnseenMatches,
      onError: (_) {},
    );
    _startMessageListener();
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _messageSubscription?.cancel();
    _messageBannerTimer?.cancel();
    super.dispose();
  }

  void _startMessageListener() {
    debugPrint('EmployeeMainNavigationPage: message listener started');

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
              'EmployeeMainNavigationPage: message stream error: $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  void _handleMessageSnapshot(MessageBannerNotification? notification) {
    debugPrint(
      'EmployeeMainNavigationPage: message snapshot received '
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
      'EmployeeMainNavigationPage: message received chatId=${notification.chatId} '
      'senderId=${notification.senderId} senderName="${notification.senderName}" '
      'eventKey=$eventKey lastMessageAt=${notification.lastMessageAt?.toDate()}',
    );

    if (!_messageListenerInitialized) {
      _lastSeenMessageKey = eventKey;
      _messageListenerInitialized = true;
      debugPrint(
        'EmployeeMainNavigationPage: first message snapshot skipped '
        'eventKey=$eventKey',
      );
      return;
    }

    if (eventKey == _lastSeenMessageKey || eventKey == _lastShownMessageKey) {
      debugPrint(
        'EmployeeMainNavigationPage: duplicate message skipped '
        'eventKey=$eventKey',
      );
      return;
    }

    debugPrint(
      'EmployeeMainNavigationPage: new message detected eventKey=$eventKey',
    );
    _lastSeenMessageKey = eventKey;
    _lastShownMessageKey = eventKey;
    _messageBannerTimer?.cancel();
    setState(() => _activeMessageNotification = notification);
    debugPrint(
      'EmployeeMainNavigationPage: message banner state set eventKey=$eventKey',
    );
    _messageBannerTimer = Timer(
      const Duration(seconds: 4),
      _dismissMessageBanner,
    );
  }

  void _dismissMessageBanner() {
    _messageBannerTimer?.cancel();
    _messageBannerTimer = null;
    if (_activeMessageNotification != null) {
      debugPrint(
        'EmployeeMainNavigationPage: message banner dismissed '
        'eventKey=${_activeMessageNotification!.eventKey}',
      );
    }
    if (mounted) {
      setState(() => _activeMessageNotification = null);
    } else {
      _activeMessageNotification = null;
    }
  }

  void _openMessageNotification(MessageBannerNotification notification) {
    _dismissMessageBanner();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailPage(chatId: notification.chatId),
      ),
    );
  }

  Future<void> _handleUnseenMatches(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (_isShowingMatchDialog || !mounted) {
      return;
    }

    final docs = [...snapshot.docs];
    docs.sort((a, b) {
      return _readTimestampMillis(
        b.data()['createdAt'],
      ).compareTo(_readTimestampMillis(a.data()['createdAt']));
    });

    QueryDocumentSnapshot<Map<String, dynamic>>? nextMatch;
    for (final doc in docs) {
      if (!_handledMatchIds.contains(doc.id)) {
        nextMatch = doc;
        break;
      }
    }

    if (nextMatch == null) {
      return;
    }

    _handledMatchIds.add(nextMatch.id);
    _isShowingMatchDialog = true;

    try {
      final data = await _matchService.getMatchCelebrationData(nextMatch.id);
      if (!mounted) {
        return;
      }

      if (data == null) {
        await _matchService.markMatchSeen(nextMatch.id);
        return;
      }

      await _showMatchCelebration(data);
    } catch (_) {
      if (mounted) {
        _handledMatchIds.remove(nextMatch.id);
      }
    } finally {
      if (mounted) {
        _isShowingMatchDialog = false;
      }
    }
  }

  Future<void> _showMatchCelebration(Map<String, dynamic> data) async {
    final matchId = data['matchId'] as String?;
    final chatId = data['chatId'] as String?;
    if (matchId == null || matchId.trim().isEmpty) {
      return;
    }

    var actionHandled = false;

    Future<void> closeDialog(NavigatorState dialogNavigator) async {
      if (dialogNavigator.canPop()) {
        dialogNavigator.pop();
      }
    }

    Future<void> markAndClose(
      BuildContext dialogContext, {
      required bool openChat,
    }) async {
      if (actionHandled) {
        return;
      }
      actionHandled = true;
      final dialogNavigator = Navigator.of(dialogContext, rootNavigator: true);

      try {
        await _matchService.markMatchSeen(matchId);
      } catch (_) {}

      if (!mounted) {
        return;
      }

      await closeDialog(dialogNavigator);

      if (!mounted || !openChat) {
        return;
      }

      if (chatId == null || chatId.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat coming soon')));
        return;
      }

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId)));
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Match celebration',
      barrierColor: Colors.black.withValues(alpha: 0.66),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return MatchCelebrationDialog(
          businessName: _readString(data['businessName'], 'Business'),
          businessLogoUrl: _readNullableString(data['businessLogoUrl']),
          jobTitle: _readString(data['jobTitle'], 'Job'),
          date: _readNullableString(data['date']),
          shiftStart: _readNullableString(data['shiftStart']),
          shiftEnd: _readNullableString(data['shiftEnd']),
          location:
              _readNullableString(data['city']) ??
              _readNullableString(data['location']) ??
              _readNullableString(data['businessAddress']),
          onOpenChat: () => markAndClose(dialogContext, openChat: true),
          onMaybeLater: () => markAndClose(dialogContext, openChat: false),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  int _readTimestampMillis(Object? value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    return 0;
  }

  String _readString(Object? value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _readNullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.navyBg,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.coralAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.work_outline_rounded),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: _applicationService.watchApprovedApplicationsCount(),
              builder: (context, snapshot) {
                return _ApplicationsNavIcon(
                  matchCount: snapshot.data ?? 0,
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
            icon: Icon(Icons.person_outline_rounded),
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
              fallbackIcon: Icons.storefront_rounded,
              onTap: () =>
                  _openMessageNotification(_activeMessageNotification!),
              onDismiss: _dismissMessageBanner,
            ),
          ),
      ],
    );
  }
}

class _ApplicationsNavIcon extends StatelessWidget {
  const _ApplicationsNavIcon({
    required this.matchCount,
    required this.isSelected,
  });

  final int matchCount;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final hasMatches = matchCount > 0;

    return SizedBox(
      height: 30,
      width: 36,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            hasMatches
                ? Icons.assignment_turned_in_rounded
                : Icons.assignment_outlined,
            color: isSelected ? AppColors.coralAccent : Colors.white54,
          ),
          if (hasMatches)
            Positioned(
              top: -3,
              right: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF6FD37A),
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  matchCount > 9 ? '9+' : matchCount.toString(),
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../applications/screens/employer_applications_page.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'in_app_notification_banner.dart';

class InAppNotificationListener extends StatefulWidget {
  const InAppNotificationListener({
    super.key,
    required this.child,
    required this.userId,
    this.types,
    this.notificationService,
  });

  final Widget child;
  final String userId;
  final List<String>? types;
  final NotificationService? notificationService;

  @override
  State<InAppNotificationListener> createState() =>
      _InAppNotificationListenerState();
}

class _InAppNotificationListenerState extends State<InAppNotificationListener> {
  late final NotificationService _notificationService =
      widget.notificationService ?? NotificationService();

  DateTime _listenerStartedAt = DateTime.now();
  StreamSubscription<AppNotification?>? _subscription;
  OverlayEntry? _overlayEntry;
  Timer? _dismissTimer;
  bool _hasInitialized = false;
  String? _lastSeenNotificationId;
  String? _lastShownNotificationId;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void didUpdateWidget(covariant InAppNotificationListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        !_sameTypes(oldWidget.types, widget.types)) {
      _startListening();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _dismissTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _startListening() {
    _subscription?.cancel();
    _subscription = null;
    _dismissBanner();
    _hasInitialized = false;
    _lastSeenNotificationId = null;
    _lastShownNotificationId = null;
    _listenerStartedAt = DateTime.now();

    final userId = widget.userId.trim();
    final types = _normalizedTypes(widget.types);
    debugPrint(
      'InAppNotificationListener: starting listener userId=$userId '
      'types=${types.join(',')} startedAt=$_listenerStartedAt',
    );

    if (userId.isEmpty) {
      debugPrint('InAppNotificationListener: empty userId, listener disabled');
      _hasInitialized = true;
      return;
    }

    final stream = types.isEmpty
        ? _notificationService.watchLatestUnreadNotification(userId)
        : _notificationService.watchLatestUnreadNotificationByTypes(
            userId: userId,
            types: types,
          );

    _subscription = stream.listen(
      _handleNotification,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('InAppNotificationListener: stream error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void _handleNotification(AppNotification? notification) {
    debugPrint(
      'InAppNotificationListener: notification event received '
      'hasNotification=${notification != null}',
    );

    if (!mounted) {
      debugPrint('InAppNotificationListener: event ignored, widget unmounted');
      return;
    }

    if (notification == null) {
      debugPrint('InAppNotificationListener: no unread notification in event');
      _hasInitialized = true;
      return;
    }

    debugPrint(
      'InAppNotificationListener: received notification '
      'id=${notification.id} type=${notification.type} '
      'title="${notification.title}" userId=${notification.userId} '
      'createdAt=${notification.createdAt?.toDate()}',
    );
    final createdAt = notification.createdAt?.toDate();
    if (createdAt != null && !createdAt.isAfter(_listenerStartedAt)) {
      debugPrint(
        'InAppNotificationListener: notification timestamp is older than '
        'listener start, but timestamp guard is relaxed and it will not be '
        'skipped by time id=${notification.id}',
      );
    }

    if (!_hasInitialized) {
      _lastSeenNotificationId = notification.id;
      _hasInitialized = true;
      debugPrint(
        'InAppNotificationListener: first snapshot skipped as startup '
        'initialization id=${notification.id}',
      );
      return;
    }

    if (notification.id == _lastSeenNotificationId ||
        notification.id == _lastShownNotificationId) {
      debugPrint(
        'InAppNotificationListener: notification skipped because it was '
        'already seen/shown id=${notification.id} '
        'lastSeen=$_lastSeenNotificationId lastShown=$_lastShownNotificationId',
      );
      return;
    }

    _lastSeenNotificationId = notification.id;
    _lastShownNotificationId = notification.id;
    debugPrint(
      'InAppNotificationListener: banner about to be shown '
      'id=${notification.id}',
    );
    _showBanner(notification);
  }

  void _showBanner(AppNotification notification) {
    _dismissBanner();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      debugPrint(
        'InAppNotificationListener: Overlay unavailable, showing SnackBar '
        'fallback id=${notification.id}',
      );
      _showSnackBarFallback(notification);
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -14 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: InAppNotificationBanner(
              title: notification.title,
              body: notification.body,
              icon: _iconFor(notification.type),
              onTap: () => _handleBannerTap(notification),
              onDismiss: _dismissBanner,
            ),
          ),
        );
      },
    );

    try {
      overlay.insert(_overlayEntry!);
      debugPrint(
        'InAppNotificationListener: OverlayEntry inserted '
        'id=${notification.id}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'InAppNotificationListener: OverlayEntry insert failed, showing '
        'SnackBar fallback id=${notification.id}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      _overlayEntry = null;
      _showSnackBarFallback(notification);
      return;
    }
    _dismissTimer = Timer(const Duration(seconds: 4), _dismissBanner);
  }

  void _handleBannerTap(AppNotification notification) {
    _dismissBanner();
    if (notification.type == 'application_created') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const EmployerApplicationsPage(),
        ),
      );
    }
  }

  void _dismissBanner() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_overlayEntry != null) {
      debugPrint('InAppNotificationListener: OverlayEntry removed');
      _overlayEntry?.remove();
    }
    _overlayEntry = null;
  }

  void _showSnackBarFallback(AppNotification notification) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint(
        'InAppNotificationListener: SnackBar fallback unavailable '
        'id=${notification.id}',
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(_iconFor(notification.type), color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    debugPrint(
      'InAppNotificationListener: SnackBar fallback shown '
      'id=${notification.id}',
    );
  }

  IconData _iconFor(String type) {
    if (type == 'application_created') {
      return Icons.group_add_rounded;
    }
    return Icons.notifications_active_outlined;
  }
}

List<String> _normalizedTypes(List<String>? types) {
  return (types ?? const <String>[])
      .map((type) => type.trim())
      .where((type) => type.isNotEmpty)
      .take(10)
      .toList();
}

bool _sameTypes(List<String>? a, List<String>? b) {
  final first = _normalizedTypes(a);
  final second = _normalizedTypes(b);
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}

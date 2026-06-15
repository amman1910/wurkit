import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../jobs/screens/job_details_page.dart';
import '../../messages/screens/chat_detail_page.dart';
import '../../messages/services/chat_service.dart';
import '../models/employee_application_item.dart';
import '../services/employee_application_service.dart';
import '../widgets/application_status_badge.dart';
import '../widgets/employee_application_card.dart';
import '../../reviews/screens/add_review_screen.dart';
import '../../reviews/services/review_service.dart';

const Color _softWhite = Color(0xFFF3F4F6);
const Color _softText = Color(0xFFCBD5E1);
const Color _deepSurface = Color(0xFF101D35);

enum _ApplicationFilter { all, pending, approved, rejected, cancelled }

enum _ApplicationSort { matchesFirst, newestFirst, oldestFirst }

class EmployeeApplicationsPage extends StatefulWidget {
  const EmployeeApplicationsPage({super.key});

  @override
  State<EmployeeApplicationsPage> createState() =>
      _EmployeeApplicationsPageState();
}

class _EmployeeApplicationsPageState extends State<EmployeeApplicationsPage> {
  final EmployeeApplicationService _service = EmployeeApplicationService();
  final ChatService _chatService = ChatService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyApplicationIds = {};

  _ApplicationFilter _filter = _ApplicationFilter.all;
  _ApplicationSort _sort = _ApplicationSort.matchesFirst;
  String _searchText = '';
  _FeedbackMessage? _feedback;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
    unawaited(_service.markApprovedApplicationsSeen());
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeApplicationItem> _visibleItems(
    List<EmployeeApplicationItem> items,
  ) {
    final filtered = items.where((item) {
      final matchesFilter = switch (_filter) {
        _ApplicationFilter.all => true,
        _ApplicationFilter.pending => item.isPending,
        _ApplicationFilter.approved => item.isApproved,
        _ApplicationFilter.rejected => item.isRejected,
        _ApplicationFilter.cancelled => item.isCancelled,
      };
      if (!matchesFilter) {
        return false;
      }
      if (_searchText.isEmpty) {
        return true;
      }
      return item.searchText.contains(_searchText);
    }).toList();

    filtered.sort(_compareItems);
    return filtered;
  }

  int _compareItems(
    EmployeeApplicationItem left,
    EmployeeApplicationItem right,
  ) {
    return switch (_sort) {
      _ApplicationSort.matchesFirst => EmployeeApplicationItem.compareDefault(
        left,
        right,
      ),
      _ApplicationSort.newestFirst =>
        (right.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          left.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
      _ApplicationSort.oldestFirst =>
        (left.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          right.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
    };
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<_ApplicationSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SortOptionTile(
                  label: 'Matches first',
                  icon: Icons.celebration_rounded,
                  selected: _sort == _ApplicationSort.matchesFirst,
                  onTap: () =>
                      Navigator.pop(context, _ApplicationSort.matchesFirst),
                ),
                _SortOptionTile(
                  label: 'Newest first',
                  icon: Icons.south_rounded,
                  selected: _sort == _ApplicationSort.newestFirst,
                  onTap: () =>
                      Navigator.pop(context, _ApplicationSort.newestFirst),
                ),
                _SortOptionTile(
                  label: 'Oldest first',
                  icon: Icons.north_rounded,
                  selected: _sort == _ApplicationSort.oldestFirst,
                  onTap: () =>
                      Navigator.pop(context, _ApplicationSort.oldestFirst),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _sort = selected);
    }
  }

  Future<void> _cancelApplication(EmployeeApplicationItem item) async {
    final confirmed = await _confirmCancel();
    if (confirmed != true) {
      return;
    }

    setState(() => _busyApplicationIds.add(item.applicationId));
    try {
      await _service.cancelApplication(item.applicationId);
      if (!mounted) {
        return;
      }
      _showFeedback(
        icon: Icons.check_circle_outline_rounded,
        text: 'Application cancelled',
        color: const Color(0xFFFF7A68),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busyApplicationIds.remove(item.applicationId));
      }
    }
  }

  Future<void> _resendApplication(EmployeeApplicationItem item) async {
    if (!item.isCancelled || !item.jobExists) {
      return;
    }

    setState(() => _busyApplicationIds.add(item.applicationId));
    try {
      await _service.resendCancelledApplication(item.applicationId);
      if (!mounted) {
        return;
      }
      _showFeedback(
        icon: Icons.send_rounded,
        text: 'Application sent again',
        color: AppColors.coralAccent,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _busyApplicationIds.remove(item.applicationId));
      }
    }
  }

  Future<bool?> _confirmCancel() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cancel application?',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The employer will no longer see you as an active candidate for this job.',
                  style: AppTextStyles.body.copyWith(height: 1.35),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: AppButtonStyles.secondaryOutline(),
                        child: const Text('Keep application'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: AppButtonStyles.primary(
                          backgroundColor: const Color(0xFFFF7A68),
                          foregroundColor: AppColors.navyBg,
                        ),
                        child: const Text('Cancel application'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openJob(EmployeeApplicationItem item) {
    if (!item.jobExists || item.jobId.isEmpty) {
      _showSnackBar('This job is no longer available');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailsPage(jobId: item.jobId)),
    );
  }

  Future<void> _openChat(EmployeeApplicationItem item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Please sign in to open chat');
      return;
    }
    if (!item.isApproved) {
      return;
    }

    setState(() => _busyApplicationIds.add(item.applicationId));
    try {
      final chatId = await _chatService.getOrCreateChatForApprovedApplication(
        jobId: item.jobId,
        employeeId: currentUser.uid,
        employerId: item.employerId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId)));
    } catch (_) {
      if (mounted) {
        _showSnackBar('Chat will be available soon');
      }
    } finally {
      if (mounted) {
        setState(() => _busyApplicationIds.remove(item.applicationId));
      }
    }
  }

  bool _canReviewEmployer(EmployeeApplicationItem item) {
    return item.isApproved && item.jobExists;
  }

  Future<void> _openEmployerReview(EmployeeApplicationItem item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Please sign in again');
      return;
    }

    final reviewed = await _reviewService.hasUserReviewedJob(
      jobId: item.jobId,
      reviewerId: currentUser.uid,
      targetUserId: item.employerId,
    );
    if (!mounted || reviewed) {
      if (mounted && reviewed) {
        _showSnackBar('You already reviewed this employer for this job.');
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          jobId: item.jobId,
          jobTitle: item.jobTitle,
          targetUserId: item.employerId,
          targetUserName: item.businessName,
          targetRole: 'employer',
          reviewerRole: 'employee',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      _showSnackBar('Review submitted.');
    }
  }

  void _showFeedback({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = _FeedbackMessage(icon, text, color));
    _feedbackTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() => _feedback = null);
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const _AuthRequiredView();
    }

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<List<EmployeeApplicationItem>>(
              stream: _service.watchEmployeeApplications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingView();
                }
                if (snapshot.hasError) {
                  return _ErrorView(error: _friendlyError(snapshot.error!));
                }

                final items = snapshot.data ?? const [];
                final visible = _visibleItems(items);
                final stats = _ApplicationStats.fromItems(items);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const _Header(),
                          const SizedBox(height: 18),
                          _SearchField(controller: _searchController),
                          const SizedBox(height: 12),
                          _FilterChips(
                            value: _filter,
                            onChanged: (value) =>
                                setState(() => _filter = value),
                          ),
                          const SizedBox(height: 12),
                          _StatsRow(stats: stats),
                          const SizedBox(height: 14),
                          _ResultsHeader(
                            count: visible.length,
                            sort: _sort,
                            onSort: _showSortSheet,
                          ),
                        ]),
                      ),
                    ),
                    if (items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyView(),
                      )
                    else if (visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _FilteredEmptyView(filter: _filter),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                        sliver: SliverList.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return EmployeeApplicationCard(
                              item: item,
                              onViewJob: item.jobExists
                                  ? () => _openJob(item)
                                  : () => _openJob(item),
                              onCancel:
                                  item.isPending &&
                                      !_busyApplicationIds.contains(
                                        item.applicationId,
                                      )
                                  ? () => _cancelApplication(item)
                                  : null,
                              onMessage:
                                  item.isApproved &&
                                      !_busyApplicationIds.contains(
                                        item.applicationId,
                                      )
                                  ? () => _openChat(item)
                                  : null,
                              onResend:
                                  item.isCancelled &&
                                      item.jobExists &&
                                      !_busyApplicationIds.contains(
                                        item.applicationId,
                                      )
                                  ? () => _resendApplication(item)
                                  : null,
                              onReview:
                                  _canReviewEmployer(item)
                                      ? () => _openEmployerReview(item)
                                      : null,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: IgnorePointer(child: _FeedbackOverlay(message: _feedback)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Applications',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Track your job applications and their status',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        style: AppTextStyles.input,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search by job title or business',
          hintStyle: AppTextStyles.hint,
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
          filled: true,
          fillColor: AppColors.surface.withValues(alpha: 0.58),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.coralAccent),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final _ApplicationFilter value;
  final ValueChanged<_ApplicationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = [
      (
        _ApplicationFilter.all,
        'All',
        AppColors.coralAccent,
        Icons.grid_view_rounded,
      ),
      (
        _ApplicationFilter.pending,
        'Pending',
        ApplicationStatusStyle.pending.color,
        Icons.schedule_rounded,
      ),
      (
        _ApplicationFilter.approved,
        'Matches',
        ApplicationStatusStyle.approved.color,
        Icons.check_circle_outline_rounded,
      ),
      (
        _ApplicationFilter.rejected,
        'Rejected',
        ApplicationStatusStyle.rejected.color,
        Icons.cancel_outlined,
      ),
      (
        _ApplicationFilter.cancelled,
        'Cancelled',
        ApplicationStatusStyle.cancelled.color,
        Icons.remove_circle_outline_rounded,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((filter) {
          final selected = value == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PremiumFilterChip(
              selected: selected,
              label: filter.$2,
              accent: filter.$3,
              icon: filter.$4,
              onTap: () => onChanged(filter.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PremiumFilterChip extends StatelessWidget {
  const _PremiumFilterChip({
    required this.selected,
    required this.label,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.coralAccent : _softText;
    final leadingColor = selected ? AppColors.coralAccent : accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.coralAccent.withValues(alpha: 0.1)
                : _deepSurface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? AppColors.coralAccent
                  : AppColors.border.withValues(alpha: 0.86),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.coralAccent.withValues(alpha: 0.13),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label == 'All')
                Icon(icon, color: leadingColor, size: 15)
              else
                _StatusAccentDot(color: leadingColor, size: 8),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final _ApplicationStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('All', stats.all, AppColors.coralAccent, Icons.business_center_outlined),
      (
        'Pending',
        stats.pending,
        ApplicationStatusStyle.pending.color,
        Icons.schedule_rounded,
      ),
      (
        'Matches',
        stats.approved,
        ApplicationStatusStyle.approved.color,
        Icons.check_circle_outline_rounded,
      ),
      (
        'Rejected',
        stats.rejected,
        ApplicationStatusStyle.rejected.color,
        Icons.cancel_outlined,
      ),
    ];
    return Row(
      children: tiles.map((tile) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: tile == tiles.last ? 0 : 8),
            child: _StatTile(
              label: tile.$1,
              value: tile.$2,
              accent: tile.$3,
              icon: tile.$4,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final int value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const Spacer(),
          Text(
            value.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _softWhite,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              height: 0.98,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (label != 'All') ...[
                _StatusAccentDot(color: accent, size: 6.5),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _softText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.sort,
    required this.onSort,
  });

  final int count;
  final _ApplicationSort sort;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'Application' : 'Applications'}',
            style: const TextStyle(
              color: _softText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: onSort,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.lightText,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sort: '),
              Text(
                _sortLabel(sort),
                style: const TextStyle(
                  color: AppColors.coralAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.coralAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sortLabel(_ApplicationSort sort) {
    return switch (sort) {
      _ApplicationSort.matchesFirst => 'Matches first',
      _ApplicationSort.newestFirst => 'Newest',
      _ApplicationSort.oldestFirst => 'Oldest',
    };
  }
}

class _StatusAccentDot extends StatelessWidget {
  const _StatusAccentDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _SortOptionTile extends StatelessWidget {
  const _SortOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: selected ? AppColors.coralAccent : AppColors.lightText,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.white : AppColors.lightText,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.coralAccent)
          : null,
    );
  }
}

class _FeedbackMessage {
  const _FeedbackMessage(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;
}

class _FeedbackOverlay extends StatelessWidget {
  const _FeedbackOverlay({required this.message});

  final _FeedbackMessage? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('empty-feedback'))
          : Center(
              key: ValueKey(message!.text),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: message!.color.withValues(alpha: 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: message!.color.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(message!.icon, color: message!.color, size: 21),
                    const SizedBox(width: 9),
                    Text(
                      message!.text,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ApplicationStats {
  const _ApplicationStats({
    required this.all,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int all;
  final int pending;
  final int approved;
  final int rejected;

  factory _ApplicationStats.fromItems(List<EmployeeApplicationItem> items) {
    return _ApplicationStats(
      all: items.length,
      pending: items.where((item) => item.isPending).length,
      approved: items.where((item) => item.isApproved).length,
      rejected: items.where((item) => item.isRejected).length,
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.coralAccent),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: _StateCard(
          icon: Icons.assignment_outlined,
          title: 'No applications yet',
          message: 'Jobs you apply to will appear here.',
        ),
      ),
    );
  }
}

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.filter});

  final _ApplicationFilter filter;

  @override
  Widget build(BuildContext context) {
    final label = switch (filter) {
      _ApplicationFilter.pending => 'pending applications',
      _ApplicationFilter.approved => 'approved applications yet',
      _ApplicationFilter.rejected => 'rejected applications',
      _ApplicationFilter.cancelled => 'cancelled applications',
      _ApplicationFilter.all => 'applications',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _StateCard(
          icon: Icons.manage_search_rounded,
          title: 'No $label',
          message: 'Try another filter or search term.',
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _StateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load applications',
          message: error,
        ),
      ),
    );
  }
}

class _AuthRequiredView extends StatelessWidget {
  const _AuthRequiredView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Center(
          child: Text(
            'Please sign in to view your applications.',
            style: AppTextStyles.body,
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

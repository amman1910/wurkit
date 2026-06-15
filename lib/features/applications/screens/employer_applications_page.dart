import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../messages/screens/chat_detail_page.dart';
import '../../reviews/screens/add_review_screen.dart';
import '../../reviews/services/review_service.dart';
import '../../notifications/services/notification_service.dart';
import '../services/application_service.dart';
import 'employer_application_details_page.dart';

enum _ApplicationFilter { all, pending, approved, rejected }

class EmployerApplicationsPage extends StatefulWidget {
  const EmployerApplicationsPage({
    super.key,
    this.jobId,
    this.jobTitle,
    this.markNotificationsReadOnOpen = true,
  });

  final String? jobId;
  final String? jobTitle;
  final bool markNotificationsReadOnOpen;

  @override
  State<EmployerApplicationsPage> createState() =>
      _EmployerApplicationsPageState();
}

class _EmployerApplicationsPageState extends State<EmployerApplicationsPage> {
  final ApplicationService _applicationService = ApplicationService();
  final NotificationService _notificationService = NotificationService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _processingIds = {};
  _ApplicationFilter? _selectedFilter;
  String _searchText = '';
  int _streamVersion = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
    if (widget.markNotificationsReadOnOpen) {
      _markApplicationNotificationsRead();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approve(EmployerApplicationItem item) async {
    await _runStatusAction(
      item.id,
      () => _applicationService.approveApplication(item.id),
      'Application approved. Match and chat created.',
    );
  }

  Future<void> _reject(EmployerApplicationItem item) async {
    await _runStatusAction(
      item.id,
      () => _applicationService.rejectApplication(item.id),
      'Application rejected.',
    );
  }

  Future<void> _runStatusAction(
    String applicationId,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _processingIds.add(applicationId));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(applicationId));
    }
  }

  void _openDetails(EmployerApplicationItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployerApplicationDetailsPage(applicationId: item.id),
      ),
    );
  }

  void _openChat(EmployerApplicationItem item) {
    final chatId = item.chatId;
    if (chatId == null || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approve this application to message.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatDetailPage(chatId: chatId)),
    );
  }

  bool _canReviewEmployee(EmployerApplicationItem item) {
    return item.isApproved &&
      item.candidate.id.isNotEmpty &&
      item.job.id.isNotEmpty;
  }

  Future<void> _openEmployeeReview(EmployerApplicationItem item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again')),
      );
      return;
    }

    final reviewed = await _reviewService.hasUserReviewedJob(
      jobId: item.job.id,
      reviewerId: currentUser.uid,
      targetUserId: item.candidate.id,
    );
    if (!mounted || reviewed) {
      if (mounted && reviewed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already reviewed this worker for this job.'),
          ),
        );
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddReviewScreen(
          jobId: item.job.id,
          jobTitle: item.job.title,
          targetUserId: item.candidate.id,
          targetUserName: item.candidate.name,
          targetRole: 'employee',
          reviewerRole: 'employer',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted.')),
      );
    }
  }

  List<EmployerApplicationItem> _visibleItems(
    List<EmployerApplicationItem> items,
    _ApplicationFilter filter,
  ) {
    final filtered = items.where((item) {
      final matchesFilter = switch (filter) {
        _ApplicationFilter.all => true,
        _ApplicationFilter.pending => item.isPending,
        _ApplicationFilter.approved => item.isApproved,
        _ApplicationFilter.rejected => item.isRejected,
      };
      if (!matchesFilter) return false;
      if (_searchText.isEmpty) return true;
      final haystack =
          '${item.candidate.name} ${item.job.title} ${item.candidate.skills.join(' ')}'
              .toLowerCase();
      return haystack.contains(_searchText);
    }).toList();

    filtered.sort((a, b) {
      final statusCompare = _statusRank(
        a.status,
      ).compareTo(_statusRank(b.status));
      if (statusCompare != 0) return statusCompare;
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return filtered;
  }

  int _statusRank(String status) {
    return status == 'pending'
        ? 0
        : status == 'approved'
        ? 1
        : 2;
  }

  void _retry() => setState(() => _streamVersion++);

  Future<void> _markApplicationNotificationsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }
    await _notificationService.markNotificationsAsReadByTypes(
      userId: currentUser.uid,
      types: const ['application_created'],
    );
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
        child: StreamBuilder<List<EmployerApplicationItem>>(
          key: ValueKey(_streamVersion),
          stream: _applicationService.watchEmployerApplications(
            jobId: widget.jobId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingView();
            }

            if (snapshot.hasError) {
              return _ApplicationsErrorView(
                error: snapshot.error.toString(),
                onRetry: _retry,
              );
            }

            final allItems = snapshot.data ?? const [];
            final stats = _ApplicationStats.fromItems(allItems);
            final activeFilter =
                _selectedFilter ??
                (stats.pending > 0
                    ? _ApplicationFilter.pending
                    : _ApplicationFilter.all);
            final visibleItems = _visibleItems(allItems, activeFilter);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _Header(
                        searchController: _searchController,
                        jobTitle: widget.jobTitle,
                        showBackButton:
                            widget.jobId != null &&
                            widget.jobId!.trim().isNotEmpty,
                      ),
                      const SizedBox(height: 18),
                      _StatsRow(stats: stats),
                      const SizedBox(height: 18),
                      _FilterTabs(
                        value: activeFilter,
                        onChanged: (filter) =>
                            setState(() => _selectedFilter = filter),
                      ),
                    ]),
                  ),
                ),
                if (allItems.isEmpty)
                  const SliverFillRemaining(child: _EmptyView())
                else if (visibleItems.isEmpty)
                  SliverFillRemaining(
                    child: _FilteredEmptyView(filter: activeFilter),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        final isProcessing = _processingIds.contains(item.id);
                        return _ApplicationCard(
                          item: item,
                          isProcessing: isProcessing,
                          onView: () => _openDetails(item),
                          onApprove: () => _approve(item),
                          onReject: () => _reject(item),
                          onMessage: () => _openChat(item),
                          onReview: _canReviewEmployee(item)
                              ? () => _openEmployeeReview(item)
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searchController,
    required this.showBackButton,
    this.jobTitle,
  });

  final TextEditingController searchController;
  final bool showBackButton;
  final String? jobTitle;

  @override
  Widget build(BuildContext context) {
    final cleanJobTitle = jobTitle?.trim();
    final hasJobTitle = cleanJobTitle != null && cleanJobTitle.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) ...[
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                !hasJobTitle
                    ? 'Applications'
                    : 'Applicants for $cleanJobTitle',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                !hasJobTitle
                    ? 'Review candidates and respond quickly'
                    : 'Review candidates for this job',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RoundIconButton(
          icon: Icons.search_rounded,
          onTap: () => _showSearchSheet(context, searchController),
        ),
      ],
    );
  }

  void _showSearchSheet(
    BuildContext context,
    TextEditingController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: AppTextStyles.input,
                decoration: InputDecoration(
                  hintText: 'Search candidates or jobs',
                  hintStyle: AppTextStyles.hint,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.lightText,
                  ),
                  filled: true,
                  fillColor: AppColors.navyBg.withValues(alpha: 0.44),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.coralAccent),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final _ApplicationStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'All', value: stats.all, color: AppColors.white),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Pending',
          value: stats.pending,
          color: _ApplicationStatusStyle.pending.color,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Approved',
          value: stats.approved,
          color: _ApplicationStatusStyle.approved.color,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Rejected',
          value: stats.rejected,
          color: _ApplicationStatusStyle.rejected.color,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(label, style: AppTextStyles.label.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.value, required this.onChanged});

  final _ApplicationFilter value;
  final ValueChanged<_ApplicationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = {
      _ApplicationFilter.all: 'All',
      _ApplicationFilter.pending: 'Pending',
      _ApplicationFilter.approved: 'Approved',
      _ApplicationFilter.rejected: 'Rejected',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: labels.entries.map((entry) {
          final selected = value == entry.key;
          final style = _ApplicationStatusStyle.fromFilter(entry.key);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.value),
                  if (entry.key != _ApplicationFilter.all) ...[
                    const SizedBox(width: 7),
                    Icon(Icons.circle, size: 8, color: style.color),
                  ],
                ],
              ),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: AppColors.coralAccent,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: selected ? AppColors.coralAccent : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: selected ? AppColors.navyBg : AppColors.lightText,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.item,
    required this.isProcessing,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onMessage,
    this.onReview,
  });

  final EmployerApplicationItem item;
  final bool isProcessing;
  final VoidCallback onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMessage;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final candidate = item.candidate;
    final job = item.job;
    final style = _ApplicationStatusStyle.fromStatus(item.status);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 350;
        final photoSize = compact ? 108.0 : 116.0;
        final thumbnailWidth = compact ? 72.0 : 82.0;
        final thumbnailHeight = compact ? 56.0 : 62.0;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CandidatePhoto(
                      imageUrl: candidate.imageUrl,
                      name: candidate.name,
                      size: photoSize,
                      borderRadius: 16,
                    ),
                    SizedBox(width: compact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  candidate.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StatusBadge(style: style),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Applied for', style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  job.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _JobThumbnail(
                                imageUrl: job.imageUrl,
                                width: thumbnailWidth,
                                height: thumbnailHeight,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 5,
                            children: [
                              _MetaText(
                                icon: Icons.location_on_outlined,
                                text:
                                    candidate.city ??
                                    candidate.locationLabel ??
                                    'Location not set',
                              ),
                              _MetaText(
                                icon: Icons.schedule_rounded,
                                text: _relativeTime(item.createdAt),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          _SkillsPreview(skills: candidate.skills),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _ApplicationActions(
                  item: item,
                  isProcessing: isProcessing,
                  onView: onView,
                  onApprove: onApprove,
                  onReject: onReject,
                  onMessage: onMessage,
                  onReview: onReview,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApplicationActions extends StatelessWidget {
  const _ApplicationActions({
    required this.item,
    required this.isProcessing,
    required this.onView,
    required this.onApprove,
    required this.onReject,
    required this.onMessage,
    this.onReview,
  });

  final EmployerApplicationItem item;
  final bool isProcessing;
  final VoidCallback onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMessage;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    if (item.isPending) {
      return Row(
        children: [
          Expanded(
            child: _OutlineActionButton(
              icon: Icons.visibility_outlined,
              label: 'View profile',
              onTap: isProcessing ? null : onView,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OutlineActionButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Approve',
              color: _ApplicationStatusStyle.approved.color,
              onTap: isProcessing ? null : onApprove,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OutlineActionButton(
              icon: Icons.cancel_outlined,
              label: 'Reject',
              color: _ApplicationStatusStyle.rejected.color,
              onTap: isProcessing ? null : onReject,
            ),
          ),
        ],
      );
    }

    if (item.isApproved) {
      return Row(
        children: [
          Expanded(
            child: _OutlineActionButton(
              icon: Icons.visibility_outlined,
              label: 'View profile',
              onTap: onView,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OutlineActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              onTap: onMessage,
            ),
          ),
          const SizedBox(width: 8),
          if (onReview != null)
            Expanded(
              child: _OutlineActionButton(
                icon: Icons.star_outline_rounded,
                label: 'Write Review',
                color: AppColors.coralAccent,
                onTap: onReview,
              ),
            )
          else
            _RoundIconButton(
              icon: Icons.more_horiz_rounded,
              onTap: onView,
              size: 42,
            ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: _OutlineActionButton(
        icon: Icons.visibility_outlined,
        label: 'View profile',
        onTap: onView,
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.coralAccent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.75)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _CandidatePhoto extends StatelessWidget {
  const _CandidatePhoto({
    required this.imageUrl,
    required this.name,
    required this.size,
    required this.borderRadius,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? _AvatarFallback(name: name)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _AvatarFallback(name: name),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF263D67), AppColors.navyBg]),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _JobThumbnail extends StatelessWidget {
  const _JobThumbnail({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String? imageUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null
            ? const _ImageFallback(icon: Icons.work_outline_rounded)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const _ImageFallback(icon: Icons.work_outline_rounded),
              ),
      ),
    );
  }
}

class _SkillsPreview extends StatelessWidget {
  const _SkillsPreview({required this.skills});

  final List<String> skills;

  @override
  Widget build(BuildContext context) {
    final visible = skills.take(2).toList();
    final remaining = skills.length - visible.length;
    if (visible.isEmpty) {
      return const Text('No skills listed', style: AppTextStyles.label);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            ...visible.map(
              (skill) =>
                  _TinyChip(label: skill, maxWidth: constraints.maxWidth),
            ),
            if (remaining > 0) _TinyChip(label: '+$remaining'),
          ],
        );
      },
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label, this.maxWidth});

  final String label;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.navyBg.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 13,
              color: Colors.white70,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.coralAccent, size: 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.style});

  final _ApplicationStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: style.color, size: 14),
          const SizedBox(width: 5),
          Text(
            style.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppColors.lightText,
      style: IconButton.styleFrom(
        fixedSize: Size(size, size),
        side: const BorderSide(color: AppColors.border),
        shape: const CircleBorder(),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, Color(0xFF263D67), AppColors.navyBg],
        ),
      ),
      child: Icon(icon, color: AppColors.coralAccent),
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

  factory _ApplicationStats.fromItems(List<EmployerApplicationItem> items) {
    return _ApplicationStats(
      all: items.length,
      pending: items.where((item) => item.isPending).length,
      approved: items.where((item) => item.isApproved).length,
      rejected: items.where((item) => item.isRejected).length,
    );
  }
}

class _ApplicationStatusStyle {
  const _ApplicationStatusStyle({
    required this.label,
    required this.color,
    required this.icon,
  });

  static const pending = _ApplicationStatusStyle(
    label: 'Pending',
    color: Color(0xFFFFC857),
    icon: Icons.schedule_rounded,
  );
  static const approved = _ApplicationStatusStyle(
    label: 'Approved',
    color: Color(0xFF6FD37A),
    icon: Icons.check_circle_outline_rounded,
  );
  static const rejected = _ApplicationStatusStyle(
    label: 'Rejected',
    color: Color(0xFFFF6B6B),
    icon: Icons.cancel_outlined,
  );

  final String label;
  final Color color;
  final IconData icon;

  static _ApplicationStatusStyle fromStatus(String status) {
    return status == 'approved'
        ? approved
        : status == 'rejected'
        ? rejected
        : pending;
  }

  static _ApplicationStatusStyle fromFilter(_ApplicationFilter filter) {
    return filter == _ApplicationFilter.approved
        ? approved
        : filter == _ApplicationFilter.rejected
        ? rejected
        : pending;
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
            'Please sign in to view applications.',
            style: AppTextStyles.body,
          ),
        ),
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _StateCard(
          icon: Icons.inbox_outlined,
          title: 'No applications yet',
          message: "When workers apply to your jobs, they'll appear here.",
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
      _ApplicationFilter.all => 'applications',
      _ApplicationFilter.pending => 'pending applications',
      _ApplicationFilter.approved => 'approved applications',
      _ApplicationFilter.rejected => 'rejected applications',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _StateCard(
          icon: Icons.filter_alt_off_outlined,
          title: 'No $label',
          message: 'Try another filter or search term.',
        ),
      ),
    );
  }
}

class _ApplicationsErrorView extends StatelessWidget {
  const _ApplicationsErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _StateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load applications',
          message: error,
          action: OutlinedButton(
            onPressed: onRetry,
            style: AppButtonStyles.secondaryOutline(),
            child: const Text('Retry'),
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
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

String _relativeTime(DateTime? date) {
  if (date == null) return 'Recently';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}

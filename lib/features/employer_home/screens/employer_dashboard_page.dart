import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employer_applications_page.dart';
import '../../jobs/screens/employer_jobs_page.dart';
import '../../messages/screens/messages_page.dart';
import '../services/employer_dashboard_service.dart';

class EmployerDashboardPage extends StatefulWidget {
  const EmployerDashboardPage({super.key});

  @override
  State<EmployerDashboardPage> createState() => _EmployerDashboardPageState();
}

class _EmployerDashboardPageState extends State<EmployerDashboardPage> {
  final EmployerDashboardService _service = EmployerDashboardService();
  int _retryKey = 0;

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _retry() {
    setState(() => _retryKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: StreamBuilder<EmployerDashboardData>(
          key: ValueKey(_retryKey),
          stream: _service.watchDashboard(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _DashboardLoadingState();
            }

            if (snapshot.hasError) {
              return _DashboardErrorState(onRetry: _retry);
            }

            final data = snapshot.data;
            if (data == null) {
              return const _DashboardLoadingState();
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.horizontal,
                AppSpacing.vertical,
                AppSpacing.horizontal,
                30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedSection(
                    index: 0,
                    child: _BrandedHeader(businessName: data.businessName),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedSection(
                    index: 1,
                    child: _PrimaryActionCard(
                      onTap: () => _openPage(const EmployerJobsPage()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section + 4),
                  _AnimatedSection(
                    index: 2,
                    child: _HiringSnapshot(stats: data.stats),
                  ),
                  if (data.isNewEmployer) ...[
                    const SizedBox(height: AppSpacing.section + 4),
                    _AnimatedSection(
                      index: 3,
                      child: _NewEmployerState(
                        onCreateJob: () => _openPage(const EmployerJobsPage()),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.section + 4),
                    _AnimatedSection(
                      index: 3,
                      child: _NeedsAttentionSection(
                        items: data.attentionItems,
                        onOpenApplications: () =>
                            _openPage(const EmployerApplicationsPage()),
                        onOpenMessages: () =>
                            _openPage(const MessagesPage(role: 'employer')),
                        onOpenJobs: () => _openPage(const EmployerJobsPage()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section + 4),
                    _AnimatedSection(
                      index: 4,
                      child: _RecentApplicationsSection(
                        applications: data.recentApplications,
                        onTap: () =>
                            _openPage(const EmployerApplicationsPage()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.section + 4),
                    _AnimatedSection(
                      index: 5,
                      child: _ActiveJobsSection(
                        jobs: data.activeJobs,
                        onTap: () => _openPage(const EmployerJobsPage()),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandedHeader extends StatelessWidget {
  const _BrandedHeader({required this.businessName});

  final String businessName;

  @override
  Widget build(BuildContext context) {
    final greeting = businessName == 'your business'
        ? 'Welcome back 👋'
        : 'Good evening, $businessName 👋';
    final logoHeight = (MediaQuery.sizeOf(context).width * 0.28).clamp(
      96.0,
      120.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'assets/images/wurkit_retro_header.png',
            width: double.infinity,
            height: logoHeight,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          greeting,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Here's what's happening with your hiring today.",
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need workers soon?',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Post a short-term job and start receiving applications in minutes.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    style: AppButtonStyles.primary(
                      foregroundColor: AppColors.navyBg,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      'Create Job Post',
                      style: AppTextStyles.buttonLabel(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.coralAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              color: AppColors.coralAccent,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _HiringSnapshot extends StatelessWidget {
  const _HiringSnapshot({required this.stats});

  final EmployerDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Hiring Snapshot'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.32,
          children: [
            _StatCard(
              label: 'Active Jobs',
              value: stats.activeJobs,
              icon: Icons.work_history_outlined,
            ),
            _StatCard(
              label: 'Pending Applications',
              value: stats.pendingApplications,
              icon: Icons.assignment_late_outlined,
            ),
            _StatCard(
              label: 'Active Matches',
              value: stats.activeMatches,
              icon: Icons.handshake_outlined,
            ),
            _StatCard(
              label: 'Unread Messages',
              value: stats.unreadMessages,
              icon: Icons.mark_chat_unread_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 24),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              value.toString(),
              key: ValueKey(value),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label,
          ),
        ],
      ),
    );
  }
}

class _NeedsAttentionSection extends StatelessWidget {
  const _NeedsAttentionSection({
    required this.items,
    required this.onOpenApplications,
    required this.onOpenMessages,
    required this.onOpenJobs,
  });

  final List<EmployerAttentionItem> items;
  final VoidCallback onOpenApplications;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenJobs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Needs Your Attention'),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const _PositiveAttentionCard()
        else
          Column(
            children: [
              for (final item in items) ...[
                _AttentionItemCard(
                  item: item,
                  onTap: switch (item.type) {
                    EmployerAttentionType.applications => onOpenApplications,
                    EmployerAttentionType.messages => onOpenMessages,
                    EmployerAttentionType.urgentJobs => onOpenJobs,
                  },
                ),
                if (item != items.last) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _AttentionItemCard extends StatelessWidget {
  const _AttentionItemCard({required this.item, required this.onTap});

  final EmployerAttentionItem item;
  final VoidCallback onTap;

  IconData get icon {
    return switch (item.type) {
      EmployerAttentionType.applications => Icons.assignment_rounded,
      EmployerAttentionType.messages => Icons.chat_bubble_rounded,
      EmployerAttentionType.urgentJobs => Icons.bolt_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          _AccentIcon(icon),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.lightText),
        ],
      ),
    );
  }
}

class _PositiveAttentionCard extends StatelessWidget {
  const _PositiveAttentionCard();

  @override
  Widget build(BuildContext context) {
    return const _DashboardCard(
      child: Row(
        children: [
          _AccentIcon(Icons.check_circle_rounded),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything looks good',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'No urgent hiring tasks right now.',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentApplicationsSection extends StatelessWidget {
  const _RecentApplicationsSection({
    required this.applications,
    required this.onTap,
  });

  final List<EmployerRecentApplication> applications;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PreviewSection(
      title: 'Recent Applications',
      emptyText: 'No applications yet.',
      isEmpty: applications.isEmpty,
      children: applications.map((application) {
        return _ApplicationRow(application: application, onTap: onTap);
      }).toList(),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.application, required this.onTap});

  final EmployerRecentApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          _EmployeeAvatar(
            imageUrl: application.employeeImageUrl,
            name: application.employeeName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  application.jobTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 5),
                Text(
                  _relativeTime(application.createdAt),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: application.status),
        ],
      ),
    );
  }
}

class _ActiveJobsSection extends StatelessWidget {
  const _ActiveJobsSection({required this.jobs, required this.onTap});

  final List<EmployerActiveJob> jobs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PreviewSection(
      title: 'Active Jobs',
      emptyText: 'You have no active job posts.',
      isEmpty: jobs.isEmpty,
      children: jobs.map((job) => _JobRow(job: job, onTap: onTap)).toList(),
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.job, required this.onTap});

  final EmployerActiveJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          _AccentIcon(job.urgent ? Icons.bolt_rounded : Icons.work_rounded),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (job.urgent) const _UrgentBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _jobSchedule(job),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 4),
                Text(
                  '${job.applicationsCount} applications',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.emptyText,
    required this.isEmpty,
    required this.children,
  });

  final String title;
  final String emptyText;
  final bool isEmpty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 10),
        if (isEmpty)
          _DashboardCard(child: Text(emptyText, style: AppTextStyles.body))
        else
          Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _NewEmployerState extends StatelessWidget {
  const _NewEmployerState({required this.onCreateJob});

  final VoidCallback onCreateJob;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to hire your first worker?',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Create your first job post and start receiving applications.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: AppSpacing.buttonHeight,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCreateJob,
              style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
              child: Text(
                'Create Job Post',
                style: AppTextStyles.buttonLabel(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.coralAccent),
          SizedBox(height: 16),
          Text('Loading your dashboard...', style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.horizontal),
        child: _DashboardCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.coralAccent,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load your dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: AppButtonStyles.primary(
                    foregroundColor: AppColors.navyBg,
                  ),
                  child: Text('Try again', style: AppTextStyles.buttonLabel()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 55),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _TapCard extends StatelessWidget {
  const _TapCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AccentIcon extends StatelessWidget {
  const _AccentIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.coralAccent, size: 20),
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  const _EmployeeAvatar({this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'W' : name.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 21,
      backgroundColor: AppColors.coralAccent.withValues(alpha: 0.18),
      backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      child: imageUrl == null
          ? Text(
              initial,
              style: const TextStyle(
                color: AppColors.coralAccent,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'approved'
        ? Colors.greenAccent
        : status == 'rejected'
        ? Colors.redAccent
        : AppColors.coralAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Urgent',
        style: TextStyle(
          color: AppColors.coralAccent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _relativeTime(DateTime? date) {
  if (date == null) {
    return 'Recently';
  }
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }
  return '${date.month}/${date.day}/${date.year}';
}

String _jobSchedule(EmployerActiveJob job) {
  final shift = _shiftText(job.shiftStart, job.shiftEnd);
  return [
    job.date,
    shift,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}

String? _shiftText(String? start, String? end) {
  if (start == null && end == null) {
    return null;
  }
  if (start == null) {
    return end;
  }
  if (end == null) {
    return start;
  }
  return '$start-$end';
}

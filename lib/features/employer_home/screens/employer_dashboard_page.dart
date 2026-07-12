import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employer_application_details_page.dart';
import '../../applications/screens/employer_applications_page.dart';
import '../../jobs/screens/employer_job_details_page.dart';
import '../../jobs/screens/employer_jobs_page.dart';
import '../../jobs/screens/post_job_screen.dart';
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
                      onTap: () => _openPage(const PostJobScreen()),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AnimatedSection(
                    index: 2,
                    child: _HiringSnapshot(stats: data.stats),
                  ),
                  if (data.isNewEmployer) ...[
                    const SizedBox(height: 18),
                    _AnimatedSection(
                      index: 3,
                      child: _NewEmployerState(
                        onCreateJob: () => _openPage(const PostJobScreen()),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 18),
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
                    const SizedBox(height: 18),
                    _AnimatedSection(
                      index: 4,
                      child: _RecentApplicationsSection(
                        applications: data.recentApplications,
                        onViewAll: () =>
                            _openPage(const EmployerApplicationsPage()),
                        onOpen: (application) => _openPage(
                          EmployerApplicationDetailsPage(
                            applicationId: application.id,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AnimatedSection(
                      index: 5,
                      child: _ActiveJobsSection(
                        jobs: data.activeJobs,
                        onViewAll: () => _openPage(const EmployerJobsPage()),
                        onOpen: (job) =>
                            _openPage(EmployerJobDetailsPage(jobId: job.id)),
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
        ? 'Welcome back'
        : 'Welcome back, $businessName';
    final logoHeight = (MediaQuery.sizeOf(context).width * 0.24).clamp(
      82.0,
      104.0,
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
        const SizedBox(height: 6),
        Text(
          greeting,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Manage your hiring activity', style: AppTextStyles.body),
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
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.coralAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.add_business_rounded,
              color: AppColors.coralAccent,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need workers soon?',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Create a short-term job and start receiving applications in minutes.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 12.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: onTap,
              style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg)
                  .copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 13),
                    ),
                  ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Create Job',
                style: AppTextStyles.buttonLabel(fontSize: 13),
              ),
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardExtent = 128.0 + ((textScale - 1).clamp(0.0, 1.2) * 24);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Hiring Overview'),
        const SizedBox(height: 10),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardExtent,
          ),
          children: [
            _StatCard(
              label: 'Active Jobs',
              value: stats.activeJobs,
              icon: Icons.business_center_rounded,
              accent: AppColors.coralAccent,
            ),
            _StatCard(
              label: 'Pending Applications',
              value: stats.pendingApplications,
              icon: Icons.assignment_rounded,
              accent: Color(0xFFFFB84D),
            ),
            _StatCard(
              label: 'Unread Messages',
              value: stats.unreadMessages,
              icon: Icons.chat_bubble_rounded,
              accent: Color(0xFF82A8FF),
            ),
            _StatCard(
              label: 'Urgent Jobs',
              value: stats.urgentJobs,
              icon: Icons.bolt_rounded,
              accent: Color(0xFFFF876F),
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
    required this.accent,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.17),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              value.toString(),
              key: ValueKey(value),
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(fontSize: 11.5),
            ),
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

  String get subtitle => switch (item.type) {
    EmployerAttentionType.applications => 'Review and respond to applicants',
    EmployerAttentionType.messages => 'Reply to your worker conversations',
    EmployerAttentionType.urgentJobs => 'Manage urgent openings',
  };

  Color get accent => switch (item.type) {
    EmployerAttentionType.applications => AppColors.coralAccent,
    EmployerAttentionType.messages => const Color(0xFF8FA8FF),
    EmployerAttentionType.urgentJobs => const Color(0xFFFF876F),
  };

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      child: Row(
        children: [
          _AccentIcon(icon, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(fontSize: 12),
                ),
              ],
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
    required this.onViewAll,
    required this.onOpen,
  });
  final List<EmployerRecentApplication> applications;
  final VoidCallback onViewAll;
  final ValueChanged<EmployerRecentApplication> onOpen;

  @override
  Widget build(BuildContext context) {
    return _HorizontalDashboardSection(
      title: 'Recent Applications',
      onViewAll: onViewAll,
      emptyText: 'No applications yet.',
      isEmpty: applications.isEmpty,
      height: 150,
      itemCount: applications.length,
      itemBuilder: (context, index) {
        final application = applications[index];
        return SizedBox(
          width: 178,
          child: _RecentApplicationCard(
            application: application,
            onTap: () => onOpen(application),
          ),
        );
      },
    );
  }
}

class _RecentApplicationCard extends StatelessWidget {
  const _RecentApplicationCard({
    required this.application,
    required this.onTap,
  });
  final EmployerRecentApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EmployeeAvatar(
                imageUrl: application.employeeImageUrl,
                name: application.employeeName,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  application.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            application.jobTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label,
          ),
          const Spacer(),
          Row(
            children: [
              _StatusBadge(status: application.status),
              const Spacer(),
              Text(
                _relativeTime(application.createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveJobsSection extends StatelessWidget {
  const _ActiveJobsSection({
    required this.jobs,
    required this.onViewAll,
    required this.onOpen,
  });
  final List<EmployerActiveJob> jobs;
  final VoidCallback onViewAll;
  final ValueChanged<EmployerActiveJob> onOpen;

  @override
  Widget build(BuildContext context) {
    return _HorizontalDashboardSection(
      title: 'Active Jobs',
      onViewAll: onViewAll,
      emptyText: 'You have no active job posts.',
      isEmpty: jobs.isEmpty,
      height: 154,
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return SizedBox(
          width: 230,
          child: _ActiveJobCard(job: job, onTap: () => onOpen(job)),
        );
      },
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});
  final EmployerActiveJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TapCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _JobImage(job: job),
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
                        maxLines: 2,
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
                const SizedBox(height: 6),
                Text(
                  _jobSchedule(job),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  '${job.applicationsCount} applications',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
                const Spacer(),
                const Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF35D879), size: 10),
                    SizedBox(width: 6),
                    Text('Active', style: AppTextStyles.label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobImage extends StatelessWidget {
  const _JobImage({required this.job});
  final EmployerActiveJob job;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: double.infinity,
      constraints: const BoxConstraints(maxHeight: 104),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.navyBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: job.imageUrl == null
          ? Icon(
              job.urgent ? Icons.bolt_rounded : Icons.work_outline_rounded,
              color: AppColors.coralAccent,
              size: 25,
            )
          : Image.network(
              job.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.work_outline_rounded,
                color: AppColors.coralAccent,
              ),
            ),
    );
  }
}

class _HorizontalDashboardSection extends StatelessWidget {
  const _HorizontalDashboardSection({
    required this.title,
    required this.onViewAll,
    required this.emptyText,
    required this.isEmpty,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });
  final String title;
  final VoidCallback onViewAll;
  final String emptyText;
  final bool isEmpty;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(title)),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.coralAccent,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isEmpty)
          _DashboardCard(child: Text(emptyText, style: AppTextStyles.body))
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
            ),
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
  const _TapCard({
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final VoidCallback onTap;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: padding,
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
  const _AccentIcon(this.icon, {this.color = AppColors.coralAccent});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 20),
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

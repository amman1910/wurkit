import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employer_applications_page.dart';
import '../models/employer_job_models.dart';
import '../services/job_service.dart';
import 'post_job_screen.dart';

class EmployerJobDetailsPage extends StatefulWidget {
  const EmployerJobDetailsPage({super.key, required this.jobId});

  final String jobId;

  @override
  State<EmployerJobDetailsPage> createState() => _EmployerJobDetailsPageState();
}

class _EmployerJobDetailsPageState extends State<EmployerJobDetailsPage> {
  final JobService _jobService = JobService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _jobStream;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _jobStream = _firestore.collection('jobs').doc(widget.jobId).snapshots();
  }

  Future<_EmployerJobSupport> _loadSupport(EmployerJob job) async {
    final profileFuture = _jobService.getCurrentEmployerProfile();
    final statsFuture = _jobService.getApplicationStatsForJob(job.id);
    return _EmployerJobSupport(
      employerProfile: await profileFuture,
      stats: await statsFuture,
    );
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage, {
    bool popAfter = false,
  }) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: Colors.green.shade700,
        ),
      );
      if (popAfter) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openApplicants(EmployerJob job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmployerApplicationsPage(jobId: job.id, jobTitle: job.title),
      ),
    );
  }

  Future<void> _openJobEditor(EmployerJob job, {required bool duplicate}) async {
    try {
      final jobData = await _jobService.getOwnedJobData(job.id);
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PostJobScreen(
            editJobId: duplicate ? null : job.id,
            initialJobData: jobData,
            isEditMode: !duplicate,
            isDuplicateMode: duplicate,
          ),
        ),
      );
      if (changed == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _confirmDeleteDraft(EmployerJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete draft?'),
        content: Text(
          'This permanently deletes "${job.title}".',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
            child: const Text('Delete draft'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runAction(
        () => _jobService.deleteDraft(job.id),
        'Draft deleted',
        popAfter: true,
      );
    }
  }

  void _showMoreActions(EmployerJob job) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManagementActionsSheet(
        job: job,
        onEdit: () {
          Navigator.pop(context);
          _openJobEditor(job, duplicate: false);
        },
        onDuplicate: () {
          Navigator.pop(context);
          _openJobEditor(job, duplicate: true);
        },
        onApplicants: () {
          Navigator.pop(context);
          _openApplicants(job);
        },
        onPublish: () {
          Navigator.pop(context);
          _runAction(() => _jobService.publishDraft(job.id), 'Job published');
        },
        onClose: () {
          Navigator.pop(context);
          _runAction(() => _jobService.closeJob(job.id), 'Job closed');
        },
        onReopen: () {
          Navigator.pop(context);
          _runAction(() => _jobService.reopenJob(job.id), 'Job reopened');
        },
        onDeleteDraft: () {
          Navigator.pop(context);
          _confirmDeleteDraft(job);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _jobStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.navyBg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.coralAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return _MessageScaffold(
            title: 'Could not load job',
            message: snapshot.error.toString(),
          );
        }

        final document = snapshot.data;
        if (document == null || !document.exists) {
          return const _MessageScaffold(
            title: 'Job not found',
            message: 'This job may have been removed.',
          );
        }

        final job = EmployerJob.fromDocument(document);
        return FutureBuilder<_EmployerJobSupport>(
          future: _loadSupport(job),
          builder: (context, supportSnapshot) {
            final support = supportSnapshot.data ?? const _EmployerJobSupport();
            final businessLogoUrl = _readString(
              support.employerProfile?['businessLogoUrl'],
            );
            final stats = support.stats ?? const JobApplicationStats.empty();

            return Scaffold(
              backgroundColor: AppColors.navyBg,
              body: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _EmployerJobHero(
                      job: job,
                      businessLogoUrl: businessLogoUrl,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _SummaryGrid(job: job, stats: stats),
                        const SizedBox(height: 16),
                        _AboutJobCard(job: job),
                        const SizedBox(height: 16),
                        _RequiredSkillsCard(skills: job.requiredSkills),
                        const SizedBox(height: 16),
                        _ApplicationsSummary(
                          stats: stats,
                          onViewApplicants: () => _openApplicants(job),
                        ),
                        const SizedBox(height: 16),
                        _JobStatusCard(job: job),
                      ]),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _EmployerBottomBar(
                isBusy: _isBusy,
                onPrimary: () => _openApplicants(job),
                onMore: () => _showMoreActions(job),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmployerJobHero extends StatelessWidget {
  const _EmployerJobHero({required this.job, required this.businessLogoUrl});

  final EmployerJob job;
  final String? businessLogoUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = job.imageUrl ?? businessLogoUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      child: SizedBox(
        height: 365,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null)
              const _HeroFallback()
            else
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _HeroFallback(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xAA000000),
                    Color(0x22000000),
                    Color(0xF20B1426),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: MediaQuery.paddingOf(context).top + 8,
              child: _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              right: 18,
              top: MediaQuery.paddingOf(context).top + 16,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusBadge(job: job),
                  if (job.urgent)
                    const _HeroBadge(label: 'Urgent', icon: Icons.bolt_rounded),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.jobCategory ?? 'Short-term role',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.03,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.job, required this.stats});

  final EmployerJob job;
  final JobApplicationStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryItem(
        icon: Icons.payments_outlined,
        label: 'Pay',
        value: job.salaryText,
      ),
      _SummaryItem(
        icon: Icons.calendar_month_rounded,
        label: 'Date',
        value: job.dateText ?? 'Flexible',
      ),
      _SummaryItem(
        icon: Icons.schedule_rounded,
        label: 'Shift',
        value: job.shiftText ?? 'Time TBD',
      ),
      _SummaryItem(
        icon: Icons.location_on_outlined,
        label: 'Location',
        value: job.locationText ?? 'Shared soon',
      ),
      _SummaryItem(
        icon: Icons.auto_awesome_rounded,
        label: 'Skills',
        value: _skillsCountText(job.requiredSkills.length),
      ),
      _SummaryItem(
        icon: Icons.groups_rounded,
        label: 'Applications',
        value: '${stats.total} total',
      ),
      _SummaryItem(
        icon: Icons.visibility_outlined,
        label: 'Visibility',
        value: job.visibility == 'draft' ? 'Draft' : 'Published',
      ),
      _SummaryItem(
        icon: Icons.flag_outlined,
        label: 'Status',
        value: job.statusLabel,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SummaryRow(left: items[0], right: items[1]),
          const Divider(color: AppColors.border, height: 18),
          _SummaryRow(left: items[2], right: items[3]),
          const Divider(color: AppColors.border, height: 18),
          _SummaryRow(left: items[4], right: items[5]),
          const Divider(color: AppColors.border, height: 18),
          _SummaryRow(left: items[6], right: items[7]),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.left, required this.right});

  final _SummaryItem left;
  final _SummaryItem right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _InfoTile(item: left)),
          const VerticalDivider(color: AppColors.border, width: 18),
          Expanded(child: _InfoTile(item: right)),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _AboutJobCard extends StatelessWidget {
  const _AboutJobCard({required this.job});

  final EmployerJob job;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'About this job',
      icon: Icons.description_outlined,
      trailing: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.coralAccent,
      ),
      child: Text(
        job.description ?? 'No detailed description was added yet.',
        style: AppTextStyles.body.copyWith(height: 1.46),
      ),
    );
  }
}

class _RequiredSkillsCard extends StatelessWidget {
  const _RequiredSkillsCard({required this.skills});

  final List<String> skills;

  void _showAllSkills(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.74,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.star_border_rounded,
                      color: AppColors.coralAccent,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Required skills',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.lightText,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: skills.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.verified_outlined,
                          color: AppColors.coralAccent,
                        ),
                        title: Text(skills[index], style: AppTextStyles.input),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSkills = skills.take(6).toList();
    final remaining = skills.length - visibleSkills.length;
    return _SectionCard(
      title: 'Required skills',
      subtitle: 'Skills expected for this role',
      icon: Icons.star_border_rounded,
      onTap: skills.isEmpty ? null : () => _showAllSkills(context),
      trailing: remaining > 0
          ? TextButton.icon(
              onPressed: () => _showAllSkills(context),
              label: const Text('View all'),
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.coralAccent,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          : null,
      child: skills.isEmpty
          ? Text(
              'No specific skills were added for this job.',
              style: AppTextStyles.body,
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...visibleSkills.map((skill) => _SkillChip(label: skill)),
                if (remaining > 0) _SkillChip(label: '+$remaining more'),
              ],
            ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.lightText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsSummary extends StatelessWidget {
  const _ApplicationsSummary({
    required this.stats,
    required this.onViewApplicants,
  });

  final JobApplicationStats stats;
  final VoidCallback onViewApplicants;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Applications summary',
      icon: Icons.groups_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final statsRow = Row(
            children: [
              _ApplicationCount(
                label: 'Total',
                value: stats.total,
                color: AppColors.white,
              ),
              _ApplicationCount(
                label: 'Pending',
                value: stats.pending,
                color: const Color(0xFFFFC857),
              ),
              _ApplicationCount(
                label: 'Approved',
                value: stats.approved,
                color: const Color(0xFF6FD37A),
              ),
              _ApplicationCount(
                label: 'Rejected',
                value: stats.rejected,
                color: const Color(0xFFFF6B6B),
              ),
            ],
          );
          final button = ElevatedButton.icon(
            onPressed: onViewApplicants,
            icon: const Icon(Icons.groups_rounded, size: 18),
            label: const Text('View applicants'),
            style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
          );

          if (constraints.maxWidth >= 430) {
            return Row(
              children: [
                Expanded(child: statsRow),
                const SizedBox(width: 16),
                SizedBox(height: 48, child: button),
              ],
            );
          }

          return Column(
            children: [
              statsRow,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, height: 50, child: button),
            ],
          );
        },
      ),
    );
  }
}

class _ApplicationCount extends StatelessWidget {
  const _ApplicationCount({
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
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTextStyles.label.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _JobStatusCard extends StatelessWidget {
  const _JobStatusCard({required this.job});

  final EmployerJob job;

  @override
  Widget build(BuildContext context) {
    final status = _JobStatusVisual.fromJob(job);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: status.color.withValues(alpha: 0.55)),
            ),
            child: Icon(status.icon, color: status.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job status',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  status.label,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(status.message, style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(status.decorativeIcon, color: status.color, size: 30),
          ),
        ],
      ),
    );
  }
}

class _JobStatusVisual {
  const _JobStatusVisual({
    required this.icon,
    required this.label,
    required this.message,
    required this.color,
    required this.decorativeIcon,
  });

  final IconData icon;
  final String label;
  final String message;
  final Color color;
  final IconData decorativeIcon;

  factory _JobStatusVisual.fromJob(EmployerJob job) {
    if (job.isDraft) {
      return const _JobStatusVisual(
        icon: Icons.edit_note_rounded,
        label: 'Draft',
        message: 'This job is saved but not visible to employees yet.',
        color: Color(0xFFFFC857),
        decorativeIcon: Icons.pending_actions_rounded,
      );
    }
    if (job.isFilled) {
      return const _JobStatusVisual(
        icon: Icons.check_circle_outline_rounded,
        label: 'Filled',
        message: 'A worker was selected for this job.',
        color: Color(0xFF63B3FF),
        decorativeIcon: Icons.verified_rounded,
      );
    }
    if (job.status == 'cancelled') {
      return const _JobStatusVisual(
        icon: Icons.cancel_outlined,
        label: 'Cancelled',
        message: 'This job was cancelled.',
        color: Color(0xFFFF6B6B),
        decorativeIcon: Icons.event_busy_rounded,
      );
    }
    if (job.isClosed) {
      return const _JobStatusVisual(
        icon: Icons.lock_outline_rounded,
        label: 'Closed',
        message: 'This job is no longer active.',
        color: Color(0xFFFF6B6B),
        decorativeIcon: Icons.lock_rounded,
      );
    }
    return const _JobStatusVisual(
      icon: Icons.radio_button_checked_rounded,
      label: 'Open',
      message: 'This job is live and accepting applications.',
      color: Color(0xFF6FD37A),
      decorativeIcon: Icons.campaign_outlined,
    );
  }
}

class _EmployerBottomBar extends StatelessWidget {
  const _EmployerBottomBar({
    required this.isBusy,
    required this.onPrimary,
    required this.onMore,
  });

  final bool isBusy;
  final VoidCallback onPrimary;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 13, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: AppSpacing.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: isBusy ? null : onPrimary,
                  icon: const Icon(Icons.groups_rounded),
                  label: const Text('View applicants'),
                  style: AppButtonStyles.primary(
                    foregroundColor: AppColors.navyBg,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: isBusy ? null : onMore,
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: AppColors.coralAccent,
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    fixedSize: const Size(50, 50),
                    shape: const CircleBorder(),
                  ),
                ),
                const SizedBox(height: 2),
                Text('More', style: AppTextStyles.label.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(item.icon, color: AppColors.coralAccent, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.coralAccent, size: 22),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: content,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.job});

  final EmployerJob job;

  @override
  Widget build(BuildContext context) {
    final status = _JobStatusVisual.fromJob(job);
    return _HeroBadge(
      label: status.label,
      icon: status.icon,
      iconColor: status.color,
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label, required this.icon, this.iconColor});

  final String label;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor ?? AppColors.coralAccent, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementActionsSheet extends StatelessWidget {
  const _ManagementActionsSheet({
    required this.job,
    required this.onEdit,
    required this.onDuplicate,
    required this.onApplicants,
    required this.onPublish,
    required this.onClose,
    required this.onReopen,
    required this.onDeleteDraft,
  });

  final EmployerJob job;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onApplicants;
  final VoidCallback onPublish;
  final VoidCallback onClose;
  final VoidCallback onReopen;
  final VoidCallback onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final actions = <_SheetAction>[
      if (job.isDraft) ...[
        _SheetAction(Icons.edit_outlined, 'Edit job', onEdit),
        _SheetAction(Icons.publish_rounded, 'Publish', onPublish),
        _SheetAction(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _SheetAction(
          Icons.delete_outline_rounded,
          'Delete draft',
          onDeleteDraft,
        ),
      ] else if (job.isOpen) ...[
        _SheetAction(Icons.edit_outlined, 'Edit job', onEdit),
        _SheetAction(Icons.groups_outlined, 'View applicants', onApplicants),
        _SheetAction(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _SheetAction(Icons.lock_outline_rounded, 'Close job', onClose),
      ] else ...[
        _SheetAction(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _SheetAction(Icons.refresh_rounded, 'Reopen job', onReopen),
      ],
    ];

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            ...actions.map(
              (action) => ListTile(
                leading: Icon(action.icon, color: AppColors.coralAccent),
                title: Text(action.label, style: AppTextStyles.input),
                onTap: action.onTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

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
      child: const Center(
        child: Icon(
          Icons.storefront_outlined,
          color: AppColors.coralAccent,
          size: 58,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.navyBg.withValues(alpha: 0.72),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.white),
        ),
      ),
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
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
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.coralAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployerJobSupport {
  const _EmployerJobSupport({this.employerProfile, this.stats});

  final Map<String, dynamic>? employerProfile;
  final JobApplicationStats? stats;
}

class _SheetAction {
  const _SheetAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _skillsCountText(int count) {
  if (count == 0) return 'No skills';
  if (count == 1) return '1 skill';
  return '$count skills';
}

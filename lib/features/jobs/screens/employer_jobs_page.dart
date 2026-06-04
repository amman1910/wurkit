import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/screens/employer_applications_page.dart';
import '../models/employer_job_models.dart';
import '../services/job_service.dart';
import 'employer_job_details_page.dart';
import 'post_job_screen.dart';

enum _JobFilter { all, open, urgent, drafts, filled, closed }

class EmployerJobsPage extends StatefulWidget {
  const EmployerJobsPage({super.key});

  @override
  State<EmployerJobsPage> createState() => _EmployerJobsPageState();
}

class _EmployerJobsPageState extends State<EmployerJobsPage> {
  final JobService _jobService = JobService();
  late final PageController _pageController;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _jobsStream;

  _JobFilter _filter = _JobFilter.all;
  int _currentPage = 0;
  Future<Map<String, dynamic>?>? _profileFuture;
  Future<Map<String, JobApplicationStats>>? _statsFuture;
  String? _statsJobIdsSignature;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.86);
    _jobsStream = _jobService.getEmployerJobs();
    _profileFuture = _jobService.getCurrentEmployerProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openPostJob() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    );
    if (changed == true && mounted) {
      _refreshLocalSupportData();
    }
  }

  Future<void> _openJob(EmployerJob job) async {
    HapticFeedback.selectionClick();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EmployerJobDetailsPage(jobId: job.id)),
    );
    if (changed == true && mounted) {
      _refreshLocalSupportData();
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
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
        _refreshLocalSupportData();
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

  void _refreshLocalSupportData() {
    setState(() {
      _profileFuture = _jobService.getCurrentEmployerProfile();
      _statsFuture = null;
      _statsJobIdsSignature = null;
    });
  }

  Future<void> _confirmDeleteDraft(EmployerJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete draft?'),
        content: Text(
          'This will permanently delete "${job.title}". Published jobs cannot be deleted here.',
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
      await _runAction(() => _jobService.deleteDraft(job.id), 'Draft deleted');
    }
  }

  void _showMoreActions(EmployerJob job) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _JobActionsSheet(
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

  Future<Map<String, JobApplicationStats>> _applicationStatsFutureFor(
    List<EmployerJob> jobs,
  ) {
    final jobIds = jobs.map((job) => job.id).toList()..sort();
    final signature = jobIds.join('|');
    if (_statsFuture == null || _statsJobIdsSignature != signature) {
      _statsJobIdsSignature = signature;
      _statsFuture = _jobService.loadApplicationStatsForJobs(jobIds);
    }
    return _statsFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _jobsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(
                error: snapshot.error.toString(),
                onRetry: () => setState(() {
                  _profileFuture = _jobService.getCurrentEmployerProfile();
                }),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }

            final allJobs =
                snapshot.data?.docs.map(EmployerJob.fromSnapshot).toList() ??
                [];

            if (allJobs.isEmpty) {
              return _EmptyState(onPostJob: _openPostJob);
            }

            return FutureBuilder<Map<String, dynamic>?>(
              future: _profileFuture,
              builder: (context, profileSnapshot) {
                final businessLogoUrl = _readString(
                  profileSnapshot.data?['businessLogoUrl'],
                );

                return FutureBuilder<Map<String, JobApplicationStats>>(
                  future: _applicationStatsFutureFor(allJobs),
                  builder: (context, statsSnapshot) {
                    final statsByJob = statsSnapshot.data ?? const {};
                    final visibleJobs = _sortedJobs(_filteredJobs(allJobs));
                    final stats = _DashboardStats.fromJobs(allJobs, statsByJob);
                    final currentPage = visibleJobs.isEmpty
                        ? 0
                        : _currentPage.clamp(0, visibleJobs.length - 1);

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _DashboardContent(
                        allJobsCount: allJobs.length,
                        jobs: visibleJobs,
                        stats: stats,
                        statsByJob: statsByJob,
                        businessLogoUrl: businessLogoUrl,
                        filter: _filter,
                        pageController: _pageController,
                        currentPage: currentPage,
                        isStatsLoading:
                            statsSnapshot.connectionState ==
                            ConnectionState.waiting,
                        onFilterChanged: (filter) {
                          setState(() {
                            _filter = filter;
                            _currentPage = 0;
                          });
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                        },
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        onPostJob: _openPostJob,
                        onOpenJob: _openJob,
                        onMore: _showMoreActions,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<EmployerJob> _filteredJobs(List<EmployerJob> jobs) {
    return jobs.where((job) {
      switch (_filter) {
        case _JobFilter.open:
          return job.isOpen;
        case _JobFilter.urgent:
          return job.urgent;
        case _JobFilter.drafts:
          return job.isDraft;
        case _JobFilter.filled:
          return job.isFilled;
        case _JobFilter.closed:
          return job.isClosed;
        case _JobFilter.all:
          return true;
      }
    }).toList();
  }

  List<EmployerJob> _sortedJobs(List<EmployerJob> jobs) {
    final sorted = [...jobs];
    sorted.sort((a, b) {
      return b.createdAtMillis.compareTo(a.createdAtMillis);
    });
    return sorted;
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.allJobsCount,
    required this.jobs,
    required this.stats,
    required this.statsByJob,
    required this.businessLogoUrl,
    required this.filter,
    required this.pageController,
    required this.currentPage,
    required this.isStatsLoading,
    required this.onFilterChanged,
    required this.onPageChanged,
    required this.onPostJob,
    required this.onOpenJob,
    required this.onMore,
  });

  final int allJobsCount;
  final List<EmployerJob> jobs;
  final _DashboardStats stats;
  final Map<String, JobApplicationStats> statsByJob;
  final String? businessLogoUrl;
  final _JobFilter filter;
  final PageController pageController;
  final int currentPage;
  final bool isStatsLoading;
  final ValueChanged<_JobFilter> onFilterChanged;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPostJob;
  final ValueChanged<EmployerJob> onOpenJob;
  final ValueChanged<EmployerJob> onMore;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('dashboard'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onPostJob: onPostJob),
          const SizedBox(height: 18),
          _StatsRow(stats: stats, isLoading: isStatsLoading),
          const SizedBox(height: 18),
          _FilterBar(value: filter, onChanged: onFilterChanged),
          const SizedBox(height: 18),
          if (jobs.isEmpty)
            _FilteredEmptyState(allJobsCount: allJobsCount)
          else ...[
            SizedBox(
              height: 470,
              child: PageView.builder(
                controller: pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: jobs.length,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final stats =
                      statsByJob[job.id] ?? const JobApplicationStats.empty();
                  return AnimatedBuilder(
                    animation: pageController,
                    builder: (context, child) {
                      var scale = 1.0;
                      if (pageController.hasClients &&
                          pageController.position.haveDimensions) {
                        final page =
                            pageController.page ?? currentPage.toDouble();
                        scale = (1 - ((page - index).abs() * 0.06)).clamp(
                          0.94,
                          1.0,
                        );
                      } else if (index != currentPage) {
                        scale = 0.96;
                      }
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: _EmployerJobCard(
                      job: job,
                      stats: stats,
                      businessLogoUrl: businessLogoUrl,
                      onTap: () => onOpenJob(job),
                      onView: () => onOpenJob(job),
                      onMore: () => onMore(job),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _PageDots(count: jobs.length, index: currentPage),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPostJob});

  final VoidCallback onPostJob;

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
                'My Jobs',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Manage your active, filled, and draft job posts',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: onPostJob,
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.coralAccent,
            foregroundColor: AppColors.navyBg,
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.isLoading});

  final _DashboardStats stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(label: 'Open', value: stats.open.toString()),
        const SizedBox(width: 8),
        _StatPill(
          label: 'Applicants',
          value: isLoading ? '...' : stats.applicants.toString(),
        ),
        const SizedBox(width: 8),
        _StatPill(label: 'Filled', value: stats.filled.toString()),
        const SizedBox(width: 8),
        _StatPill(label: 'Drafts', value: stats.drafts.toString()),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _JobFilter value;
  final ValueChanged<_JobFilter> onChanged;

  static const _labels = {
    _JobFilter.all: 'All',
    _JobFilter.open: 'Open',
    _JobFilter.urgent: 'Urgent',
    _JobFilter.drafts: 'Drafts',
    _JobFilter.filled: 'Filled',
    _JobFilter.closed: 'Closed',
  };

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                const SizedBox(height: 12),
                ..._labels.entries.map((entry) {
                  final selected = entry.key == value;
                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? AppColors.coralAccent : Colors.white38,
                    ),
                    title: Text(entry.value, style: AppTextStyles.input),
                    onTap: () {
                      onChanged(entry.key);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFilterOptions(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_list_rounded,
                color: AppColors.coralAccent,
                size: 20,
              ),
              const SizedBox(width: 9),
              Text(
                _labels[value]!,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployerJobCard extends StatelessWidget {
  const _EmployerJobCard({
    required this.job,
    required this.stats,
    required this.businessLogoUrl,
    required this.onTap,
    required this.onView,
    required this.onMore,
  });

  final EmployerJob job;
  final JobApplicationStats stats;
  final String? businessLogoUrl;
  final VoidCallback onTap;
  final VoidCallback onView;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final imageUrl = job.imageUrl ?? businessLogoUrl;
    final isClosed = job.isClosed;
    final image = imageUrl == null
        ? const _ImageFallback()
        : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _ImageFallback(),
          );
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (isClosed)
                          ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                            child: image,
                          )
                        else
                          image,
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x99000000),
                                Color(0x22000000),
                                Color(0xEE111B31),
                              ],
                            ),
                          ),
                        ),
                        if (isClosed)
                          Container(
                            color: Colors.black.withValues(alpha: 0.46),
                          ),
                        Positioned(
                          left: 18,
                          top: 18,
                          right: 18,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusBadge(job: job),
                              if (job.urgent)
                                const _OverlayBadge(
                                  label: 'Urgent',
                                  icon: Icons.bolt_rounded,
                                ),
                              if (stats.pending > 0)
                                _OverlayBadge(
                                  label: '${stats.pending} pending',
                                  icon: Icons.mark_email_unread_outlined,
                                )
                              else
                                _OverlayBadge(
                                  label: '${stats.total} applicants',
                                  icon: Icons.group_outlined,
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                job.jobCategory ?? 'Short-term role',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                job.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isClosed
                                      ? Colors.white.withValues(alpha: 0.78)
                                      : AppColors.white,
                                  fontSize: isClosed ? 26 : 28,
                                  fontWeight: isClosed
                                      ? FontWeight.w800
                                      : FontWeight.w900,
                                  height: 1.04,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _OverlayInfoRow(
                                icon: Icons.payments_outlined,
                                text: job.salaryText,
                              ),
                              const SizedBox(height: 6),
                              _OverlayInfoRow(
                                icon: Icons.place_outlined,
                                text: job.locationText ?? 'Location TBD',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onView,
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 17,
                            ),
                            label: const Text('View'),
                            style: AppButtonStyles.secondaryOutline(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onMore,
                          icon: const Icon(Icons.more_horiz_rounded),
                          color: AppColors.coralAccent,
                          style: IconButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ],
                    ),
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

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

class _OverlayInfoRow extends StatelessWidget {
  const _OverlayInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.coralAccent, size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.job});

  final EmployerJob job;

  @override
  Widget build(BuildContext context) {
    final isClosed = job.isClosed;
    final isFilled = job.isFilled;
    return _OverlayBadge(
      label: isClosed ? 'Closed' : job.statusLabel,
      icon: job.isDraft
          ? Icons.edit_note_rounded
          : isFilled
          ? Icons.check_circle_outline_rounded
          : isClosed
          ? Icons.lock_outline_rounded
          : Icons.radio_button_checked_rounded,
      backgroundColor: isClosed
          ? const Color(0xCC2A2D34)
          : isFilled
          ? const Color(0xCC173E34)
          : null,
      iconColor: isClosed
          ? Colors.white70
          : isFilled
          ? Colors.greenAccent
          : null,
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({
    required this.label,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.navyBg.withValues(alpha: 0.72),
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

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (dotIndex) {
        final selected = dotIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 18 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.coralAccent : Colors.white24,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _JobActionsSheet extends StatelessWidget {
  const _JobActionsSheet({
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
    final actions = <_ActionItem>[
      if (job.isDraft) ...[
        _ActionItem(Icons.edit_outlined, 'Edit job', onEdit),
        _ActionItem(Icons.publish_rounded, 'Publish', onPublish),
        _ActionItem(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _ActionItem(
          Icons.delete_outline_rounded,
          'Delete draft',
          onDeleteDraft,
        ),
      ] else if (job.isOpen) ...[
        _ActionItem(Icons.edit_outlined, 'Edit job', onEdit),
        _ActionItem(Icons.groups_outlined, 'View applicants', onApplicants),
        _ActionItem(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _ActionItem(Icons.lock_outline_rounded, 'Close job', onClose),
      ] else if (job.isFilled) ...[
        _ActionItem(Icons.groups_outlined, 'View applicants', onApplicants),
        _ActionItem(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _ActionItem(Icons.refresh_rounded, 'Reopen job', onReopen),
      ] else ...[
        _ActionItem(Icons.copy_rounded, 'Duplicate job', onDuplicate),
        _ActionItem(Icons.refresh_rounded, 'Reopen job', onReopen),
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

class _ActionItem {
  const _ActionItem(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _DashboardStats {
  const _DashboardStats({
    required this.open,
    required this.applicants,
    required this.filled,
    required this.drafts,
  });

  final int open;
  final int applicants;
  final int filled;
  final int drafts;

  factory _DashboardStats.fromJobs(
    List<EmployerJob> jobs,
    Map<String, JobApplicationStats> statsByJob,
  ) {
    return _DashboardStats(
      open: jobs.where((job) => job.isOpen).length,
      applicants: statsByJob.values.fold(
        0,
        (total, stats) => total + stats.total,
      ),
      filled: jobs.where((job) => job.isFilled).length,
      drafts: jobs.where((job) => job.isDraft).length,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPostJob});

  final VoidCallback onPostJob;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.coralAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.work_outline_rounded,
                  color: AppColors.coralAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No jobs posted yet',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Post your first short-term job and start receiving applicants.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: AppSpacing.buttonHeight,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPostJob,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Post your first job',
                    style: AppTextStyles.buttonLabel(),
                  ),
                  style: AppButtonStyles.primary(
                    foregroundColor: AppColors.navyBg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.allJobsCount});

  final int allJobsCount;

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
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            color: AppColors.coralAccent,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'No jobs match this filter',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$allJobsCount jobs exist in total. Try another filter.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.coralAccent),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isIndexError = error.toLowerCase().contains('index');
    return Center(
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
              const Text(
                'Could not load your jobs',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isIndexError
                    ? 'Firestore needs the jobs index: employerId ascending and createdAt descending.'
                    : error,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onRetry,
                style: AppButtonStyles.secondaryOutline(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

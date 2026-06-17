import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_ui.dart';
import '../../auth/screens/welcome_page.dart';
import '../../reports/models/report_item.dart';
import '../../reports/services/report_service.dart';
import '../models/admin_category_item.dart';
import '../models/admin_job_item.dart';
import '../models/admin_review_item.dart';
import '../models/admin_stats.dart';
import '../models/admin_user_item.dart';
import '../services/admin_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminService _adminService = AdminService();
  final ReportService _reportService = ReportService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy - h:mm a');

  late Future<bool> _isAdminFuture;
  String _jobsFilter = 'all';
  String _reportsFilter = 'all';

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid ?? '';
    _isAdminFuture = _adminService.isAdminUser(uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAdminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.navyBg,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          return _AccessDenied(onBack: _goToWelcome);
        }

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            backgroundColor: AppColors.navyBg,
            appBar: AppBar(
              backgroundColor: AppColors.navyBg,
              foregroundColor: AppColors.white,
              title: const Text(
                'Admin Dashboard',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Jobs'),
                  Tab(text: 'Reviews'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Categories'),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () async {
                    await _auth.signOut();
                    if (!mounted) return;
                    _goToWelcome();
                  },
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
            body: TabBarView(
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildJobsTab(),
                _buildReviewsTab(),
                _buildReportsTab(),
                _buildCategoriesTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return StreamBuilder<AdminStats>(
      stream: _adminService.watchStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CenteredInfo(
            icon: Icons.error_outline,
            title: 'Could not load stats',
            subtitle: '${snapshot.error}',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        final cards = [
          _StatData(
            'Total employees',
            stats.totalEmployees,
            Icons.badge_outlined,
          ),
          _StatData(
            'Total employers',
            stats.totalEmployers,
            Icons.storefront_outlined,
          ),
          _StatData('Total users', stats.totalUsers, Icons.groups_2_outlined),
          _StatData('Open jobs', stats.openJobs, Icons.work_outline),
          _StatData(
            'Closed/Filled jobs',
            stats.closedOrFilledJobs,
            Icons.check_circle_outline,
          ),
          _StatData(
            'Total applications',
            stats.totalApplications,
            Icons.assignment_outlined,
          ),
          _StatData(
            'Total reviews',
            stats.totalReviews,
            Icons.reviews_outlined,
          ),
          _StatData('Total reports', stats.totalReports, Icons.flag_outlined),
          _StatData(
            'Pending reports',
            stats.pendingReports,
            Icons.pending_actions_outlined,
          ),
          _StatData('Blocked users', stats.blockedUsers, Icons.block_outlined),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = AppSpacing.horizontal * 2;
            final availableWidth = constraints.maxWidth - horizontalPadding;
            final cardWidth = (availableWidth - 12) / 2;
            final compact = cardWidth < 170;

            return GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.horizontal),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: compact ? 1.1 : 1.22,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(card.icon, color: AppColors.coralAccent),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${card.value}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.title,
                        style: AppTextStyles.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildUsersTab() {
    return StreamBuilder<List<AdminUserItem>>(
      stream: _adminService.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CenteredInfo(
            icon: Icons.error_outline,
            title: 'Could not load users',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!;
        if (users.isEmpty) {
          return const _CenteredInfo(
            icon: Icons.group_off_outlined,
            title: 'No users found',
            subtitle: 'Users from Firestore will appear here.',
          );
        }

        final currentUid = _auth.currentUser?.uid;
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.horizontal),
          itemBuilder: (context, index) {
            final user = users[index];
            final isSelf = user.userId == currentUid;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (user.isBlocked)
                        _pill('Blocked', Colors.red)
                      else
                        _pill('Active', Colors.green),
                      const SizedBox(width: 8),
                      _pill(
                        user.isVerified ? 'Verified' : 'Unverified',
                        user.isVerified ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user.email.isEmpty ? '-' : user.email,
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Role: ${user.role.isEmpty ? 'unknown' : user.role}',
                    style: AppTextStyles.body,
                  ),
                  if (user.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_dateFormat.format(user.createdAt!)}',
                      style: AppTextStyles.label,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _showUserDetails(user),
                        style: AppButtonStyles.secondaryOutline(),
                        child: const Text('View details'),
                      ),
                      OutlinedButton(
                        onPressed: isSelf
                            ? null
                            : () => _runAction(
                                user.isBlocked
                                    ? () =>
                                          _adminService.unblockUser(user.userId)
                                    : () =>
                                          _adminService.blockUser(user.userId),
                              ),
                        style: AppButtonStyles.secondaryOutline(),
                        child: Text(
                          user.isBlocked ? 'Unblock user' : 'Block user',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _runAction(
                          user.isVerified
                              ? () => _adminService.unverifyUser(user.userId)
                              : () => _adminService.verifyUser(user.userId),
                        ),
                        style: AppButtonStyles.secondaryOutline(),
                        child: Text(
                          user.isVerified
                              ? 'Remove verification'
                              : 'Verify user',
                        ),
                      ),
                    ],
                  ),
                  if (isSelf)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'You cannot block your own admin account.',
                        style: AppTextStyles.label.copyWith(
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: users.length,
        );
      },
    );
  }

  Widget _buildJobsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              _jobFilterChip('all', 'All'),
              _jobFilterChip('open', 'Open'),
              _jobFilterChip('closed', 'Closed'),
              _jobFilterChip('filled', 'Filled'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminJobItem>>(
            stream: _adminService.watchJobs(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CenteredInfo(
                  icon: Icons.error_outline,
                  title: 'Could not load jobs',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final jobs = snapshot.data!;
              final filtered = jobs.where((job) {
                if (_jobsFilter == 'all') return true;
                return job.status == _jobsFilter;
              }).toList();

              if (filtered.isEmpty) {
                return const _CenteredInfo(
                  icon: Icons.work_off_outlined,
                  title: 'No jobs found',
                  subtitle: 'Try another filter.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final job = filtered[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.title,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _pill(
                              job.status,
                              job.status == 'open'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Category: ${job.category}',
                          style: AppTextStyles.body,
                        ),
                        Text(
                          'Employer: ${job.employerName}',
                          style: AppTextStyles.body,
                        ),
                        Text(
                          'Location: ${job.location}',
                          style: AppTextStyles.body,
                        ),
                        Text('Wage: ${job.wage}', style: AppTextStyles.body),
                        if (job.createdAt != null)
                          Text(
                            'Created: ${_dateFormat.format(job.createdAt!)}',
                            style: AppTextStyles.label,
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showJobDetails(job),
                              style: AppButtonStyles.secondaryOutline(),
                              child: const Text('View job details'),
                            ),
                            if (job.status != 'closed')
                              OutlinedButton(
                                onPressed: () => _confirmCloseJob(job),
                                style: AppButtonStyles.secondaryOutline(),
                                child: const Text('Close job'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: filtered.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTab() {
    return StreamBuilder<List<AdminReviewItem>>(
      stream: _adminService.watchReviews(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CenteredInfo(
            icon: Icons.error_outline,
            title: 'Could not load reviews',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return const _CenteredInfo(
            icon: Icons.rate_review_outlined,
            title: 'No reviews found',
            subtitle: 'Reviews will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '${review.rating}/5',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _confirmDeleteReview(review),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (review.comment.isNotEmpty)
                    Text(review.comment, style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Text(
                    '${review.reviewerName} (${review.reviewerRole}) -> ${review.targetUserName} (${review.targetRole})',
                    style: AppTextStyles.label,
                  ),
                  if (review.createdAt != null)
                    Text(
                      'Created: ${_dateFormat.format(review.createdAt!)}',
                      style: AppTextStyles.label,
                    ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: reviews.length,
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              _reportFilterChip('all', 'All'),
              _reportFilterChip('pending', 'Pending'),
              _reportFilterChip('reviewed', 'Reviewed'),
              _reportFilterChip('resolved', 'Resolved'),
              _reportFilterChip('dismissed', 'Dismissed'),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReportItem>>(
            stream: _reportService.watchReportsForAdmin(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CenteredInfo(
                  icon: Icons.error_outline,
                  title: 'Could not load reports',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final reports = snapshot.data!;
              final filtered = reports.where((report) {
                if (_reportsFilter == 'all') return true;
                return report.status == _reportsFilter;
              }).toList();

              if (filtered.isEmpty) {
                return const _CenteredInfo(
                  icon: Icons.flag_outlined,
                  title: 'No reports found',
                  subtitle: 'Try another filter.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final report = filtered[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.reason,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _pill(
                              report.status,
                              _reportStatusColor(report.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Type: ${report.reportType}',
                          style: AppTextStyles.body,
                        ),
                        Text(
                          report.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'By: ${report.reportedByName} (${report.reportedByRole})',
                          style: AppTextStyles.label,
                        ),
                        Text(
                          'Against: ${report.reportedUserName} (${report.reportedUserRole})',
                          style: AppTextStyles.label,
                        ),
                        if (report.jobTitle != null)
                          Text(
                            'Job: ${report.jobTitle}',
                            style: AppTextStyles.label,
                          ),
                        if (report.createdAt != null)
                          Text(
                            'Created: ${_dateFormat.format(report.createdAt!)}',
                            style: AppTextStyles.label,
                          ),
                        if (report.adminNote != null &&
                            report.adminNote!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Admin note: ${report.adminNote}',
                            style: AppTextStyles.label,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _showReportDetails(report),
                              style: AppButtonStyles.secondaryOutline(),
                              child: const Text('View details'),
                            ),
                            OutlinedButton(
                              onPressed: () => _runAction(
                                () => _reportService.updateReportStatus(
                                  report.reportId,
                                  'reviewed',
                                ),
                              ),
                              style: AppButtonStyles.secondaryOutline(),
                              child: const Text('Mark reviewed'),
                            ),
                            OutlinedButton(
                              onPressed: () => _runAction(
                                () => _reportService.updateReportStatus(
                                  report.reportId,
                                  'resolved',
                                ),
                              ),
                              style: AppButtonStyles.secondaryOutline(),
                              child: const Text('Mark resolved'),
                            ),
                            OutlinedButton(
                              onPressed: () => _runAction(
                                () => _reportService.updateReportStatus(
                                  report.reportId,
                                  'dismissed',
                                ),
                              ),
                              style: AppButtonStyles.secondaryOutline(),
                              child: const Text('Dismiss'),
                            ),
                            OutlinedButton(
                              onPressed: () => _showAddAdminNoteDialog(report),
                              style: AppButtonStyles.secondaryOutline(),
                              child: const Text('Add admin note'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: filtered.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              style: AppButtonStyles.primary(),
              icon: const Icon(Icons.add),
              label: Text(
                'Add category',
                style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminCategoryItem>>(
            stream: _adminService.watchCategories(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CenteredInfo(
                  icon: Icons.error_outline,
                  title: 'Could not load categories',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final categories = snapshot.data!;
              if (categories.isEmpty) {
                return const _CenteredInfo(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  subtitle: 'Create categories for future job posting flows.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final item = categories[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${item.categoryId}',
                                style: AppTextStyles.label,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _pill(
                          item.isActive ? 'Active' : 'Disabled',
                          item.isActive ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _runAction(
                            () => _adminService.setCategoryActive(
                              categoryId: item.categoryId,
                              isActive: !item.isActive,
                            ),
                          ),
                          style: AppButtonStyles.secondaryOutline(),
                          child: Text(item.isActive ? 'Disable' : 'Enable'),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: categories.length,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _jobFilterChip(String value, String label) {
    final selected = _jobsFilter == value;
    return ChoiceChip(
      selectedColor: AppColors.coralAccent,
      labelStyle: TextStyle(
        color: selected ? AppColors.navyBg : AppColors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surface,
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _jobsFilter = value),
    );
  }

  Widget _reportFilterChip(String value, String label) {
    final selected = _reportsFilter == value;
    return ChoiceChip(
      selectedColor: AppColors.coralAccent,
      labelStyle: TextStyle(
        color: selected ? AppColors.navyBg : AppColors.white,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.surface,
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _reportsFilter = value),
    );
  }

  Color _reportStatusColor(String status) {
    switch (status) {
      case 'reviewed':
        return Colors.amber;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      _showSnack('Updated successfully');
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _confirmDeleteReview(AdminReviewItem review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete review?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _runAction(() => _adminService.deleteReview(review.reviewId));
  }

  Future<void> _confirmCloseJob(AdminJobItem job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this job?'),
        content: const Text('The job status will be set to closed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close job'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _runAction(() => _adminService.closeJob(job.jobId));
  }

  void _showUserDetails(AdminUserItem user) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.name}'),
            Text('Email: ${user.email.isEmpty ? '-' : user.email}'),
            Text('Role: ${user.role.isEmpty ? 'unknown' : user.role}'),
            Text('Blocked: ${user.isBlocked ? 'Yes' : 'No'}'),
            Text('Verified: ${user.isVerified ? 'Yes' : 'No'}'),
            Text('User ID: ${user.userId}'),
            if (user.createdAt != null)
              Text('Created: ${_dateFormat.format(user.createdAt!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showJobDetails(AdminJobItem job) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Job details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${job.title}'),
            Text('Category: ${job.category}'),
            Text('Employer: ${job.employerName}'),
            Text('Location: ${job.location}'),
            Text('Wage: ${job.wage}'),
            Text('Status: ${job.status}'),
            Text('Job ID: ${job.jobId}'),
            if (job.createdAt != null)
              Text('Created: ${_dateFormat.format(job.createdAt!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(ReportItem report) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason: ${report.reason}'),
              Text('Type: ${report.reportType}'),
              Text('Status: ${report.status}'),
              Text('By: ${report.reportedByName} (${report.reportedByRole})'),
              Text(
                'Against: ${report.reportedUserName} (${report.reportedUserRole})',
              ),
              if (report.jobId != null) Text('Job ID: ${report.jobId}'),
              if (report.jobTitle != null) Text('Job: ${report.jobTitle}'),
              const SizedBox(height: 8),
              Text('Description: ${report.description}'),
              if (report.adminNote != null && report.adminNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Admin note: ${report.adminNote}'),
              ],
              if (report.createdAt != null) ...[
                const SizedBox(height: 8),
                Text('Created: ${_dateFormat.format(report.createdAt!)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAdminNoteDialog(ReportItem report) async {
    final controller = TextEditingController(text: report.adminNote ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add admin note'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (save != true) return;
    await _runAction(
      () => _reportService.addAdminNote(report.reportId, controller.text),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added != true) return;
    await _runAction(() => _adminService.addCategory(controller.text));
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _goToWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }
}

class _CenteredInfo extends StatelessWidget {
  const _CenteredInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.coralAccent),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.label,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppColors.coralAccent,
              ),
              const SizedBox(height: 14),
              const Text(
                'Access denied',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only admin users can open this page.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onBack,
                style: AppButtonStyles.secondaryOutline(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatData {
  const _StatData(this.title, this.value, this.icon);

  final String title;
  final int value;
  final IconData icon;
}

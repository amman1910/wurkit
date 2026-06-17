import 'package:flutter/material.dart';
import '../../../core/theme/app_ui.dart';
import '../services/admin_service.dart';
import '../widgets/stat_card.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key, required this.adminService});

  final AdminService adminService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: adminService.watchStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final stats = snapshot.data;
        if (stats == null) {
          return const Center(
            child: Text(
              'No data',
              style: TextStyle(color: AppColors.lightText),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.horizontal),
          children: [
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                StatCard(
                  title: 'Total Employees',
                  value: stats.totalEmployees,
                  icon: Icons.person,
                ),
                StatCard(
                  title: 'Total Employers',
                  value: stats.totalEmployers,
                  icon: Icons.business,
                ),
                StatCard(
                  title: 'Total Users',
                  value: stats.totalUsers,
                  icon: Icons.group,
                ),
                StatCard(
                  title: 'Open Jobs',
                  value: stats.openJobs,
                  icon: Icons.work_outline,
                ),
                StatCard(
                  title: 'Closed/Filled Jobs',
                  value: stats.closedOrFilledJobs,
                  icon: Icons.check_circle,
                ),
                StatCard(
                  title: 'Applications',
                  value: stats.totalApplications,
                  icon: Icons.assignment,
                ),
                StatCard(
                  title: 'Reviews',
                  value: stats.totalReviews,
                  icon: Icons.star,
                ),
                StatCard(
                  title: 'Blocked Users',
                  value: stats.blockedUsers,
                  icon: Icons.block,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../services/job_service.dart';
import '../widgets/job_card.dart';

class EmployeeJobsPage extends StatefulWidget {
  const EmployeeJobsPage({super.key});

  @override
  State<EmployeeJobsPage> createState() => _EmployeeJobsPageState();
}

class _EmployeeJobsPageState extends State<EmployeeJobsPage> {
  final JobService _jobService = JobService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jobs',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse available short-term jobs near you.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _jobService.getOpenJobs(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _JobErrorView(error: snapshot.error.toString());
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _JobLoadingView();
                    }

                    final jobs = snapshot.data?.docs ?? [];
                    if (jobs.isEmpty) {
                      return const _JobEmptyView();
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: jobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final job = jobs[index].data();
                        return JobCard(job: job);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobLoadingView extends StatelessWidget {
  const _JobLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
          ),
        ),
      ),
    );
  }
}

class _JobEmptyView extends StatelessWidget {
  const _JobEmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              'No jobs available',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'There are no open jobs available at the moment.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobErrorView extends StatelessWidget {
  const _JobErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 18),
            const Text(
              'Failed to load jobs',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(error, style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

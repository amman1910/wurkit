import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../services/job_service.dart';
import 'post_job_screen.dart';

class EmployerJobsPage extends StatefulWidget {
  const EmployerJobsPage({super.key});

  @override
  State<EmployerJobsPage> createState() => _EmployerJobsPageState();
}

class _EmployerJobsPageState extends State<EmployerJobsPage> {
  final JobService _jobService = JobService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: SingleChildScrollView(
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
                'Manage the jobs your business posts.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PostJobScreen(),
                      ),
                    );
                  },
                  style: AppButtonStyles.primary(
                    foregroundColor: AppColors.navyBg,
                  ),
                  child: Text(
                    'Create job post',
                    style: AppTextStyles.buttonLabel(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StreamBuilder<QuerySnapshot>(
                stream: _jobService.getOpenJobs(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _ErrorCard(error: snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingCard();
                  }

                  final jobs = snapshot.data?.docs ?? [];

                  if (jobs.isEmpty) {
                    return const _EmptyCard();
                  }

                  return Column(
                    children: jobs.map((doc) {
                      final job = doc.data() as Map<String, dynamic>;
                      return _JobCard(jobId: doc.id, job: job);
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.jobId, required this.job});

  final String jobId;
  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final title = job['title'] as String? ?? '';
    final description = job['description'] as String? ?? '';
    final location = job['location'] as String? ?? '';
    final date = job['date'] as String? ?? '';
    final salary = job['salary'] as num? ?? 0;
    final salaryType = job['salaryType'] as String? ?? '';
    final requiredSkill = job['requiredSkill'] as String? ?? '';
    final shiftStart = job['shiftStart'] as String? ?? '';
    final shiftEnd = job['shiftEnd'] as String? ?? '';
    final urgent = job['urgent'] as bool? ?? false;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (urgent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.coralAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(
                      color: AppColors.coralAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextStyles.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: AppColors.coralAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(location, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: AppColors.coralAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(date, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.attach_money,
                color: AppColors.coralAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${salary.toStringAsFixed(salary is int ? 0 : 1)} $salaryType',
                style: AppTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.work, color: AppColors.coralAccent, size: 16),
              const SizedBox(width: 4),
              Text(requiredSkill, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: AppColors.coralAccent,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text('$shiftStart - $shiftEnd', style: AppTextStyles.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
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
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.coralAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: AppColors.coralAccent,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No jobs available yet',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Create your first job post to get started.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(error, style: AppTextStyles.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

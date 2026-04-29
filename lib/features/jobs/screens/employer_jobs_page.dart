import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class EmployerJobsPage extends StatelessWidget {
  const EmployerJobsPage({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Job posting coming soon')));
  }

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
                  onPressed: () => _showComingSoon(context),
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
              const _EmployerJobsPlaceholderCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployerJobsPlaceholderCard extends StatelessWidget {
  const _EmployerJobsPlaceholderCard();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _EmployerJobsIcon(),
          SizedBox(height: 18),
          Text(
            'Your job posts will appear here',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'This space will help you manage every role your business opens.',
            style: AppTextStyles.body,
          ),
          SizedBox(height: 20),
          _FutureHint(label: 'Active jobs'),
          _FutureHint(label: 'Urgent jobs'),
          _FutureHint(label: 'Edit job posts'),
          _FutureHint(label: 'Close filled jobs'),
        ],
      ),
    );
  }
}

class _EmployerJobsIcon extends StatelessWidget {
  const _EmployerJobsIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _FutureHint extends StatelessWidget {
  const _FutureHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.coralAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.label),
        ],
      ),
    );
  }
}

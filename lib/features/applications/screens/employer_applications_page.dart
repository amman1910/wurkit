import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class EmployerApplicationsPage extends StatelessWidget {
  const EmployerApplicationsPage({super.key});

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
            children: const [
              Text(
                'Applications',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Review workers who applied to your jobs.',
                style: AppTextStyles.body,
              ),
              SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _StatusChip(label: 'Pending'),
                  _StatusChip(label: 'Approved'),
                  _StatusChip(label: 'Rejected'),
                ],
              ),
              SizedBox(height: 24),
              _EmployerApplicationsPlaceholderCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.lightText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmployerApplicationsPlaceholderCard extends StatelessWidget {
  const _EmployerApplicationsPlaceholderCard();

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
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.coralAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppColors.coralAccent,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Worker applications will appear here',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'As candidates apply, you will be able to review, shortlist, and move them forward here.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

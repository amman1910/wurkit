import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class EmployeeJobsPage extends StatelessWidget {
  const EmployeeJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _EmployeePlaceholderScaffold(
      title: 'Jobs',
      subtitle: 'Browse available short-term jobs near you.',
      message: 'Job feed coming soon',
      icon: Icons.work_outline_rounded,
      bullets: [
        'Search jobs',
        'Filter by distance',
        'Apply with one tap',
        'View job details',
      ],
    );
  }
}

class _EmployeePlaceholderScaffold extends StatelessWidget {
  const _EmployeePlaceholderScaffold({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.icon,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final String message;
  final IconData icon;
  final List<String> bullets;

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
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTextStyles.body),
              const SizedBox(height: 24),
              Container(
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
                      child: Icon(icon, color: AppColors.coralAccent),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'We\'re setting up the employee experience so this space can become your main work dashboard.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 20),
                    ...bullets.map(
                      (bullet) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.coralAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(bullet, style: AppTextStyles.label),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

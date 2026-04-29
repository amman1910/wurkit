import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class EmployeeProfilePage extends StatelessWidget {
  const EmployeeProfilePage({super.key});

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
              _ProfileHeader(),
              SizedBox(height: 24),
              _ProfileSectionCard(
                icon: Icons.badge_outlined,
                title: 'Personal Info',
                rows: [
                  _ProfileRow(label: 'Phone', value: 'Add your phone number later'),
                  _ProfileRow(label: 'Age', value: 'Add your age later'),
                ],
              ),
              SizedBox(height: 16),
              _ProfileSectionCard(
                icon: Icons.tune_rounded,
                title: 'Work Preferences',
                rows: [
                  _ProfileRow(label: 'Categories', value: 'Choose preferred job categories'),
                  _ProfileRow(label: 'Skills', value: 'Add your top work skills'),
                  _ProfileRow(label: 'Salary expectation', value: 'Set your expected hourly rate'),
                ],
              ),
              SizedBox(height: 16),
              _ProfileSectionCard(
                icon: Icons.calendar_month_outlined,
                title: 'Availability',
                rows: [
                  _ProfileRow(label: 'Available days', value: 'Select days you can work'),
                  _ProfileRow(label: 'Shift types', value: 'Choose morning, evening, or flexible'),
                  _ProfileRow(label: 'Location/radius', value: 'Set where you want to work'),
                ],
              ),
              SizedBox(height: 16),
              _ProfileSectionCard(
                icon: Icons.work_history_outlined,
                title: 'Experience',
                rows: [
                  _ProfileRow(label: 'Bio', value: 'Introduce yourself in a few lines'),
                  _ProfileRow(label: 'Past work', value: 'List previous jobs or experience'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.coralAccent.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.coralAccent,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your profile',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.navyBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'Worker profile',
                    style: TextStyle(
                      color: AppColors.coralAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<Widget> rows;

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
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.coralAccent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.coralAccent),
              ),
              const SizedBox(width: 12),
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
              const Text(
                'Edit later',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...rows,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

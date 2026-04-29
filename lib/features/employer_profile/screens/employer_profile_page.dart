import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class EmployerProfilePage extends StatelessWidget {
  const EmployerProfilePage({super.key});

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
              _EmployerProfileHeader(),
              SizedBox(height: 24),
              _EmployerSectionCard(
                icon: Icons.apartment_rounded,
                title: 'Business Info',
                rows: [
                  _EmployerProfileRow(
                    label: 'Business name',
                    value: 'Add your business name later',
                  ),
                  _EmployerProfileRow(
                    label: 'Business type',
                    value: 'Choose the business category later',
                  ),
                  _EmployerProfileRow(
                    label: 'Phone/email',
                    value: 'Add your business contact details later',
                  ),
                ],
              ),
              SizedBox(height: 16),
              _EmployerSectionCard(
                icon: Icons.location_on_outlined,
                title: 'Location',
                rows: [
                  _EmployerProfileRow(
                    label: 'Address',
                    value: 'Add your street address later',
                  ),
                  _EmployerProfileRow(
                    label: 'City',
                    value: 'Add your city later',
                  ),
                ],
              ),
              SizedBox(height: 16),
              _EmployerSectionCard(
                icon: Icons.tune_rounded,
                title: 'Hiring Preferences',
                rows: [
                  _EmployerProfileRow(
                    label: 'Worker categories',
                    value: 'Choose the worker types you hire most',
                  ),
                  _EmployerProfileRow(
                    label: 'Shift types',
                    value: 'Set day, evening, or flexible shifts',
                  ),
                  _EmployerProfileRow(
                    label: 'Hourly rate range',
                    value: 'Add your typical pay range later',
                  ),
                ],
              ),
              SizedBox(height: 16),
              _EmployerSectionCard(
                icon: Icons.description_outlined,
                title: 'Public Business Note',
                rows: [
                  _EmployerProfileRow(
                    label: 'Business note',
                    value: 'Add a short public note about your business later',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployerProfileHeader extends StatelessWidget {
  const _EmployerProfileHeader();

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
              Icons.storefront_rounded,
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
                  'Business profile',
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
                    'Employer account',
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

class _EmployerSectionCard extends StatelessWidget {
  const _EmployerSectionCard({
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

class _EmployerProfileRow extends StatelessWidget {
  const _EmployerProfileRow({
    required this.label,
    required this.value,
  });

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

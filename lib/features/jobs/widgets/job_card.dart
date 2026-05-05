import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job});

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
    final salaryValue = salary.toDouble();
    final salaryLabel = salaryValue % 1 == 0
        ? salaryValue.toStringAsFixed(0)
        : salaryValue.toStringAsFixed(1);

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
              Text('$salaryLabel $salaryType', style: AppTextStyles.label),
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

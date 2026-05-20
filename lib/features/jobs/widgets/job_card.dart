import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job});

  final Map<String, dynamic> job;

  @override
  Widget build(BuildContext context) {
    final title = job['title'] as String? ?? '';
    final description = job['description'] as String? ?? '';
    final location = _readLocation(job['location']);
    final date = _readDateText(job);
    final skills = _readSkills(job);
    final shiftText = _readShiftText(job);
    final urgent = job['urgent'] as bool? ?? false;
    final salaryLabel = _readSalaryText(job);
    final status = job['status'] as String?;
    final category = job['jobCategory'] as String?;

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
                    color: AppColors.coralAccent.withValues(alpha: 0.2),
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
              if (status == 'draft')
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'DRAFT',
                    style: TextStyle(
                      color: AppColors.lightText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
              Text(salaryLabel, style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.work, color: AppColors.coralAccent, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  skills.isNotEmpty ? skills : (category ?? 'General help'),
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
              Text(shiftText, style: AppTextStyles.label),
            ],
          ),
        ],
      ),
    );
  }
}

String _readSalaryText(Map<String, dynamic> job) {
  final amount = _readNum(job['salaryAmount']) ?? _readNum(job['salary']);
  final salaryType = job['salaryType'] as String? ?? '';
  if (amount == null) return salaryType.isEmpty ? 'Pay not listed' : salaryType;

  final amountText = amount % 1 == 0
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(1);
  final suffix = salaryType == 'Hourly'
      ? ' / hour'
      : salaryType == 'Daily'
      ? ' / day'
      : salaryType.isEmpty
      ? ''
      : ' $salaryType';
  return '₪$amountText$suffix';
}

String _readSkills(Map<String, dynamic> job) {
  final skills = job['requiredSkills'];
  if (skills is List) {
    return skills
        .whereType<String>()
        .where((skill) => skill.isNotEmpty)
        .join(', ');
  }
  return job['requiredSkill'] as String? ?? '';
}

String _readShiftText(Map<String, dynamic> job) {
  final shifts = job['shifts'];
  if (shifts is List && shifts.isNotEmpty) {
    final labels = shifts
        .whereType<Map>()
        .map((shift) {
          final start = shift['startTime'] as String?;
          final end = shift['endTime'] as String?;
          if (start == null && end == null) return null;
          if (start == null) return end;
          if (end == null) return start;
          return '$start - $end';
        })
        .whereType<String>()
        .toList();
    if (labels.isNotEmpty) return labels.join(', ');
  }

  final shiftStart = job['shiftStart'] as String?;
  final shiftEnd = job['shiftEnd'] as String?;
  if (shiftStart == null && shiftEnd == null) return 'Time TBD';
  if (shiftStart == null) return shiftEnd!;
  if (shiftEnd == null) return shiftStart;
  return '$shiftStart - $shiftEnd';
}

String _readLocation(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is Map) {
    if (value['type'] == 'remote') return 'Remote';
    final address = value['address'] as String?;
    final city = value['city'] as String?;
    return [
      address,
      city,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
  }
  return 'Location TBD';
}

String _readDateText(Map<String, dynamic> job) {
  if (job['startAsSoonAsPossible'] == true) return 'ASAP';
  final start = job['startDate'];
  final end = job['endDate'];
  if (start is Timestamp && end is Timestamp) {
    return '${_shortDate(start.toDate())} - ${_shortDate(end.toDate())}';
  }
  if (start is Timestamp) return _shortDate(start.toDate());
  return job['date'] as String? ?? 'Flexible';
}

String _shortDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

double? _readNum(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

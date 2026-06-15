import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../models/employee_application_item.dart';
import 'application_status_badge.dart';

class EmployeeApplicationCard extends StatelessWidget {
  const EmployeeApplicationCard({
    super.key,
    required this.item,
    required this.onViewJob,
    required this.onCancel,
    required this.onMessage,
    required this.onResend,
    this.onReview,
  });

  final EmployeeApplicationItem item;
  final VoidCallback? onViewJob;
  final VoidCallback? onCancel;
  final VoidCallback? onMessage;
  final VoidCallback? onResend;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final statusStyle = ApplicationStatusStyle.fromStatus(item.status);
    final muted = item.isCancelled || !item.jobExists;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewJob,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: muted ? 0.58 : 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.isMatch
                  ? statusStyle.color.withValues(alpha: 0.24)
                  : AppColors.border.withValues(alpha: 0.88),
            ),
            boxShadow: item.isMatch
                ? [
                    BoxShadow(
                      color: statusStyle.color.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.isMatch) ...[
                _MatchStrip(color: statusStyle.color),
                const SizedBox(height: 9),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ApplicationThumb(
                    imageUrl: item.jobImageUrl ?? item.businessLogoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.jobTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted
                                      ? Colors.white70
                                      : const Color(0xFFF3F4F6),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ApplicationStatusBadge(status: item.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.coralAccent,
                              size: 15,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _MetaWrap(item: item),
                        const SizedBox(height: 8),
                        Text(
                          'Applied ${formatApplicationDate(item.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _ActionRow(
                item: item,
                onViewJob: onViewJob,
                onCancel: onCancel,
                onMessage: onMessage,
                onResend: onResend,
                onReview: onReview,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchStrip extends StatelessWidget {
  const _MatchStrip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.celebration_rounded, color: color, size: 17),
        const SizedBox(width: 7),
        Text(
          "It's a match!",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _ApplicationThumb extends StatelessWidget {
  const _ApplicationThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 98,
        height: 112,
        child: imageUrl == null
            ? const _ImageFallback()
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ImageFallback(),
              ),
      ),
    );
  }
}

class _MetaWrap extends StatelessWidget {
  const _MetaWrap({required this.item});

  final EmployeeApplicationItem item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _MetaItem(icon: Icons.payments_outlined, text: item.salaryText),
        _MetaItem(icon: Icons.calendar_month_rounded, text: item.dateText),
        _MetaItem(icon: Icons.schedule_rounded, text: item.shiftText),
        _MetaItem(icon: Icons.location_on_outlined, text: item.locationText),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 13),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.item,
    required this.onViewJob,
    required this.onCancel,
    required this.onMessage,
    required this.onResend,
    this.onReview,
  });

  final EmployeeApplicationItem item;
  final VoidCallback? onViewJob;
  final VoidCallback? onCancel;
  final VoidCallback? onMessage;
  final VoidCallback? onResend;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniActionButton(
            icon: Icons.arrow_forward_rounded,
            label: item.jobExists ? 'View job' : 'Unavailable',
            onTap: onViewJob,
          ),
        ),
        if (item.isPending) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _MiniActionButton(
              icon: Icons.delete_outline_rounded,
              label: 'Cancel',
              color: const Color(0xFFFF7A68),
              onTap: onCancel,
            ),
          ),
        ],
        if (item.isApproved) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _MiniActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              color: const Color(0xFF6FD37A),
              onTap: onMessage,
            ),
          ),
          if (onReview != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _MiniActionButton(
                icon: Icons.star_outline_rounded,
                label: 'Write Review',
                color: AppColors.coralAccent,
                onTap: onReview,
              ),
            ),
          ],
        ],
        if (item.isCancelled && item.jobExists && onResend != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _MiniActionButton(
              icon: Icons.refresh_rounded,
              label: 'Apply again',
              color: AppColors.coralAccent,
              onTap: onResend,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.coralAccent,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: Colors.white38,
          side: BorderSide(color: color.withValues(alpha: 0.76)),
          backgroundColor: color.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          minimumSize: const Size(0, 38),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF263D67), AppColors.surface, AppColors.navyBg],
        ),
      ),
      child: const Icon(
        Icons.work_outline_rounded,
        color: AppColors.coralAccent,
      ),
    );
  }
}

String formatApplicationDate(DateTime? date) {
  if (date == null) {
    return 'recently';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'on ${months[date.month - 1]} ${date.day}, ${date.year}';
}

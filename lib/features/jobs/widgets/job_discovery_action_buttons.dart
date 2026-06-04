import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class JobDiscoveryActionButtons extends StatelessWidget {
  const JobDiscoveryActionButtons({
    super.key,
    required this.isBusy,
    required this.onNotInterested,
    required this.onSkip,
    required this.onApply,
    this.height = 52,
  });

  final bool isBusy;
  final VoidCallback onNotInterested;
  final VoidCallback onSkip;
  final VoidCallback onApply;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DiscoveryActionButton(
            icon: Icons.close_rounded,
            label: 'Not Interested',
            color: const Color(0xFFFF7A68),
            onTap: isBusy ? null : onNotInterested,
            height: height,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _DiscoveryActionButton(
            icon: Icons.keyboard_double_arrow_right_rounded,
            label: 'Skip',
            color: Colors.white70,
            onTap: isBusy ? null : onSkip,
            height: height,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _DiscoveryActionButton(
            icon: Icons.check_rounded,
            label: 'Apply',
            color: const Color(0xFF6FD37A),
            onTap: isBusy ? null : onApply,
            height: height,
          ),
        ),
      ],
    );
  }
}

class _DiscoveryActionButton extends StatelessWidget {
  const _DiscoveryActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.height,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isApply = label == 'Apply';
    final isSkip = label == 'Skip';
    final foreground = isSkip ? AppColors.lightText : color;
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isApply
                ? color.withValues(alpha: 0.13)
                : AppColors.surface.withValues(alpha: isSkip ? 0.62 : 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSkip
                  ? AppColors.border
                  : color.withValues(alpha: isApply ? 0.9 : 0.78),
              width: 1.2,
            ),
            boxShadow: isApply
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

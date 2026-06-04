import 'package:flutter/material.dart';

class ApplicationStatusBadge extends StatelessWidget {
  const ApplicationStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = ApplicationStatusStyle.fromStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, color: style.color, size: 15),
          const SizedBox(width: 6),
          Text(
            style.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class ApplicationStatusStyle {
  const ApplicationStatusStyle({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  static const pending = ApplicationStatusStyle(
    label: 'Pending',
    color: Color(0xFFFFC857),
    icon: Icons.schedule_rounded,
  );

  static const approved = ApplicationStatusStyle(
    label: 'Match',
    color: Color(0xFF6FD37A),
    icon: Icons.check_circle_outline_rounded,
  );

  static const rejected = ApplicationStatusStyle(
    label: 'Rejected',
    color: Color(0xFFFF5B5B),
    icon: Icons.cancel_outlined,
  );

  static const cancelled = ApplicationStatusStyle(
    label: 'Cancelled',
    color: Color(0xFF9AA4B5),
    icon: Icons.remove_circle_outline_rounded,
  );

  static ApplicationStatusStyle fromStatus(String status) {
    return switch (status) {
      'approved' => approved,
      'rejected' => rejected,
      'cancelled' => cancelled,
      _ => pending,
    };
  }

  static String filterLabel(String status) {
    return switch (status) {
      'approved' => 'Matches',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      'pending' => 'Pending',
      _ => 'All',
    };
  }
}

class TinyStatusDot extends StatelessWidget {
  const TinyStatusDot({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = ApplicationStatusStyle.fromStatus(status).color;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

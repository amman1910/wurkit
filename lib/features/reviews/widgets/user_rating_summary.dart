import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class UserRatingSummary extends StatelessWidget {
  const UserRatingSummary({
    super.key,
    required this.userId,
    this.compact = false,
  });

  final String userId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final service = ReviewService();

    return StreamBuilder<List<Review>>(
      stream: service.getReviewsForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _SummaryShell(
            compact: compact,
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.coralAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Loading reviews...', style: AppTextStyles.body),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _SummaryShell(
            compact: compact,
            child: Text(
              'Could not load reviews',
              style: AppTextStyles.body.copyWith(color: Colors.red.shade200),
            ),
          );
        }

        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return _SummaryShell(
            compact: compact,
            child: Text(
              'No reviews yet',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final average =
            reviews.fold<double>(0, (sum, review) => sum + review.rating) /
            reviews.length;
        final ratingText = average.toStringAsFixed(1);
        final reviewCount = reviews.length;

        return _SummaryShell(
          compact: compact,
          child: Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.coralAccent),
              const SizedBox(width: 8),
              Text(
                '$ratingText ($reviewCount review${reviewCount == 1 ? '' : 's'})',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryShell extends StatelessWidget {
  const _SummaryShell({required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 11 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../screens/user_reviews_list.dart';
import 'user_rating_summary.dart';

class PublicProfileReviewsSection extends StatelessWidget {
  const PublicProfileReviewsSection({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ratings & Reviews',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          UserRatingSummary(userId: trimmedUserId),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReviewsList(userId: trimmedUserId),
                  ),
                );
              },
              style: AppButtonStyles.secondaryOutline(),
              child: Text(
                'View reviews',
                style: AppTextStyles.buttonLabel(color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
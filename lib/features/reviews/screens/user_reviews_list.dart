import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_ui.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class UserReviewsList extends StatelessWidget {
  const UserReviewsList({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final service = ReviewService();
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBg,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Reviews'),
      ),
      body: StreamBuilder<List<Review>>(
        stream: service.getReviewsForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.coralAccent),
            );
          }

          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'Could not load reviews',
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
            );
          }

          final reviews = snapshot.data ?? const [];
          if (reviews.isEmpty) {
            return const _StateMessage(
              icon: Icons.star_outline_rounded,
              title: 'No reviews yet',
              message: 'Reviews will appear here once people rate this user.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _ReviewCard(review: review);
            },
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final formattedDate = review.createdAt == null
        ? 'Just now'
        : DateFormat('MMM d, y').format(review.createdAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  final filled = index < review.rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.coralAccent,
                    size: 18,
                  );
                }),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: AppTextStyles.label.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment.isEmpty ? 'No comment provided.' : review.comment,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reviewed by ${review.reviewerName}',
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.coralAccent, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

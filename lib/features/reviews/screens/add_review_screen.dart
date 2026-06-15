import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../services/review_service.dart';

class AddReviewScreen extends StatefulWidget {
  const AddReviewScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetRole,
    required this.reviewerRole,
  });

  final String jobId;
  final String jobTitle;
  final String targetUserId;
  final String targetUserName;
  final String targetRole;
  final String reviewerRole;

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _commentController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  int? _rating;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Please sign in again.');
      return;
    }

    if (_rating == null) {
      _showSnackBar('Please select a rating.');
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _reviewService.addReview(
        jobId: widget.jobId,
        reviewerId: currentUser.uid,
        reviewerRole: widget.reviewerRole,
        targetUserId: widget.targetUserId,
        targetUserName: widget.targetUserName,
        targetRole: widget.targetRole,
        rating: _rating!,
        comment: _commentController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBg,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: const Text('Write Review'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCard(
                  title: widget.jobTitle,
                  subtitle: 'Reviewing ${widget.targetUserName}',
                ),
                const SizedBox(height: 18),
                const Text(
                  'How was the experience?',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap a star rating and add a short note.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                _StarRatingPicker(
                  rating: _rating,
                  onChanged: (value) => setState(() => _rating = value),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _commentController,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.input,
                  maxLength: 500,
                  decoration: AppInputDecorations.authField(
                    label: 'Comment',
                    hint: 'Add a short review...',
                  ).copyWith(
                    alignLabelWithHint: true,
                    counterStyle: AppTextStyles.label,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return null;
                    }
                    if (text.length < 3) {
                      return 'Comment must be at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitReview,
                    style: AppButtonStyles.primary(
                      foregroundColor: AppColors.navyBg,
                      disabledBackgroundColor: Colors.grey.shade600,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.navyBg,
                            ),
                          )
                        : Text(
                            'Submit',
                            style: AppTextStyles.buttonLabel(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job',
            style: TextStyle(
              color: AppColors.coralAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _StarRatingPicker extends StatelessWidget {
  const _StarRatingPicker({required this.rating, required this.onChanged});

  final int? rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        final selected = rating != null && value <= rating!;
        return Padding(
          padding: EdgeInsets.only(right: index == 4 ? 0 : 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(value),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.coralAccent.withValues(alpha: 0.18)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppColors.coralAccent
                      : AppColors.border.withValues(alpha: 0.9),
                ),
              ),
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                color: selected ? AppColors.coralAccent : AppColors.lightText,
                size: 24,
              ),
            ),
          ),
        );
      }),
    );
  }
}
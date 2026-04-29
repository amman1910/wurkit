import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({
    super.key,
    required this.role,
  });

  final String role;

  bool get _isEmployer => role == 'employer';

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
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isEmployer
                    ? 'Chat with workers after a match is created.'
                    : 'Chat with employers after a match is created.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              _MessagePlaceholderCard(isEmployer: _isEmployer),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePlaceholderCard extends StatelessWidget {
  const _MessagePlaceholderCard({required this.isEmployer});

  final bool isEmployer;

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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.coralAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.coralAccent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isEmployer
                ? 'Your conversations with workers will appear here.'
                : 'Your conversations with employers will appear here.',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmployer
                ? 'Once matches are created, this tab will keep your worker conversations organized in one place.'
                : 'Once matches are created, this tab will keep your employer conversations organized in one place.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

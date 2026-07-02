import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/services/application_service.dart';
import '../../reviews/widgets/public_profile_reviews_section.dart';
import '../services/employee_profile_service.dart';

class EmployeeProfilePreviewPage extends StatelessWidget {
  const EmployeeProfilePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = EmployeeProfileService();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBg,
        foregroundColor: AppColors.white,
        title: const Text('Profile preview'),
      ),
      body: user == null
          ? const _PreviewMessage('Sign in to preview your profile.')
          : StreamBuilder<Map<String, dynamic>?>(
              stream: service.watchCurrentEmployeeProfile(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.coralAccent,
                    ),
                  );
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return const _PreviewMessage(
                    'Your profile preview is not available right now.',
                  );
                }
                final candidate = CandidateProfileSummary.fromData(
                  employeeId: user.uid,
                  fallbackName: user.displayName,
                  data: snapshot.data,
                );
                return _CandidatePreview(candidate: candidate);
              },
            ),
    );
  }
}

class _CandidatePreview extends StatelessWidget {
  const _CandidatePreview({required this.candidate});

  final CandidateProfileSummary candidate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CandidateAvatar(candidate: candidate),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _AvailabilityBadge(candidate.availabilityLabel),
                      const SizedBox(height: 12),
                      Text(
                        [
                          candidate.ageRange,
                          candidate.experienceLabel,
                        ].whereType<String>().join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PreviewCard(
            child: Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: 'Availability',
                    value: candidate.availabilityLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Fact(
                    label: 'Experience',
                    value: candidate.experienceLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Fact(
                    label: 'Skills',
                    value: candidate.skills.length.toString(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'About',
            child: Text(
              candidate.shortBio ?? 'No bio added yet.',
              style: AppTextStyles.body,
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Skills & preferred roles',
            child: _ProfileChips(
              values: {
                ...candidate.skills,
                ...candidate.preferredRoles,
                ...candidate.jobCategories,
              }.toList(),
            ),
          ),
          if (candidate.pastExperiences.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Work experience',
              child: Column(
                children: candidate.pastExperiences
                    .take(3)
                    .map((experience) => _ExperienceRow(experience))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          PublicProfileReviewsSection(userId: candidate.id),
        ],
      ),
    );
  }
}

class _CandidateAvatar extends StatelessWidget {
  const _CandidateAvatar({required this.candidate});
  final CandidateProfileSummary candidate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 112,
        height: 132,
        child: candidate.imageUrl == null
            ? Container(
                color: AppColors.surface,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.coralAccent,
                  size: 48,
                ),
              )
            : Image.network(
                candidate.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surface,
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.coralAccent,
                    size: 48,
                  ),
                ),
              ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.coralAccent),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.coralAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: AppTextStyles.label, textAlign: TextAlign.center),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _ProfileChips extends StatelessWidget {
  const _ProfileChips({required this.values});
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text('Not added yet', style: AppTextStyles.label);
    }
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: values.take(10).map((value) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.navyBg.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value, style: AppTextStyles.label),
        );
      }).toList(),
    );
  }
}

class _ExperienceRow extends StatelessWidget {
  const _ExperienceRow(this.experience);
  final CandidateExperience experience;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.work_outline_rounded,
            color: AppColors.coralAccent,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  experience.title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (experience.workplace != null) ...[
                  Text(experience.workplace!, style: AppTextStyles.label),
                ],
                if (experience.duration != null) ...[
                  Text(experience.duration!, style: AppTextStyles.label),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../auth/screens/welcome_page.dart';
import '../../auth/services/auth_service.dart';
import '../services/employee_profile_service.dart';
import 'employee_basic_info_page.dart';
import 'employee_work_preferences_page.dart';
import 'employee_availability_location_page.dart';
import 'employee_experience_summary_page.dart';

class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  final EmployeeProfileService _service = EmployeeProfileService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _service.watchCurrentEmployeeProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }

            if (snapshot.hasError) {
              return _ErrorState(
                onRetry: () {
                  setState(() {});
                },
              );
            }

            final profile = snapshot.data;

            if (profile == null || profile.isEmpty) {
              return const _EmptyProfileState();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.horizontal,
                vertical: AppSpacing.vertical,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeaderCard(
                    profile: profile,
                    onEditImage: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeeBasicInfoPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ProfileCompletionCard(profile: profile),
                  const SizedBox(height: 24),
                  _PersonalInfoSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeeBasicInfoPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _WorkPreferencesSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeeWorkPreferencesPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _AvailabilityLocationSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeeAvailabilityLocationPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _ExperienceSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EmployeeExperienceSummaryPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _LogoutActionCard(onTap: _confirmAndLogout),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Log out?',
            style: TextStyle(color: AppColors.white),
          ),
          content: const Text(
            'Are you sure you want to sign out of your account?',
            style: TextStyle(color: AppColors.lightText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.lightText),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Log out',
                style: TextStyle(
                  color: AppColors.coralAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await _authService.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not log out. Please try again.'),
        ),
      );
    }
  }
}

// ============================================================================
// LOADING STATE
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading your profile...',
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.horizontal),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.coralAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong while loading your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(
                      color: AppColors.navyBg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

// ============================================================================
// EMPTY PROFILE STATE
// ============================================================================

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.horizontal),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_add,
                color: AppColors.coralAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'We could not find your employee profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmployeeBasicInfoPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Complete profile',
                    style: TextStyle(
                      color: AppColors.navyBg,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

// ============================================================================
// PROFILE HEADER CARD
// ============================================================================

class _ProfileHeaderCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEditImage;

  const _ProfileHeaderCard({
    required this.profile,
    required this.onEditImage,
  });

  String _getAvailabilityBadge() {
    final isAvailableNow = _safeGetBool('availableNow', _safeGetBool('isAvailableNow', false));
    return isAvailableNow ? 'Available now' : 'Not available now';
  }

  Color _getAvailabilityColor() {
    final isAvailableNow = _safeGetBool('availableNow', _safeGetBool('isAvailableNow', false));
    return isAvailableNow ? Colors.green : AppColors.lightText;
  }

  T _safeGet<T>(String key, T defaultValue) {
    final value = profile[key];
    return value is T ? value : defaultValue;
  }

  bool _safeGetBool(String key, bool defaultValue) => _safeGet(key, defaultValue);
  String _safeGetString(String key, String defaultValue) => _safeGet(key, defaultValue);

  @override
  Widget build(BuildContext context) {
    final name = _safeGetString('name', 'Your profile');
    final profileImageUrl = _safeGetString('profileImageUrl', '');
    final availabilityBadge = _getAvailabilityBadge();
    final availabilityColor = _getAvailabilityColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onEditImage,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.coralAccent.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.coralAccent.withOpacity(0.35),
                        ),
                      ),
                      child: profileImageUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person_outline,
                                    color: AppColors.coralAccent,
                                    size: 40,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.person_outline,
                              color: AppColors.coralAccent,
                              size: 40,
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.navyBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.coralAccent,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: availabilityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: availabilityColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            availabilityBadge,
                            style: TextStyle(
                              color: availabilityColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROFILE COMPLETION CARD
// ============================================================================

class _ProfileCompletionCard extends StatelessWidget {
  final Map<String, dynamic> profile;

  const _ProfileCompletionCard({required this.profile});

  int _calculateCompletion() {
    final fields = [
      'name',
      'phoneNumber',
      'ageRange',
      'jobCategories',
      'preferredRoles',
      'skills',
      'salaryExpectation',
      'preferredWorkRadiusKm',
      'availableDays',
      'preferredShiftTypes',
      'shortBio',
      'pastWorkExperience',
    ];

    int completed = 0;
    for (final field in fields) {
      final value = profile[field];
      if (value != null) {
        if (value is List) {
          if (value.isNotEmpty) completed++;
        } else if (value is String) {
          if (value.isNotEmpty) completed++;
        } else if (value is num) {
          if (value != 0) completed++;
        } else {
          completed++;
        }
      }
    }

    return ((completed / fields.length) * 100).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final completion = _calculateCompletion();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile strength',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completion% complete',
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 8,
              backgroundColor: AppColors.navyBg.withOpacity(0.5),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Complete your profile to get better job matches.',
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PERSONAL INFO SECTION
// ============================================================================

class _PersonalInfoSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _PersonalInfoSection({
    required this.profile,
    required this.onEdit,
  });

  String _safeGetString(String key, String defaultValue) {
    final value = profile[key];
    return value is String ? value : defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final name = _safeGetString('name', 'Not added yet');
    final phone = _safeGetString('phoneNumber', 'Not added yet');
    final age = _safeGetString('ageRange', 'Not added yet');

    return _ProfileSectionCard(
      icon: Icons.badge_outlined,
      title: 'Personal Info',
      subtitle: 'Basic details employers may use to contact you.',
      onEdit: onEdit,
      child: Column(
        children: [
          _ProfileInfoTile(
            icon: Icons.person_outline,
            label: 'Full name',
            value: name,
          ),
          const Divider(color: AppColors.border, height: 1),
          _ProfileInfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: phone,
          ),
          const Divider(color: AppColors.border, height: 1),
          _ProfileInfoTile(
            icon: Icons.cake_outlined,
            label: 'Age range',
            value: age,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WORK PREFERENCES SECTION
// ============================================================================

class _WorkPreferencesSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _WorkPreferencesSection({
    required this.profile,
    required this.onEdit,
  });

  List<dynamic> _safeGetList(String key, List<dynamic> defaultValue) {
    final value = profile[key];
    return value is List ? value : defaultValue;
  }

  double _safeGetDouble(String key, double defaultValue) {
    final value = profile[key];
    return value is num ? value.toDouble() : defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final jobCategories = _safeGetList('jobCategories', []);
    final roles = _safeGetList('preferredRoles', []);
    final skills = _safeGetList('skills', []);
    final salary = _safeGetDouble('salaryExpectation', 0);

    return _ProfileSectionCard(
      icon: Icons.tune_rounded,
      title: 'Work Preferences',
      subtitle: 'The types of jobs you are interested in.',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jobCategories.isNotEmpty) ...[
            _ChipGroup(
              label: 'Job categories',
              chips: jobCategories.cast<String>(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const _ChipGroupEmpty(label: 'Job categories'),
            const SizedBox(height: 16),
          ],
          if (roles.isNotEmpty) ...[
            _ChipGroup(
              label: 'Preferred roles',
              chips: roles.cast<String>(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const _ChipGroupEmpty(label: 'Preferred roles'),
            const SizedBox(height: 16),
          ],
          if (skills.isNotEmpty) ...[
            _ChipGroup(
              label: 'Skills',
              chips: skills.cast<String>(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const _ChipGroupEmpty(label: 'Skills'),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Salary expectation',
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 14,
                  ),
                ),
                Text(
                  salary > 0 ? '\$${salary.toStringAsFixed(2)}/hr' : 'Not set yet',
                  style: const TextStyle(
                    color: AppColors.coralAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// AVAILABILITY & LOCATION SECTION
// ============================================================================

class _AvailabilityLocationSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _AvailabilityLocationSection({
    required this.profile,
    required this.onEdit,
  });

  bool _safeGetBool(String key, bool defaultValue) {
    final value = profile[key];
    return value is bool ? value : defaultValue;
  }

  List<dynamic> _safeGetList(String key, List<dynamic> defaultValue) {
    final value = profile[key];
    return value is List ? value : defaultValue;
  }

  double _safeGetDouble(String key, double defaultValue) {
    final value = profile[key];
    return value is num ? value.toDouble() : defaultValue;
  }

  Map<String, dynamic> _safeGetMap(String key, Map<String, dynamic> defaultValue) {
    final value = profile[key];
    return value is Map ? Map<String, dynamic>.from(value) : defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final availableNow = _safeGetBool('availableNow', _safeGetBool('isAvailableNow', false));
    final canWorkToday = _safeGetBool('canWorkToday', false);
    final canWorkShortNotice = _safeGetBool('canWorkOnShortNotice', _safeGetBool('canWorkShortNotice', false));
    final availableDays = _safeGetList('availableDays', []);
    final shiftTypes = _safeGetList('preferredShiftTypes', []);
    final radius = _safeGetDouble('preferredWorkRadiusKm', 0);
    final locationData = _safeGetMap('location', {});
    final hasLocation = locationData.isNotEmpty;

    return _ProfileSectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Availability & Location',
      subtitle: 'When and where you are ready to work.',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvailabilityStatusBlock(
            availableNow: availableNow,
            canWorkToday: canWorkToday,
            canWorkShortNotice: canWorkShortNotice,
          ),
          const SizedBox(height: 16),
          if (availableDays.isNotEmpty) ...[
            _ChipGroup(
              label: 'Available days',
              chips: availableDays.map((item) => item.toString()).toList(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const _ChipGroupEmpty(label: 'Available days'),
            const SizedBox(height: 16),
          ],
          if (shiftTypes.isNotEmpty) ...[
            _ChipGroup(
              label: 'Preferred shift types',
              chips: shiftTypes.map((item) => item.toString()).toList(),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const _ChipGroupEmpty(label: 'Preferred shift types'),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Work radius',
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 14,
                  ),
                ),
                Text(
                  radius > 0
                      ? 'Up to ${radius.toStringAsFixed(0)} km'
                      : 'Not set yet',
                  style: const TextStyle(
                    color: AppColors.coralAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Location',
                  style: TextStyle(
                    color: AppColors.lightText,
                    fontSize: 14,
                  ),
                ),
                Text(
                  hasLocation ? 'Location enabled' : 'Location not enabled',
                  style: TextStyle(
                    color: hasLocation ? Colors.green : AppColors.lightText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EXPERIENCE SECTION
// ============================================================================

class _ExperienceSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _ExperienceSection({
    required this.profile,
    required this.onEdit,
  });

  String _safeGetString(String key, String defaultValue) {
    final value = profile[key];
    return value is String ? value : defaultValue;
  }

  List<dynamic> _safeGetList(String key, List<dynamic> defaultValue) {
    final value = profile[key];
    return value is List ? value : defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final bio = _safeGetString('shortBio', 'No bio added yet');
    final experiences = _safeGetList('pastWorkExperience', _safeGetList('pastExperiences', []));

    return _ProfileSectionCard(
      icon: Icons.work_history_outlined,
      title: 'Experience',
      subtitle: 'A short summary that helps employers know you better.',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navyBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              bio,
              style: const TextStyle(
                color: AppColors.lightText,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (experiences.isNotEmpty)
            ...List.generate(experiences.length, (index) {
              final exp = experiences[index];
              if (exp is! Map) return const SizedBox.shrink();

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < experiences.length - 1 ? 12 : 0,
                ),
                child: _ExperienceMiniCard(
                  experience: Map<String, dynamic>.from(exp),
                ),
              );
            })
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navyBg.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.3)),
              ),
              child: const Text(
                'No past experience added yet',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

class _ProfileSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final Widget child;

  const _ProfileSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.coralAccent, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.lightText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.coralAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.coralAccent,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _LogoutActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.coralAccent.withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.coralAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.coralAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Sign out of your Wurkit account',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.lightText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.lightText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final String label;
  final List<String> chips;

  const _ChipGroup({
    required this.label,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lightText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips
              .map(
                (chip) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.coralAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.coralAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      color: AppColors.coralAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ChipGroupEmpty extends StatelessWidget {
  final String label;

  const _ChipGroupEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lightText,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.navyBg.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withOpacity(0.3)),
          ),
          child: const Text(
            'Not selected yet',
            style: TextStyle(
              color: AppColors.lightText,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvailabilityStatusBlock extends StatelessWidget {
  final bool availableNow;
  final bool canWorkToday;
  final bool canWorkShortNotice;

  const _AvailabilityStatusBlock({
    required this.availableNow,
    required this.canWorkToday,
    required this.canWorkShortNotice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusRow(
            label: 'Available now',
            isActive: availableNow,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            label: 'Can work today',
            isActive: canWorkToday,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            label: 'Short notice availability',
            isActive: canWorkShortNotice,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool isActive;

  const _StatusRow({
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.lightText,
            fontSize: 13,
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.green.withOpacity(0.2)
                : AppColors.navyBg.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? Colors.green : AppColors.border,
            ),
          ),
          child: isActive
              ? const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.green,
                )
              : null,
        ),
      ],
    );
  }
}

class _ExperienceMiniCard extends StatelessWidget {
  final Map<String, dynamic> experience;

  const _ExperienceMiniCard({required this.experience});

  String _safeGetString(String key, String defaultValue) {
    final value = experience[key];
    return value is String ? value : defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    final title = _safeGetString('jobTitle', _safeGetString('title', 'Job'));
    final company = _safeGetString('workplace', _safeGetString('company', 'Company'));
    final category = _safeGetString('category', '');
    final duration = _safeGetString('duration', '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.work_outline,
                color: AppColors.coralAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            company,
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 12,
            ),
          ),
          if (category.isNotEmpty || duration.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (category.isNotEmpty) ...[
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: AppColors.coralAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (duration.isNotEmpty)
                  Text(
                    duration,
                    style: const TextStyle(
                      color: AppColors.lightText,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

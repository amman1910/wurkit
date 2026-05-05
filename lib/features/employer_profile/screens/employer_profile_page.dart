import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../auth/screens/welcome_page.dart';
import '../../auth/services/auth_service.dart';
import '../services/employer_profile_service.dart';
import 'employer_business_info_page.dart';
import 'employer_business_location_page.dart';
import 'employer_hiring_preferences_page.dart';
import 'employer_profile_summary_page.dart';

class EmployerProfilePage extends StatefulWidget {
  const EmployerProfilePage({super.key});

  @override
  State<EmployerProfilePage> createState() => _EmployerProfilePageState();
}

class _EmployerProfilePageState extends State<EmployerProfilePage> {
  final EmployerProfileService _service = EmployerProfileService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _service.watchCurrentEmployerProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }

            if (snapshot.hasError) {
              return _ErrorState(onRetry: () => setState(() {}));
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
                  _BusinessHeaderCard(
                    profile: profile,
                    onEditLogo: () => _openBusinessInfo(context),
                  ),
                  const SizedBox(height: 24),
                  _ProfileCompletionCard(profile: profile),
                  const SizedBox(height: 24),
                  _BusinessInfoSection(
                    profile: profile,
                    onEdit: () => _openBusinessInfo(context),
                  ),
                  const SizedBox(height: 24),
                  _LocationSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployerBusinessLocationPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _HiringPreferencesSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployerHiringPreferencesPage(isEditing: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _PublicBusinessNoteSection(
                    profile: profile,
                    onEdit: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmployerProfileSummaryPage(isEditing: true),
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

  void _openBusinessInfo(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EmployerBusinessInfoPage(isEditing: true),
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
          ),
          SizedBox(height: 20),
          Text(
            'Loading your business profile...',
            style: TextStyle(color: AppColors.lightText, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _CenteredStateCard(
      icon: Icons.error_outline,
      message: 'Something went wrong while loading your business profile.',
      buttonText: 'Try again',
      onPressed: onRetry,
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState();

  @override
  Widget build(BuildContext context) {
    return _CenteredStateCard(
      icon: Icons.storefront_outlined,
      message: 'We could not find your business profile.',
      buttonText: 'Complete business profile',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployerBusinessInfoPage()),
        );
      },
    );
  }
}

class _CenteredStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;

  const _CenteredStateCard({
    required this.icon,
    required this.message,
    required this.buttonText,
    required this.onPressed,
  });

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
              Icon(icon, color: AppColors.coralAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                  onPressed: onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coralAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
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

class _BusinessHeaderCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEditLogo;

  const _BusinessHeaderCard({
    required this.profile,
    required this.onEditLogo,
  });

  @override
  Widget build(BuildContext context) {
    final businessName = _readString(profile, 'businessName', 'Business profile');
    final businessType = _readString(profile, 'businessType', 'Not added yet');
    final logoUrl = _readString(profile, 'businessLogoUrl', '');
    final urgentHiring = _readBool(profile, 'urgentHiringEnabled', false);
    final badgeText = urgentHiring ? 'Urgent hiring enabled' : 'Standard hiring';
    final badgeColor = urgentHiring ? Colors.green : AppColors.lightText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEditLogo,
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
                  child: logoUrl.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            logoUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.storefront_rounded,
                                color: AppColors.coralAccent,
                                size: 40,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.storefront_rounded,
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
                  businessName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  businessType,
                  style: const TextStyle(
                    color: AppColors.lightText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withOpacity(0.45)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _ProfileCompletionCard extends StatelessWidget {
  final Map<String, dynamic> profile;

  const _ProfileCompletionCard({required this.profile});

  int _calculateCompletion() {
    final fields = [
      'businessName',
      'businessType',
      'businessPhone',
      'businessEmail',
      'businessDescription',
      'businessLogoUrl',
      'businessAddress',
      'city',
      'location',
      'hiringCategories',
      'requiredSkills',
      'typicalShiftTypes',
      'defaultHourlyRateMin',
      'defaultHourlyRateMax',
      'preferredExperienceLevel',
      'publicBusinessNote',
    ];

    var completed = 0;
    for (final field in fields) {
      final value = profile[field];
      if (value is String && value.trim().isNotEmpty) completed++;
      if (value is List && value.isNotEmpty) completed++;
      if (value is Map && value.isNotEmpty) completed++;
      if (value is num && value > 0) completed++;
    }

    return ((completed / fields.length) * 100).round();
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
            'Business profile strength',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completion% complete',
            style: const TextStyle(color: AppColors.lightText, fontSize: 14),
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
            'Complete your business profile to improve trust and attract better candidates.',
            style: TextStyle(color: AppColors.lightText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BusinessInfoSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _BusinessInfoSection({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.apartment_rounded,
      title: 'Business Info',
      subtitle: 'Basic details workers see before applying.',
      onEdit: onEdit,
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.storefront_outlined,
            label: 'Business name',
            value: _readString(profile, 'businessName', 'Not added yet'),
          ),
          _InfoTile(
            icon: Icons.category_outlined,
            label: 'Business type',
            value: _readString(profile, 'businessType', 'Not added yet'),
          ),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: _readString(profile, 'businessPhone', 'Not added yet'),
          ),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _readString(profile, 'businessEmail', 'Not added yet'),
          ),
          _InfoTile(
            icon: Icons.notes_outlined,
            label: 'Description',
            value: _readString(profile, 'businessDescription', 'No description added yet'),
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _LocationSection({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final location = _readMap(profile, 'location');
    final hasLocation = location['lat'] != null && location['lng'] != null;

    return _SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location',
      subtitle: 'Where workers should arrive for shifts.',
      onEdit: onEdit,
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.place_outlined,
            label: 'Address',
            value: _readString(profile, 'businessAddress', 'Not added yet'),
          ),
          _InfoTile(
            icon: Icons.location_city_outlined,
            label: 'City',
            value: _readString(profile, 'city', 'Not added yet'),
          ),
          _InfoTile(
            icon: Icons.domain_outlined,
            label: 'Physical business',
            value: _readBool(profile, 'isPhysicalBusiness', false) ? 'Yes' : 'No',
          ),
          _InfoTile(
            icon: hasLocation ? Icons.check_circle_outline : Icons.info_outline,
            label: 'Location status',
            value: hasLocation ? 'Location enabled' : 'Location not enabled',
            valueColor: hasLocation ? Colors.green : AppColors.lightText,
          ),
        ],
      ),
    );
  }
}

class _HiringPreferencesSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _HiringPreferencesSection({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final minRate = _readDouble(profile, 'defaultHourlyRateMin', 0);
    final maxRate = _readDouble(profile, 'defaultHourlyRateMax', 0);

    return _SectionCard(
      icon: Icons.tune_rounded,
      title: 'Hiring Preferences',
      subtitle: 'The worker types and shifts your business usually needs.',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Hiring categories',
            chips: _readStringList(profile, 'hiringCategories'),
          ),
          const SizedBox(height: 16),
          _ChipGroup(
            label: 'Required skills',
            chips: _readStringList(profile, 'requiredSkills'),
          ),
          const SizedBox(height: 16),
          _ChipGroup(
            label: 'Typical shift types',
            chips: _readStringList(profile, 'typicalShiftTypes'),
          ),
          const SizedBox(height: 16),
          _InfoTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Preferred experience level',
            value: _readString(profile, 'preferredExperienceLevel', 'Not added yet'),
          ),
          _PaymentRangeBlock(minRate: minRate, maxRate: maxRate),
          const SizedBox(height: 14),
          _StatusBlock(
            urgentHiringEnabled: _readBool(profile, 'urgentHiringEnabled', false),
            shortNoticeEnabled: _readBool(profile, 'usuallyNeedsShortNoticeWorkers', false),
          ),
        ],
      ),
    );
  }
}

class _PublicBusinessNoteSection extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _PublicBusinessNoteSection({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.description_outlined,
      title: 'Public Business Note',
      subtitle: 'A short note that helps workers understand your business.',
      onEdit: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navyBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _readString(
            profile,
            'publicBusinessNote',
            'No public business note added yet.',
          ),
          style: const TextStyle(color: AppColors.lightText, fontSize: 14),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final Widget child;

  const _SectionCard({
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                  style: const TextStyle(color: AppColors.lightText, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.white,
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
          style: const TextStyle(color: AppColors.lightText, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (chips.isEmpty)
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
              style: TextStyle(color: AppColors.lightText, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _PaymentRangeBlock extends StatelessWidget {
  final double minRate;
  final double maxRate;

  const _PaymentRangeBlock({
    required this.minRate,
    required this.maxRate,
  });

  @override
  Widget build(BuildContext context) {
    final value = minRate > 0 && maxRate > 0
        ? 'NIS ${minRate.toStringAsFixed(0)} - NIS ${maxRate.toStringAsFixed(0)} per hour'
        : 'Not set yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.coralAccent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.coralAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.coralAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBlock extends StatelessWidget {
  final bool urgentHiringEnabled;
  final bool shortNoticeEnabled;

  const _StatusBlock({
    required this.urgentHiringEnabled,
    required this.shortNoticeEnabled,
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
        children: [
          _StatusRow(label: 'Urgent hiring', isActive: urgentHiringEnabled),
          const SizedBox(height: 8),
          _StatusRow(label: 'Short notice workers', isActive: shortNoticeEnabled),
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
          style: const TextStyle(color: AppColors.lightText, fontSize: 13),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.green.withOpacity(0.2)
                : AppColors.navyBg.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isActive ? Colors.green : AppColors.border),
          ),
          child: isActive
              ? const Icon(Icons.check, size: 16, color: Colors.green)
              : null,
        ),
      ],
    );
  }
}

String _readString(Map<String, dynamic> data, String key, String fallback) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

bool _readBool(Map<String, dynamic> data, String key, bool fallback) {
  final value = data[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

double _readDouble(Map<String, dynamic> data, String key, double fallback) {
  final value = data[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is List) {
    return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}

Map<String, dynamic> _readMap(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

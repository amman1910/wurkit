import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_ui.dart';
import '../../employer_home/screens/employer_main_navigation_page.dart';
import '../services/employer_profile_service.dart';

class EmployerProfileSummaryPage extends StatefulWidget {
  final bool isEditing;

  const EmployerProfileSummaryPage({super.key, this.isEditing = false});

  @override
  State<EmployerProfileSummaryPage> createState() => _EmployerProfileSummaryPageState();
}

class _EmployerProfileSummaryPageState extends State<EmployerProfileSummaryPage>
    with SingleTickerProviderStateMixin {
  final EmployerProfileService _profileService = EmployerProfileService();
  final TextEditingController _publicNoteController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isFinishing = false;
  Map<String, dynamic>? _profileData;

  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _animations = List.generate(7, (index) => _createAnimation(index));
    _animationController.forward();
    _loadProfile();
  }

  Animation<double> _createAnimation(int index) {
    final intervals = [
      const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
      const Interval(0.1, 0.35, curve: Curves.easeOutCubic),
      const Interval(0.2, 0.45, curve: Curves.easeOutCubic),
      const Interval(0.3, 0.55, curve: Curves.easeOutCubic),
      const Interval(0.4, 0.65, curve: Curves.easeOutCubic),
      const Interval(0.5, 0.75, curve: Curves.easeOutCubic),
      const Interval(0.6, 0.85, curve: Curves.easeOutCubic),
    ];

    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: intervals[index],
      ),
    );
  }

  @override
  void dispose() {
    _publicNoteController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getEmployerProfile();
      if (!mounted) return;

      setState(() {
        _profileData = profile;
        _publicNoteController.text = _readStringFromData(profile, 'publicBusinessNote');
        _isLoadingProfile = false;
      });

      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Business profile data was not found'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load business profile: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _handleFinish() async {
    setState(() {
      _isFinishing = true;
    });

    try {
      final note = _publicNoteController.text.trim();
      await _profileService.completeEmployerProfile(
        publicBusinessNote: note.isEmpty ? null : note,
      );

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployerMainNavigationPage(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete business profile: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  String _readString(String key, {String fallback = 'Not provided'}) {
    return _readStringFromData(_profileData, key, fallback: fallback);
  }

  static String _readStringFromData(
    Map<String, dynamic>? data,
    String key, {
    String fallback = '',
  }) {
    final value = data?[key];
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  bool _readBool(String key) {
    final value = _profileData?[key];
    return value is bool ? value : false;
  }

  List<String> _readStringList(String key) {
    final value = _profileData?[key];
    if (value is List) {
      return value
          .whereType<dynamic>()
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _formatYesNo(bool value) {
    return value ? 'Yes' : 'No';
  }

  String _formatHourlyRateRange() {
    final minValue = _profileData?['defaultHourlyRateMin'];
    final maxValue = _profileData?['defaultHourlyRateMax'];

    if (minValue is num && maxValue is num) {
      return 'NIS ${minValue.toStringAsFixed(0)} - NIS ${maxValue.toStringAsFixed(0)} per hour';
    }

    return 'Not provided';
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return FadeTransition(
      opacity: _animations[index],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(_animations[index]),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeaderIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: AppColors.coralAccent,
        size: 20,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: AppColors.lightText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: AppColors.white,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipList(List<String> items) {
    if (items.isEmpty) {
      return Text(
        'Not provided',
        style: AppTextStyles.body.copyWith(
          color: AppColors.lightText,
          fontSize: 15,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.navyBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            item,
            style: AppTextStyles.label.copyWith(
              color: AppColors.white,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLabeledChipGroup(String label, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: AppColors.lightText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          _buildChipList(items),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_isLoadingProfile) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_profileData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'We could not find your business profile summary yet.',
          style: AppTextStyles.body.copyWith(color: AppColors.lightText),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        _buildAnimatedItem(
          2,
          Container(
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
                Row(
                  children: [
                    _buildSectionHeaderIcon(Icons.storefront_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Business info',
                        style: AppTextStyles.buttonLabel(
                          color: AppColors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Business name', _readString('businessName')),
                _buildInfoRow('Business type', _readString('businessType')),
                _buildInfoRow('Business phone', _readString('businessPhone')),
                _buildInfoRow('Business email', _readString('businessEmail')),
                _buildInfoRow('Business description', _readString('businessDescription')),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.field),
        _buildAnimatedItem(
          3,
          Container(
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
                Row(
                  children: [
                    _buildSectionHeaderIcon(Icons.location_on_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Location',
                        style: AppTextStyles.buttonLabel(
                          color: AppColors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Business address', _readString('businessAddress')),
                _buildInfoRow('City', _readString('city')),
                _buildInfoRow('Physical business', _formatYesNo(_readBool('isPhysicalBusiness'))),
                _buildInfoRow(
                  'Location permission granted',
                  _formatYesNo(_readBool('locationPermissionGranted')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.field),
        _buildAnimatedItem(
          4,
          Container(
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
                Row(
                  children: [
                    _buildSectionHeaderIcon(Icons.groups_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hiring preferences',
                        style: AppTextStyles.buttonLabel(
                          color: AppColors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabeledChipGroup('Hiring categories', _readStringList('hiringCategories')),
                _buildLabeledChipGroup('Required skills', _readStringList('requiredSkills')),
                _buildLabeledChipGroup('Typical shift types', _readStringList('typicalShiftTypes')),
                _buildInfoRow('Urgent hiring enabled', _formatYesNo(_readBool('urgentHiringEnabled'))),
                _buildInfoRow(
                  'Short-notice workers',
                  _formatYesNo(_readBool('usuallyNeedsShortNoticeWorkers')),
                ),
                _buildInfoRow('Default hourly rate range', _formatHourlyRateRange()),
                _buildInfoRow(
                  'Preferred experience level',
                  _readString('preferredExperienceLevel'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.field),
        _buildAnimatedItem(
          5,
          TextFormField(
            controller: _publicNoteController,
            maxLines: 4,
            maxLength: 200,
            style: AppTextStyles.input,
            decoration: AppInputDecorations.authField(
              label: 'Public business note',
              hint: 'Add a short note workers will see on your business profile...',
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildAnimatedItem(
          6,
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: _isFinishing ? null : _handleFinish,
              style: AppButtonStyles.primary(
                backgroundColor: AppColors.coralAccent,
                foregroundColor: AppColors.navyBg,
                disabledBackgroundColor: AppColors.coralAccent.withOpacity(0.35),
              ),
              child: _isFinishing
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyBg),
                    )
                  : Text(
                      widget.isEditing ? 'Save changes' : 'Finish',
                      style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                    ),
            ),
          ),
        ),
      ],
    );
  }

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              _buildAnimatedItem(
                0,
                Image.asset(
                  'assets/images/wurkit_logo.png',
                  height: 92,
                ),
              ),
              const SizedBox(height: 18),
              _buildAnimatedItem(
                1,
                Column(
                  children: [
                    Text(
                      'Review your business profile',
                      style: GoogleFonts.nunito(
                        color: AppColors.coralAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Make sure everything looks good before workers see your business.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.lightText,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildProfileContent(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

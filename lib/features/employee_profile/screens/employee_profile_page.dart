import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_ui.dart';
import '../../auth/screens/welcome_page.dart';
import '../../auth/services/auth_service.dart';
import '../../reviews/screens/user_reviews_list.dart';
import '../../reviews/widgets/user_rating_summary.dart';
import '../services/employee_profile_service.dart';
import 'employee_basic_info_page.dart';

class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  final EmployeeProfileService _service = EmployeeProfileService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isDeletingAccount = false;

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
              return _ErrorState(onRetry: () => setState(() {}));
            }

            final profile = snapshot.data;
            if (profile == null || profile.isEmpty) {
              return const _EmptyProfileState();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeaderCard(
                    profile: profile,
                    isUploadingImage: _isUploadingImage,
                    onEditImage: _updateProfileImage,
                  ),
                  const SizedBox(height: 10),
                  _ReviewsSection(
                    userId: FirebaseAuth.instance.currentUser?.uid,
                  ),
                  const SizedBox(height: 10),
                  _ProfileCompletionCard(
                    profile: profile,
                    onTap: () => _showProfileSummarySheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _WorkPreferencesCard(
                    profile: profile,
                    onEdit: () => _showEditWorkPreferencesSheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _AvailabilityLocationCard(
                    profile: profile,
                    onEdit: () => _showEditAvailabilitySheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _ExperienceCard(
                    profile: profile,
                    onEdit: () => _showEditExperienceSheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _LogoutActionCard(onTap: _confirmAndLogout),
                  const SizedBox(height: 10),
                  _DeleteAccountActionCard(
                    onTap: _isDeletingAccount ? null : _confirmAndDeleteAccount,
                    isLoading: _isDeletingAccount,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _updateProfileImage() async {
    if (_isUploadingImage) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);
      final imageUrl = await _service.uploadEmployeeProfileImage(
        imageFile: File(pickedFile.path),
      );
      await _saveProfileUpdates({'profileImageUrl': imageUrl});
      if (!mounted) return;
      _showSnackBar('Profile image updated.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not update your profile image.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfileUpdates(Map<String, dynamic> data) async {
    await _service.updateCurrentEmployeeProfile(data);
  }

  void _showProfileSummarySheet(Map<String, dynamic> profile) {
    final completion = _calculateCompletion(profile);
    final missing = _missingProfileElements(profile);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Color.lerp(AppColors.navyBg, AppColors.surface, 0.72),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: AppColors.border.withOpacity(0.55)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Profile Summary',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.lightText,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$completion% complete',
                      style: const TextStyle(
                        color: AppColors.coralAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SheetLabel('What contributes'),
                    const _CompletionSummaryRow('Profile photo'),
                    const _CompletionSummaryRow('Work preferences'),
                    const _CompletionSummaryRow('Availability'),
                    const _CompletionSummaryRow('Experience'),
                    const _CompletionSummaryRow('Location'),
                    const SizedBox(height: 18),
                    if (missing.isEmpty) ...[
                      const Text(
                        'Your profile is fully completed.',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Employers can currently see your profile photo, work preferences, availability, experience, and location.',
                        style: TextStyle(
                          color: AppColors.lightText,
                          height: 1.35,
                        ),
                      ),
                    ] else ...[
                      const _SheetLabel('Missing'),
                      ...missing.map((item) => _MissingSummaryRow(item)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditWorkPreferencesSheet(Map<String, dynamic> profile) {
    final categories = _readStringList(profile, 'jobCategories');
    final roles = _readStringList(profile, 'preferredRoles');
    final skills = _readStringList(profile, 'skills');
    final jobTypes = _readStringList(profile, 'preferredJobTypes');
    final experienceLevel = _readString(profile, 'experienceLevel');

    _showProfileBottomSheet(
      title: 'Work Preferences',
      builder: (context, setSheetState, setSaving) {
        String? selectedExperience = experienceLevel.isEmpty
            ? null
            : experienceLevel;
        return StatefulBuilder(
          builder: (context, localSetState) {
            void toggle(List<String> target, String value) {
              localSetState(() {
                target.contains(value)
                    ? target.remove(value)
                    : target.add(value);
              });
            }

            Future<void> save() async {
              setSaving(true);
              try {
                await _saveProfileUpdates({
                  'jobCategories': categories,
                  'preferredRoles': roles,
                  'skills': skills,
                  'preferredJobTypes': jobTypes,
                  'experienceLevel': selectedExperience ?? '',
                });
                if (!context.mounted || !mounted) return;
                Navigator.pop(context);
                _showSnackBar('Work preferences updated.');
              } catch (_) {
                if (mounted) {
                  _showSnackBar(
                    'Could not save work preferences.',
                    isError: true,
                  );
                }
              } finally {
                setSaving(false);
              }
            }

            return _SheetContent(
              onSave: save,
              children: [
                _MultiSelectBlock(
                  title: 'Job categories',
                  options: _ProfileOptions.jobCategories,
                  selected: categories,
                  onToggle: toggle,
                ),
                _MultiSelectBlock(
                  title: 'Preferred roles',
                  options: _ProfileOptions.roles,
                  selected: roles,
                  onToggle: toggle,
                ),
                _MultiSelectBlock(
                  title: 'Skills',
                  options: _ProfileOptions.skills,
                  selected: skills,
                  onToggle: toggle,
                ),
                _MultiSelectBlock(
                  title: 'Job types',
                  options: _ProfileOptions.jobTypes,
                  selected: jobTypes,
                  onToggle: toggle,
                ),
                _ChoiceBlock(
                  title: 'Experience level',
                  options: _ProfileOptions.experienceLevels,
                  selected: selectedExperience,
                  onSelect: (value) =>
                      localSetState(() => selectedExperience = value),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAvailabilitySheet(Map<String, dynamic> profile) {
    var availableNow = _readBool(
      profile,
      'availableNow',
      _readBool(profile, 'isAvailableNow'),
    );
    var canWorkToday = _readBool(profile, 'canWorkToday');
    var canWorkShortNotice = _readBool(
      profile,
      'canWorkOnShortNotice',
      _readBool(profile, 'canWorkShortNotice'),
    );
    final availableDays = _readStringList(profile, 'availableDays');
    final shiftTypes = _readStringList(profile, 'preferredShiftTypes');
    var radius = _readDouble(
      profile,
      'preferredWorkRadiusKm',
      10,
    ).clamp(2, 30).toDouble();
    final locationPermissionGranted = _readBool(
      profile,
      'locationPermissionGranted',
    );
    final location = _readMap(profile, 'location');

    _showProfileBottomSheet(
      title: 'Availability & Location',
      builder: (context, setSheetState, setSaving) {
        return StatefulBuilder(
          builder: (context, localSetState) {
            void toggle(List<String> target, String value) {
              localSetState(() {
                target.contains(value)
                    ? target.remove(value)
                    : target.add(value);
              });
            }

            Future<void> save() async {
              setSaving(true);
              try {
                await _saveProfileUpdates({
                  'availableNow': availableNow,
                  'isAvailableNow': availableNow,
                  'canWorkToday': canWorkToday,
                  'canWorkOnShortNotice': canWorkShortNotice,
                  'canWorkShortNotice': canWorkShortNotice,
                  'availableDays': availableDays,
                  'preferredShiftTypes': shiftTypes,
                  'preferredWorkRadiusKm': radius,
                  'locationPermissionGranted': locationPermissionGranted,
                  if (location.isNotEmpty) 'location': location,
                });
                if (!context.mounted || !mounted) return;
                Navigator.pop(context);
                _showSnackBar('Availability updated.');
              } catch (_) {
                if (mounted) {
                  _showSnackBar('Could not save availability.', isError: true);
                }
              } finally {
                setSaving(false);
              }
            }

            return _SheetContent(
              onSave: save,
              children: [
                _SwitchRow(
                  title: 'Available now',
                  value: availableNow,
                  onChanged: (value) =>
                      localSetState(() => availableNow = value),
                ),
                _SwitchRow(
                  title: 'Can work today',
                  value: canWorkToday,
                  onChanged: (value) =>
                      localSetState(() => canWorkToday = value),
                ),
                _SwitchRow(
                  title: 'Short notice',
                  value: canWorkShortNotice,
                  onChanged: (value) =>
                      localSetState(() => canWorkShortNotice = value),
                ),
                _MultiSelectBlock(
                  title: 'Available days',
                  options: _ProfileOptions.availableDays,
                  selected: availableDays,
                  onToggle: toggle,
                ),
                _MultiSelectBlock(
                  title: 'Preferred shifts',
                  options: _ProfileOptions.shiftTypes,
                  selected: shiftTypes,
                  onToggle: toggle,
                ),
                const _SheetLabel('Work radius'),
                Slider(
                  value: radius,
                  min: 2,
                  max: 30,
                  divisions: 14,
                  activeColor: AppColors.coralAccent,
                  inactiveColor: AppColors.border,
                  label: '${radius.round()} km',
                  onChanged: (value) => localSetState(() => radius = value),
                ),
                Text(
                  'Up to ${radius.round()} km',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditExperienceSheet(Map<String, dynamic> profile) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _EditExperienceSheet(profile: profile, onSave: _saveProfileUpdates),
    );
    if (!mounted) return;
    if (result == true) {
      _showSnackBar('Experience updated.');
    }
  }

  void _showProfileBottomSheet({
    required String title,
    required Widget Function(
      BuildContext context,
      void Function(VoidCallback fn) setSheetState,
      void Function(bool value) setSaving,
    )
    builder,
    VoidCallback? onClosed,
  }) {
    var isSaving = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void setSaving(bool value) {
              setSheetState(() => isSaving = value);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.86,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: AppColors.lightText,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: isSaving,
                        child: Opacity(
                          opacity: isSaving ? 0.62 : 1,
                          child: builder(context, setSheetState, setSaving),
                        ),
                      ),
                    ),
                    if (isSaving)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: CircularProgressIndicator(
                          color: AppColors.coralAccent,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => onClosed?.call());
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
      if (mounted) {
        _showSnackBar('Could not log out. Please try again.', isError: true);
      }
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    final controller = TextEditingController();
    var canDelete = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> deleteAccount() async {
              if (!canDelete || isDeleting) return;

              setDialogState(() => isDeleting = true);
              setState(() => _isDeletingAccount = true);

              try {
                await _service.deleteEmployeeAccount();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } on EmployeeAccountDeletionException catch (error) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, false);
                _showSnackBar(
                  error.isPermissionDenied
                      ? 'Only employee accounts can be deleted from this screen.'
                      : 'Could not delete account. Please try again.',
                  isError: true,
                );
              } catch (_) {
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, false);
                _showSnackBar(
                  'Could not delete account. Please try again.',
                  isError: true,
                );
              } finally {
                if (mounted) {
                  setState(() => _isDeletingAccount = false);
                }
              }
            }

            return PopScope(
              canPop: !isDeleting,
              child: AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text(
                  'Delete account?',
                  style: TextStyle(color: AppColors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This action is permanent. Your profile, app access, and Firebase Auth account will be deleted.',
                      style: TextStyle(
                        color: AppColors.lightText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Historical applications, matches, and chats may remain visible to employers, but your identity will be anonymized. You will be signed out after deletion.',
                      style: TextStyle(
                        color: AppColors.lightText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Type DELETE to confirm',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      enabled: !isDeleting,
                      style: const TextStyle(color: AppColors.white),
                      decoration: AppInputDecorations.authField(
                        label: 'Confirmation',
                        hint: 'DELETE',
                      ).copyWith(fillColor: AppColors.navyBg),
                      onChanged: (value) {
                        setDialogState(() => canDelete = value == 'DELETE');
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isDeleting
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.lightText),
                    ),
                  ),
                  TextButton(
                    onPressed: canDelete && !isDeleting ? deleteAccount : null,
                    child: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.redAccent,
                            ),
                          )
                        : Text(
                            'Delete account',
                            style: TextStyle(
                              color: canDelete
                                  ? Colors.redAccent
                                  : AppColors.lightText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await _authService.signOut();
    } catch (_) {
      // The callable deletes the Firebase Auth user; local sign-out is a best
      // effort cleanup before clearing the stack.
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.coralAccent,
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    final currentUserId = userId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
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
          UserRatingSummary(userId: currentUserId),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserReviewsList(userId: currentUserId),
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

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.isUploadingImage,
    required this.onEditImage,
  });

  final Map<String, dynamic> profile;
  final bool isUploadingImage;
  final VoidCallback onEditImage;

  @override
  Widget build(BuildContext context) {
    final name = _readString(profile, 'name', 'Your profile');
    final imageUrl = _readString(profile, 'profileImageUrl');
    final availableNow = _readBool(
      profile,
      'availableNow',
      _readBool(profile, 'isAvailableNow'),
    );
    final age = _readString(profile, 'ageRange', 'Age');
    final locationLabel = _locationLabel(profile);

    return _PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileImageButton(
                imageUrl: imageUrl,
                isUploading: isUploadingImage,
                onTap: onEditImage,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xE6FFFFFF),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(
                      text: availableNow
                          ? 'Available now'
                          : 'Not available now',
                      color: availableNow
                          ? Colors.greenAccent.shade400
                          : AppColors.lightText,
                      icon: Icons.circle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderFact(
                  icon: Icons.event_available_outlined,
                  value: age,
                  label: 'Age',
                ),
              ),
              const _VerticalRule(),
              Expanded(
                child: _HeaderFact(
                  icon: Icons.location_on_outlined,
                  value: locationLabel,
                  label: 'Location',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard({required this.profile, required this.onTap});

  final Map<String, dynamic> profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completion = _calculateCompletion(profile);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Profile strength',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.lightText,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completion% complete',
                      style: const TextStyle(
                        color: AppColors.lightText,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: completion / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.navyBg.withOpacity(0.65),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.coralAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      completion >= 100
                          ? 'Great job! Your profile is complete.'
                          : 'Complete your profile to get better job matches.',
                      style: const TextStyle(
                        color: AppColors.lightText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.navyBg.withOpacity(0.28),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border.withOpacity(0.65)),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.coralAccent,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkPreferencesCard extends StatelessWidget {
  const _WorkPreferencesCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final chips = [
      ..._readStringList(profile, 'preferredRoles'),
      ..._readStringList(profile, 'skills'),
      ..._readStringList(profile, 'jobCategories'),
    ];

    return _ActionProfileCard(
      icon: Icons.business_center_outlined,
      title: 'Work Preferences',
      subtitle: 'Preferred jobs, roles and skills.',
      onTap: onEdit,
      trailing: _EditTrailing(onTap: onEdit),
      child: _PreviewChips(items: chips, visibleCount: 3),
    );
  }
}

class _AvailabilityLocationCard extends StatelessWidget {
  const _AvailabilityLocationCard({
    required this.profile,
    required this.onEdit,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final availableNow = _readBool(
      profile,
      'availableNow',
      _readBool(profile, 'isAvailableNow'),
    );
    final shortNotice = _readBool(
      profile,
      'canWorkOnShortNotice',
      _readBool(profile, 'canWorkShortNotice'),
    );
    final radius = _readDouble(profile, 'preferredWorkRadiusKm');
    final days = _readStringList(profile, 'availableDays');

    return _ActionProfileCard(
      icon: Icons.hub_outlined,
      title: 'Availability & Location',
      subtitle: 'When and where you can work.',
      onTap: onEdit,
      trailing: _EditTrailing(onTap: onEdit),
      child: Wrap(
        spacing: 12,
        runSpacing: 7,
        children: [
          _InlineIndicator(
            icon: Icons.calendar_today_outlined,
            text: availableNow ? 'Available now' : 'Not now',
            active: availableNow,
          ),
          _InlineIndicator(
            icon: Icons.schedule_rounded,
            text: shortNotice ? 'Short notice' : 'Planned shifts',
            active: shortNotice,
          ),
          _InlineIndicator(
            icon: Icons.location_on_outlined,
            text: radius > 0
                ? 'Up to ${radius.round()} km'
                : _locationLabel(profile),
          ),
          if (days.isNotEmpty)
            _InlineIndicator(
              icon: Icons.event_outlined,
              text: _shortDays(days),
            ),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bio = _readString(profile, 'shortBio', 'No bio added yet');
    final experiences = _readExperienceList(profile);
    final level = _readString(profile, 'experienceLevel');
    final firstExperience = experiences.isNotEmpty
        ? experiences.first
        : <String, dynamic>{};
    final duration = _readString(firstExperience, 'duration');

    return _ActionProfileCard(
      icon: Icons.star_border_rounded,
      title: 'Experience',
      subtitle: 'Your work experience and bio.',
      onTap: onEdit,
      trailing: _EditTrailing(onTap: onEdit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.lightText,
              fontSize: 14,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          _PreviewChips(
            items: [
              if (duration.isNotEmpty) duration,
              if (level.isNotEmpty) level,
              if (experiences.length > 1) '+${experiences.length - 1} more',
            ],
            emptyText: 'Add experience',
          ),
        ],
      ),
    );
  }
}

class _ActionProfileCard extends StatelessWidget {
  const _ActionProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: _PremiumCard(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: AppColors.lightText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    const SizedBox(height: 8),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.navyBg, AppColors.surface, 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileImageButton extends StatelessWidget {
  const _ProfileImageButton({
    required this.imageUrl,
    required this.isUploading,
    required this.onTap,
  });

  final String imageUrl;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: AppColors.navyBg.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.coralAccent, width: 2),
            ),
            child: ClipOval(
              child: imageUrl.isEmpty
                  ? const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.coralAccent,
                      size: 40,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.coralAccent,
                          size: 40,
                        );
                      },
                    ),
            ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    color: AppColors.coralAccent,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          Positioned(
            right: -3,
            bottom: 3,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.navyBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.coralAccent, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.coralAccent,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderFact extends StatelessWidget {
  const _HeaderFact({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.coralAccent, size: 22),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.border);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: AppColors.navyBg.withOpacity(0.38),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: AppColors.coralAccent, size: 24),
    );
  }
}

class _EditTrailing extends StatelessWidget {
  const _EditTrailing({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.coralAccent,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Edit',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.lightText,
          size: 22,
        ),
      ],
    );
  }
}

class _PreviewChips extends StatelessWidget {
  const _PreviewChips({
    required this.items,
    this.emptyText = 'Not selected yet',
    this.visibleCount = 2,
  });

  final List<String> items;
  final String emptyText;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final cleaned = items
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) {
      return _PreviewChip(text: emptyText, muted: true);
    }
    final visible = cleaned.take(visibleCount).toList();
    final hiddenCount = cleaned.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ...visible.map((item) => _PreviewChip(text: item)),
        if (hiddenCount > 0) _PreviewChip(text: '+$hiddenCount', outline: true),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.text,
    this.muted = false,
    this.outline = false,
  });

  final String text;
  final bool muted;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outline
            ? Colors.transparent
            : AppColors.navyBg.withOpacity(muted ? 0.26 : 0.42),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: outline
              ? AppColors.coralAccent
              : AppColors.border.withOpacity(0.6),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: muted ? AppColors.lightText : AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineIndicator extends StatelessWidget {
  const _InlineIndicator({
    required this.icon,
    required this.text,
    this.active = false,
  });

  final IconData icon;
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: active ? Colors.greenAccent.shade400 : AppColors.coralAccent,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.lightText, fontSize: 13),
        ),
      ],
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.children, required this.onSave});

  final List<Widget> children;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      children: [
        ...children,
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.coralAccent,
              foregroundColor: AppColors.navyBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.lightText),
          ),
        ),
      ],
    );
  }
}

class _EditExperienceSheet extends StatefulWidget {
  const _EditExperienceSheet({required this.profile, required this.onSave});

  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  @override
  State<_EditExperienceSheet> createState() => _EditExperienceSheetState();
}

class _EditExperienceSheetState extends State<_EditExperienceSheet> {
  late final TextEditingController _bioController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _workplaceController;
  late final TextEditingController _durationController;
  late final TextEditingController _descriptionController;
  late final List<Map<String, dynamic>> _experiences;
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(
      text: _readString(widget.profile, 'shortBio'),
    );
    _experiences = _readExperienceList(widget.profile);
    final firstExperience = _experiences.isNotEmpty
        ? _experiences.first
        : <String, dynamic>{};
    _jobTitleController = TextEditingController(
      text: _readString(
        firstExperience,
        'jobTitle',
        _readString(firstExperience, 'title'),
      ),
    );
    _workplaceController = TextEditingController(
      text: _readString(
        firstExperience,
        'workplace',
        _readString(firstExperience, 'company'),
      ),
    );
    _durationController = TextEditingController(
      text: _readString(firstExperience, 'duration'),
    );
    _descriptionController = TextEditingController(
      text: _readString(firstExperience, 'description'),
    );
    final category = _readString(firstExperience, 'category');
    _selectedCategory = category.isEmpty ? null : category;
  }

  @override
  void dispose() {
    _bioController.dispose();
    _jobTitleController.dispose();
    _workplaceController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final bio = _bioController.text.trim();
    final experience = {
      'jobTitle': _jobTitleController.text.trim(),
      'workplace': _workplaceController.text.trim(),
      'category': _selectedCategory ?? '',
      'duration': _durationController.text.trim(),
      'description': _descriptionController.text.trim(),
    };
    final hasExperience = experience.values.any(
      (value) => value.toString().trim().isNotEmpty,
    );
    final updatedExperiences = hasExperience
        ? [experience, ..._experiences.skip(1)]
        : _experiences.skip(1).toList();

    setState(() => _isSaving = true);
    try {
      await widget.onSave({
        'shortBio': bio,
        'pastWorkExperience': updatedExperiences,
        'pastExperiences': updatedExperiences,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save experience.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Experience',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.lightText,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isSaving,
                child: Opacity(
                  opacity: _isSaving ? 0.62 : 1,
                  child: _SheetContent(
                    onSave: _handleSave,
                    children: [
                      _SheetTextField(
                        controller: _bioController,
                        label: 'Bio',
                        minLines: 3,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 12),
                      const _SheetLabel('Most recent experience'),
                      _SheetTextField(
                        controller: _jobTitleController,
                        label: 'Role',
                      ),
                      _SheetTextField(
                        controller: _workplaceController,
                        label: 'Workplace',
                      ),
                      _ChoiceBlock(
                        title: 'Category',
                        options: _ProfileOptions.experienceCategories,
                        selected: _selectedCategory,
                        onSelect: (value) =>
                            setState(() => _selectedCategory = value),
                      ),
                      _SheetTextField(
                        controller: _durationController,
                        label: 'Duration',
                      ),
                      _SheetTextField(
                        controller: _descriptionController,
                        label: 'Notes',
                        minLines: 2,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: CircularProgressIndicator(color: AppColors.coralAccent),
              ),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectBlock extends StatelessWidget {
  const _MultiSelectBlock({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final List<String> selected;
  final void Function(List<String> target, String value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = selected.contains(option);
            return FilterChip(
              selected: active,
              label: Text(option),
              onSelected: (_) => onToggle(selected, option),
              selectedColor: AppColors.coralAccent.withOpacity(0.24),
              backgroundColor: AppColors.navyBg.withOpacity(0.45),
              checkmarkColor: AppColors.coralAccent,
              side: BorderSide(
                color: active ? AppColors.coralAccent : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: active ? AppColors.white : AppColors.lightText,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetLabel(title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final active = selected == option;
            return ChoiceChip(
              selected: active,
              label: Text(option),
              onSelected: (_) => onSelect(option),
              selectedColor: AppColors.coralAccent.withOpacity(0.24),
              backgroundColor: AppColors.navyBg.withOpacity(0.45),
              side: BorderSide(
                color: active ? AppColors.coralAccent : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: active ? AppColors.white : AppColors.lightText,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navyBg.withOpacity(0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.coralAccent,
          ),
        ],
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.white),
        decoration: AppInputDecorations.authField(
          label: label,
        ).copyWith(fillColor: AppColors.navyBg.withOpacity(0.5)),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CompletionSummaryRow extends StatelessWidget {
  const _CompletionSummaryRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.coralAccent,
            size: 18,
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(color: AppColors.lightText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _MissingSummaryRow extends StatelessWidget {
  const _MissingSummaryRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: CircleAvatar(
              radius: 2,
              backgroundColor: AppColors.coralAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.lightText,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutActionCard extends StatelessWidget {
  const _LogoutActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: _PremiumCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.navyBg.withOpacity(0.35),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border.withOpacity(0.6)),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.coralAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sign out of your Wurkit account',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 12,
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

class _DeleteAccountActionCard extends StatelessWidget {
  const _DeleteAccountActionCard({
    required this.onTap,
    required this.isLoading,
  });

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const destructive = Colors.redAccent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: _PremiumCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: destructive.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: destructive.withOpacity(0.32)),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: destructive,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: destructive,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete account',
                      style: TextStyle(
                        color: destructive,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Permanently delete your WURKIT employee account',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 12,
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

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.coralAccent),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.coralAccent,
                size: 44,
              ),
              const SizedBox(height: 14),
              const Text(
                'Something went wrong while loading your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: onRetry,
                style: AppButtonStyles.primary(),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProfileState extends StatelessWidget {
  const _EmptyProfileState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_add_rounded,
                color: AppColors.coralAccent,
                size: 44,
              ),
              const SizedBox(height: 14),
              const Text(
                'We could not find your employee profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeeBasicInfoPage(),
                    ),
                  );
                },
                style: AppButtonStyles.primary(),
                child: const Text('Complete profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileOptions {
  static const List<String> jobCategories = [
    'Restaurant & Food Service',
    'Retail & Stores',
    'Events',
    'Warehouse & Logistics',
    'Delivery & Driving',
    'Cleaning & Maintenance',
    'Office & Admin',
    'Hospitality & Hotels',
    'Customer Service',
    'Other',
  ];

  static const List<String> roles = [
    'Waiter',
    'Bartender',
    'Kitchen Assistant',
    'Barista',
    'Cashier',
    'Sales Associate',
    'Event Staff',
    'Cleaner',
    'Driver',
    'Customer Support',
    'General Helper',
  ];

  static const List<String> skills = [
    'Customer Service',
    'Cash Handling',
    'Food Service',
    'Cleaning',
    'Heavy Lifting',
    'Driving',
    'Computer Skills',
    'Multilingual',
    'Time Management',
    'Teamwork',
    'Reliability',
    'Fast Learner',
  ];

  static const List<String> jobTypes = [
    'One-time shifts',
    'Temporary jobs',
    'Weekend jobs',
    'Flexible part-time',
  ];

  static const List<String> experienceLevels = [
    'No experience',
    'Beginner',
    'Some experience',
    'Experienced',
  ];

  static const List<String> availableDays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const List<String> shiftTypes = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
  ];

  static const List<String> experienceCategories = [
    'Restaurant',
    'Retail',
    'Events',
    'Warehouse',
    'Cleaning',
    'Delivery',
    'Office Support',
  ];
}

String _readString(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is num) return value.toString();
  return fallback;
}

bool _readBool(Map<String, dynamic> data, String key, [bool fallback = false]) {
  final value = data[key];
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

double _readDouble(
  Map<String, dynamic> data,
  String key, [
  double fallback = 0,
]) {
  final value = data[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _readStringList(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return [];
}

Map<String, dynamic> _readMap(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> _readExperienceList(Map<String, dynamic> profile) {
  final value = profile['pastWorkExperience'] ?? profile['pastExperiences'];
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return [];
}

String _locationLabel(Map<String, dynamic> profile) {
  final city = _readString(profile, 'city');
  final preferredLocation = _readString(profile, 'preferredLocation');
  final address = _readString(profile, 'address');
  if (city.isNotEmpty) return city;
  if (preferredLocation.isNotEmpty) return preferredLocation;
  if (address.isNotEmpty) return address;
  return _readBool(profile, 'locationPermissionGranted') ||
          _readMap(profile, 'location').isNotEmpty
      ? 'Location set'
      : 'Location';
}

String _shortDays(List<String> days) {
  const abbreviations = {
    'Sunday': 'Sun',
    'Monday': 'Mon',
    'Tuesday': 'Tue',
    'Wednesday': 'Wed',
    'Thursday': 'Thu',
    'Friday': 'Fri',
    'Saturday': 'Sat',
  };
  return days.take(2).map((day) => abbreviations[day] ?? day).join(', ');
}

List<String> _missingProfileElements(Map<String, dynamic> profile) {
  final missing = <String>[];
  if (_readString(profile, 'profileImageUrl').isEmpty) {
    missing.add('Add a profile photo');
  }
  if (_readStringList(profile, 'preferredRoles').isEmpty &&
      _readStringList(profile, 'jobCategories').isEmpty) {
    missing.add('Add preferred roles or job categories');
  }
  if (_readStringList(profile, 'skills').length < 3) {
    missing.add('Add more skills');
  }
  if (!_readBool(
        profile,
        'availableNow',
        _readBool(profile, 'isAvailableNow'),
      ) &&
      _readStringList(profile, 'availableDays').isEmpty) {
    missing.add('Add availability information');
  }
  if (_readDouble(profile, 'preferredWorkRadiusKm') <= 0 &&
      !_readBool(profile, 'locationPermissionGranted') &&
      _readMap(profile, 'location').isEmpty) {
    missing.add('Add location or work radius');
  }
  if (_readString(profile, 'shortBio').isEmpty) {
    missing.add('Add a work bio');
  }
  if (_readExperienceList(profile).isEmpty &&
      _readString(profile, 'experienceLevel').isEmpty) {
    missing.add('Add experience information');
  }
  return missing;
}

int _calculateCompletion(Map<String, dynamic> profile) {
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

  var completed = 0;
  for (final field in fields) {
    final value = profile[field];
    if (value == null) continue;
    if (value is List && value.isNotEmpty) completed++;
    if (value is String && value.trim().isNotEmpty) completed++;
    if (value is num && value != 0) completed++;
    if (value is bool) completed++;
    if (value is Map && value.isNotEmpty) completed++;
  }
  return ((completed / fields.length) * 100).clamp(0, 100).round();
}

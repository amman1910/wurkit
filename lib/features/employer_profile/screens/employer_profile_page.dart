import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_ui.dart';
import '../../auth/screens/welcome_page.dart';
import '../../auth/services/auth_service.dart';
import '../../reviews/screens/user_reviews_list.dart';
import '../../reviews/widgets/user_rating_summary.dart';
import '../services/employer_profile_service.dart';
import 'employer_business_info_page.dart';

class EmployerProfilePage extends StatefulWidget {
  const EmployerProfilePage({super.key});

  @override
  State<EmployerProfilePage> createState() => _EmployerProfilePageState();
}

class _EmployerProfilePageState extends State<EmployerProfilePage> {
  final EmployerProfileService _service = EmployerProfileService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingLogo = false;
  bool _isDeletingAccount = false;

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BusinessHeaderCard(
                    profile: profile,
                    isUploadingLogo: _isUploadingLogo,
                    onEditLogo: _updateBusinessLogo,
                  ),
                  const SizedBox(height: 10),
                  _ReviewsSection(
                    userId: FirebaseAuth.instance.currentUser?.uid,
                  ),
                  const SizedBox(height: 10),
                  _ProfileCompletionCard(
                    profile: profile,
                    onTap: () => _showBusinessProfileSummarySheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _BusinessInfoCard(
                    profile: profile,
                    onEdit: () => _showEditBusinessInfoSheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _LocationCard(
                    profile: profile,
                    onEdit: () => _showEditLocationSheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _HiringPreferencesCard(
                    profile: profile,
                    onEdit: () => _showEditHiringPreferencesSheet(profile),
                  ),
                  const SizedBox(height: 10),
                  _PublicBusinessNoteCard(
                    profile: profile,
                    onEdit: () => _showEditPublicBusinessNoteSheet(profile),
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

  Future<void> _updateBusinessLogo() async {
    if (_isUploadingLogo) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingLogo = true);
      final imageUrl = await _service.uploadEmployerBusinessLogo(
        imageFile: File(pickedFile.path),
      );
      await _saveProfileUpdates({'businessLogoUrl': imageUrl});
      if (!mounted) return;
      _showSnackBar('Business logo updated.');
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Could not update business logo.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _saveProfileUpdates(Map<String, dynamic> data) {
    return _service.updateCurrentEmployerProfile(data);
  }

  void _showBusinessProfileSummarySheet(Map<String, dynamic> profile) {
    final completion = _calculateCompletion(profile);
    final missing = _missingProfileElements(profile);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileSheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(
                title: 'Business Profile Summary',
                onClose: () => Navigator.pop(context),
              ),
              Text(
                '$completion% complete',
                style: const TextStyle(
                  color: AppColors.coralAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              const _SheetLabel('What improves trust'),
              const _CompletionSummaryRow('Business logo'),
              const _CompletionSummaryRow('Business info'),
              const _CompletionSummaryRow('Location'),
              const _CompletionSummaryRow('Hiring preferences'),
              const _CompletionSummaryRow('Public business note'),
              const SizedBox(height: 18),
              if (missing.isEmpty) ...[
                const Text(
                  'Your business profile is complete.',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Workers can now see the key information they need before applying.',
                  style: TextStyle(color: AppColors.lightText, height: 1.35),
                ),
              ] else ...[
                const _SheetLabel('Missing'),
                ...missing.map((item) => _MissingSummaryRow(item)),
                const SizedBox(height: 10),
                const Text(
                  'A complete profile helps workers understand your business and improves candidate quality.',
                  style: TextStyle(color: AppColors.lightText, height: 1.35),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditBusinessInfoSheet(Map<String, dynamic> profile) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _EditBusinessInfoSheet(profile: profile, onSave: _saveProfileUpdates),
    );
    if (!mounted) return;
    if (result == true) {
      _showSnackBar('Business info updated.');
    }
  }

  Future<void> _showEditLocationSheet(Map<String, dynamic> profile) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditLocationSheet(
        profile: profile,
        onSave: _saveProfileUpdates,
        onDetectLocation: () async {
          await _service.requestLocationPermission();
          return _service.getCurrentPosition();
        },
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _showSnackBar('Location updated.');
    }
  }

  void _showEditHiringPreferencesSheet(Map<String, dynamic> profile) {
    final categories = _readStringList(profile, 'hiringCategories');
    final skills = _readStringList(profile, 'requiredSkills');
    final shiftTypes = _readStringList(profile, 'typicalShiftTypes');
    var urgentHiring = _readBool(profile, 'urgentHiringEnabled');
    var shortNotice = _readBool(profile, 'usuallyNeedsShortNoticeWorkers');
    String? selectedExperience =
        _readString(profile, 'preferredExperienceLevel').isEmpty
        ? null
        : _readString(profile, 'preferredExperienceLevel');

    _showProfileBottomSheet(
      title: 'Hiring Preferences',
      builder: (context, setSaving) {
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
                  'hiringCategories': categories,
                  'requiredSkills': skills,
                  'typicalShiftTypes': shiftTypes,
                  'preferredExperienceLevel': selectedExperience ?? '',
                  'urgentHiringEnabled': urgentHiring,
                  'usuallyNeedsShortNoticeWorkers': shortNotice,
                });
                if (!context.mounted || !mounted) return;
                Navigator.pop(context);
                _showSnackBar('Hiring preferences updated.');
              } catch (_) {
                if (mounted) {
                  _showSnackBar(
                    'Could not save hiring preferences.',
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
                  title: 'Hiring categories',
                  options: _EmployerProfileOptions.hiringCategories,
                  selected: categories,
                  onToggle: toggle,
                ),
                _MultiSelectBlock(
                  title: 'Required skills',
                  options: _EmployerProfileOptions.requiredSkills,
                  selected: skills,
                  onToggle: toggle,
                ),
                _MultiSelectBlock(
                  title: 'Shift types',
                  options: _EmployerProfileOptions.shiftTypes,
                  selected: shiftTypes,
                  onToggle: toggle,
                ),
                _ChoiceBlock(
                  title: 'Preferred experience',
                  options: _EmployerProfileOptions.experienceLevels,
                  selected: selectedExperience,
                  onSelect: (value) =>
                      localSetState(() => selectedExperience = value),
                ),
                _SwitchRow(
                  title: 'Urgent hiring',
                  value: urgentHiring,
                  onChanged: (value) =>
                      localSetState(() => urgentHiring = value),
                ),
                _SwitchRow(
                  title: 'Short notice workers',
                  value: shortNotice,
                  onChanged: (value) =>
                      localSetState(() => shortNotice = value),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditPublicBusinessNoteSheet(
    Map<String, dynamic> profile,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPublicBusinessNoteSheet(
        profile: profile,
        onSave: _saveProfileUpdates,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _showSnackBar('Public business note updated.');
    }
  }

  void _showProfileBottomSheet({
    required String title,
    required Widget Function(BuildContext context, ValueChanged<bool> setSaving)
    builder,
    VoidCallback? onClosed,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var isSaving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _ProfileSheetFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHeader(
                    title: title,
                    onClose: () => Navigator.pop(context),
                  ),
                  builder(
                    context,
                    (value) => setSheetState(() => isSaving = value),
                  ),
                  if (isSaving)
                    const LinearProgressIndicator(
                      color: AppColors.coralAccent,
                      backgroundColor: AppColors.border,
                    ),
                ],
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
      if (!mounted) return;
      _showSnackBar('Could not log out. Please try again.', isError: true);
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !_isDeletingAccount,
      builder: (context) {
        final controller = TextEditingController();
        var canDelete = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text(
                'Delete account',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This action is permanent. Your business profile and access will be deleted. Your open jobs will be closed or hidden.',
                    style: TextStyle(color: AppColors.lightText, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Applications, matches, and chats may remain as historical records but will be anonymized for the other side. You will be signed out after deletion.',
                    style: TextStyle(color: AppColors.lightText, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.white),
                    decoration: AppInputDecorations.authField(
                      label: 'Type DELETE to confirm',
                    ).copyWith(fillColor: AppColors.navyBg.withOpacity(0.5)),
                    onChanged: (value) {
                      setDialogState(() => canDelete = value == 'DELETE');
                    },
                  ),
                ],
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
                  onPressed: canDelete
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: canDelete
                          ? Colors.redAccent
                          : AppColors.lightText.withOpacity(0.45),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || _isDeletingAccount) return;

    setState(() => _isDeletingAccount = true);
    try {
      await _service.deleteEmployerAccount();
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    } on EmployerAccountDeletionException catch (error) {
      if (!mounted) return;
      final message = error.isUnauthenticated
          ? 'Please sign in again to delete your account.'
          : error.isPermissionDenied
          ? 'Only employer accounts can be deleted from this screen.'
          : 'Could not delete account. Please try again.';
      _showSnackBar(message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        'Could not delete account. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.surface,
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

class _BusinessHeaderCard extends StatelessWidget {
  const _BusinessHeaderCard({
    required this.profile,
    required this.isUploadingLogo,
    required this.onEditLogo,
  });

  final Map<String, dynamic> profile;
  final bool isUploadingLogo;
  final VoidCallback onEditLogo;

  @override
  Widget build(BuildContext context) {
    final businessName = _readString(
      profile,
      'businessName',
      'Business profile',
    );
    final businessType = _readString(profile, 'businessType', 'Not added yet');
    final logoUrl = _readString(profile, 'businessLogoUrl');
    final urgentHiring = _readBool(profile, 'urgentHiringEnabled');

    return _PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GestureDetector(
            onTap: onEditLogo,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.coralAccent.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.coralAccent.withOpacity(0.28),
                    ),
                  ),
                  child: ClipOval(
                    child: logoUrl.isNotEmpty
                        ? Image.network(
                            logoUrl,
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const _BusinessLogoFallback(),
                          )
                        : const _BusinessLogoFallback(),
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
                    child: isUploadingLogo
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.coralAccent,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.coralAccent,
                            size: 15,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  businessType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.lightText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (urgentHiring) ...[
                  const SizedBox(height: 9),
                  const _CompactStatusChip(
                    label: 'Urgent hiring enabled',
                    color: Colors.green,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessLogoFallback extends StatelessWidget {
  const _BusinessLogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.storefront_rounded,
      color: AppColors.coralAccent,
      size: 34,
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
        borderRadius: BorderRadius.circular(18),
        child: _PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Business profile strength',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$completion%',
                    style: const TextStyle(
                      color: AppColors.coralAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.lightText,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: completion / 100,
                  minHeight: 7,
                  backgroundColor: AppColors.navyBg.withOpacity(0.55),
                  color: AppColors.coralAccent,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Complete your profile to improve trust and candidate quality.',
                style: TextStyle(color: AppColors.lightText, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessInfoCard extends StatelessWidget {
  const _BusinessInfoCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final description = _readString(
      profile,
      'businessDescription',
      'Not added yet',
    );

    return _SectionCard(
      icon: Icons.apartment_rounded,
      title: 'Business Info',
      onEdit: onEdit,
      child: Column(
        children: [
          _InfoTile(
            label: 'Business name',
            value: _readString(profile, 'businessName', 'Not added yet'),
          ),
          _InfoTile(
            label: 'Business type',
            value: _readString(profile, 'businessType', 'Not added yet'),
          ),
          _InfoTile(
            label: 'Phone',
            value: _readString(profile, 'businessPhone', 'Not added yet'),
          ),
          _InfoTile(
            label: 'Email',
            value: _readString(profile, 'businessEmail', 'Not added yet'),
          ),
          _InfoTile(label: 'Description', value: description, maxLines: 2),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final location = _readMap(profile, 'location');
    final hasLocation =
        _readNullableDouble(location, 'lat') != null &&
        _readNullableDouble(location, 'lng') != null;

    return _SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Location',
      onEdit: onEdit,
      child: Column(
        children: [
          _InfoTile(
            label: 'Address',
            value: _readString(profile, 'businessAddress', 'Not added yet'),
          ),
          _InfoTile(
            label: 'City',
            value: _readString(profile, 'city', 'Not added yet'),
          ),
          _InfoTile(
            label: 'Physical business',
            value: _readBool(profile, 'isPhysicalBusiness') ? 'Yes' : 'No',
          ),
          _InfoTile(
            label: 'Location status',
            value: hasLocation ? 'Location enabled' : 'Location not enabled',
            valueColor: hasLocation ? Colors.green : AppColors.lightText,
          ),
        ],
      ),
    );
  }
}

class _HiringPreferencesCard extends StatelessWidget {
  const _HiringPreferencesCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.tune_rounded,
      title: 'Hiring Preferences',
      onEdit: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChipGroup(
            label: 'Hiring categories',
            chips: _readStringList(profile, 'hiringCategories'),
          ),
          const SizedBox(height: 12),
          _ChipGroup(
            label: 'Required skills',
            chips: _readStringList(profile, 'requiredSkills'),
          ),
          const SizedBox(height: 12),
          _ChipGroup(
            label: 'Shift types',
            chips: _readStringList(profile, 'typicalShiftTypes'),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            label: 'Preferred experience',
            value: _readString(
              profile,
              'preferredExperienceLevel',
              'Not added yet',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CompactStatusChip(
                label: _readBool(profile, 'urgentHiringEnabled')
                    ? 'Urgent hiring'
                    : 'Urgent hiring off',
                color: _readBool(profile, 'urgentHiringEnabled')
                    ? Colors.green
                    : AppColors.lightText,
              ),
              _CompactStatusChip(
                label: _readBool(profile, 'usuallyNeedsShortNoticeWorkers')
                    ? 'Short notice'
                    : 'Short notice off',
                color: _readBool(profile, 'usuallyNeedsShortNoticeWorkers')
                    ? Colors.green
                    : AppColors.lightText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PublicBusinessNoteCard extends StatelessWidget {
  const _PublicBusinessNoteCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.description_outlined,
      title: 'Public Business Note',
      onEdit: onEdit,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.navyBg.withOpacity(0.42),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.45)),
        ),
        child: Text(
          _readString(profile, 'publicBusinessNote', 'Not added yet'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.lightText,
            fontSize: 13,
            height: 1.32,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.onEdit,
    required this.child,
  });

  final IconData icon;
  final String title;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.coralAccent, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.coralAccent,
                tooltip: 'Edit',
              ),
            ],
          ),
          Divider(color: AppColors.border.withOpacity(0.45), height: 10),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.surface, AppColors.navyBg, 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withOpacity(0.55)),
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.lightText, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? AppColors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.label, required this.chips});

  final String label;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.lightText, fontSize: 12),
        ),
        const SizedBox(height: 7),
        if (chips.isEmpty)
          const Text(
            'Not selected yet',
            style: TextStyle(color: AppColors.lightText, fontSize: 13),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips.take(8).map((chip) => _CompactChip(chip)).toList(),
          ),
      ],
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withOpacity(0.13),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.coralAccent.withOpacity(0.32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.coralAccent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactStatusChip extends StatelessWidget {
  const _CompactStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileSheetFrame extends StatelessWidget {
  const _ProfileSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(AppColors.navyBg, AppColors.surface, 0.72),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border.withOpacity(0.55)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          color: AppColors.lightText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children,
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onSave,
            style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditBusinessInfoSheet extends StatefulWidget {
  const _EditBusinessInfoSheet({required this.profile, required this.onSave});

  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  @override
  State<_EditBusinessInfoSheet> createState() => _EditBusinessInfoSheetState();
}

class _EditBusinessInfoSheetState extends State<_EditBusinessInfoSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _readString(widget.profile, 'businessName'),
    );
    _typeController = TextEditingController(
      text: _readString(widget.profile, 'businessType'),
    );
    _phoneController = TextEditingController(
      text: _readString(widget.profile, 'businessPhone'),
    );
    _emailController = TextEditingController(
      text: _readString(widget.profile, 'businessEmail'),
    );
    _descriptionController = TextEditingController(
      text: _readString(widget.profile, 'businessDescription'),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final businessName = _nameController.text.trim();
    final businessType = _typeController.text.trim();
    final businessPhone = _phoneController.text.trim();
    final businessEmail = _emailController.text.trim();
    final businessDescription = _descriptionController.text.trim();

    if (businessName.isEmpty || businessType.isEmpty || businessPhone.isEmpty) {
      _showSheetSnackBar('Business name, type, and phone are required.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave({
        'businessName': businessName,
        'businessType': businessType,
        'businessPhone': businessPhone,
        'businessEmail': businessEmail,
        'businessDescription': businessDescription,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSheetSnackBar('Could not save business info.');
    }
  }

  void _showSheetSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: AppColors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TextEditorSheetScaffold(
      title: 'Business Info',
      isSaving: _isSaving,
      child: _SheetContent(
        onSave: _handleSave,
        children: [
          _SheetTextField(controller: _nameController, label: 'Business name'),
          _SheetTextField(controller: _typeController, label: 'Business type'),
          _SheetTextField(controller: _phoneController, label: 'Phone'),
          _SheetTextField(controller: _emailController, label: 'Email'),
          _SheetTextField(
            controller: _descriptionController,
            label: 'Business description',
            minLines: 3,
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}

class _EditLocationSheet extends StatefulWidget {
  const _EditLocationSheet({
    required this.profile,
    required this.onSave,
    required this.onDetectLocation,
  });

  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic> data) onSave;
  final Future<Position> Function() onDetectLocation;

  @override
  State<_EditLocationSheet> createState() => _EditLocationSheetState();
}

class _EditLocationSheetState extends State<_EditLocationSheet> {
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late bool _isPhysicalBusiness;
  late bool _locationPermissionGranted;
  double? _latitude;
  double? _longitude;
  bool _isSaving = false;
  bool _isDetectingLocation = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: _readString(widget.profile, 'businessAddress'),
    );
    _cityController = TextEditingController(
      text: _readString(widget.profile, 'city'),
    );
    _isPhysicalBusiness = _readBool(widget.profile, 'isPhysicalBusiness');
    _locationPermissionGranted = _readBool(
      widget.profile,
      'locationPermissionGranted',
    );
    final location = _readMap(widget.profile, 'location');
    _latitude = _readNullableDouble(location, 'lat');
    _longitude = _readNullableDouble(location, 'lng');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final position = await widget.onDetectLocation();
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = true;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isDetectingLocation = false;
      });
      _showSheetSnackBar('Location detected.', isError: false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationPermissionGranted = false;
        _isDetectingLocation = false;
      });
      _showSheetSnackBar('Could not detect location.');
    }
  }

  Future<void> _handleSave() async {
    final update = <String, dynamic>{
      'businessAddress': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'isPhysicalBusiness': _isPhysicalBusiness,
      'locationPermissionGranted': _locationPermissionGranted,
      if (_latitude != null && _longitude != null)
        'location': {'lat': _latitude, 'lng': _longitude},
    };

    setState(() => _isSaving = true);
    try {
      await widget.onSave(update);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSheetSnackBar('Could not save location.');
    }
  }

  void _showSheetSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? AppColors.white : AppColors.navyBg,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : AppColors.coralAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _TextEditorSheetScaffold(
      title: 'Location',
      isSaving: _isSaving,
      child: _SheetContent(
        onSave: _handleSave,
        children: [
          _SheetTextField(
            controller: _addressController,
            label: 'Business address',
          ),
          _SheetTextField(controller: _cityController, label: 'City'),
          _SwitchRow(
            title: 'Physical business',
            value: _isPhysicalBusiness,
            onChanged: (value) => setState(() => _isPhysicalBusiness = value),
          ),
          OutlinedButton.icon(
            onPressed: _isDetectingLocation ? null : _detectLocation,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coralAccent,
              side: BorderSide(color: AppColors.coralAccent.withOpacity(0.55)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: _isDetectingLocation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.coralAccent,
                    ),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              _latitude != null && _longitude != null
                  ? 'Location detected'
                  : 'Detect location',
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _EditPublicBusinessNoteSheet extends StatefulWidget {
  const _EditPublicBusinessNoteSheet({
    required this.profile,
    required this.onSave,
  });

  final Map<String, dynamic> profile;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  @override
  State<_EditPublicBusinessNoteSheet> createState() =>
      _EditPublicBusinessNoteSheetState();
}

class _EditPublicBusinessNoteSheetState
    extends State<_EditPublicBusinessNoteSheet> {
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text: _readString(widget.profile, 'publicBusinessNote'),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final publicBusinessNote = _noteController.text.trim();

    setState(() => _isSaving = true);
    try {
      await widget.onSave({'publicBusinessNote': publicBusinessNote});
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save business note.',
            style: TextStyle(color: AppColors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TextEditorSheetScaffold(
      title: 'Public Business Note',
      isSaving: _isSaving,
      child: _SheetContent(
        onSave: _handleSave,
        children: [
          _SheetTextField(
            controller: _noteController,
            label: 'Public business note',
            minLines: 4,
            maxLines: 7,
          ),
        ],
      ),
    );
  }
}

class _TextEditorSheetScaffold extends StatelessWidget {
  const _TextEditorSheetScaffold({
    required this.title,
    required this.child,
    required this.isSaving,
  });

  final String title;
  final Widget child;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return _ProfileSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(
            title: title,
            onClose: isSaving ? () {} : () => Navigator.pop(context, false),
          ),
          AbsorbPointer(
            absorbing: isSaving,
            child: Opacity(opacity: isSaving ? 0.62 : 1, child: child),
          ),
          if (isSaving)
            const LinearProgressIndicator(
              color: AppColors.coralAccent,
              backgroundColor: AppColors.border,
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
    return _ActionCard(
      icon: Icons.logout_rounded,
      iconColor: AppColors.coralAccent,
      title: 'Log out',
      subtitle: 'Sign out of your WURKIT account',
      onTap: onTap,
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
    return _ActionCard(
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.redAccent,
      title: 'Delete account',
      subtitle: 'Permanently delete your WURKIT employer account',
      onTap: onTap,
      isLoading: isLoading,
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

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
                  color: iconColor.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.32)),
                ),
                child: isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: iconColor == Colors.redAccent
                            ? iconColor
                            : AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
                'Something went wrong while loading your business profile.',
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
                Icons.storefront_rounded,
                color: AppColors.coralAccent,
                size: 44,
              ),
              const SizedBox(height: 14),
              const Text(
                'We could not find your business profile.',
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
                      builder: (_) => const EmployerBusinessInfoPage(),
                    ),
                  );
                },
                style: AppButtonStyles.primary(),
                child: const Text('Complete business profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployerProfileOptions {
  static const List<String> hiringCategories = [
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

  static const List<String> requiredSkills = [
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

  static const List<String> shiftTypes = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
    'Weekend',
    'Holiday',
  ];

  static const List<String> experienceLevels = [
    'No experience',
    'Beginner',
    'Some experience',
    'Experienced',
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

double? _readNullableDouble(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<String> _missingProfileElements(Map<String, dynamic> profile) {
  final missing = <String>[];
  if (_readString(profile, 'businessLogoUrl').isEmpty) {
    missing.add('Add a business logo');
  }
  if (_readString(profile, 'businessName').isEmpty ||
      _readString(profile, 'businessType').isEmpty ||
      _readString(profile, 'businessPhone').isEmpty) {
    missing.add('Complete business info');
  }
  if (_readString(profile, 'businessEmail').isEmpty) {
    missing.add('Add business email');
  }
  if (_readString(profile, 'businessAddress').isEmpty ||
      _readString(profile, 'city').isEmpty ||
      _readMap(profile, 'location').isEmpty) {
    missing.add('Enable location');
  }
  if (_readStringList(profile, 'hiringCategories').length < 2) {
    missing.add('Add more hiring categories');
  }
  if (_readStringList(profile, 'requiredSkills').isEmpty ||
      _readStringList(profile, 'typicalShiftTypes').isEmpty ||
      _readString(profile, 'preferredExperienceLevel').isEmpty) {
    missing.add('Complete hiring preferences');
  }
  if (_readString(profile, 'publicBusinessNote').isEmpty) {
    missing.add('Add public business note');
  }
  return missing;
}

int _calculateCompletion(Map<String, dynamic> profile) {
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
    'preferredExperienceLevel',
    'publicBusinessNote',
  ];

  var completed = 0;
  for (final field in fields) {
    final value = profile[field];
    if (value == null) continue;
    if (value is String && value.trim().isNotEmpty) completed++;
    if (value is List && value.isNotEmpty) completed++;
    if (value is Map && value.isNotEmpty) completed++;
    if (value is num && value > 0) completed++;
    if (value is bool) completed++;
  }

  return ((completed / fields.length) * 100).clamp(0, 100).round();
}

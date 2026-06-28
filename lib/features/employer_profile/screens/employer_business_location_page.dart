import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_ui.dart';
import '../../../shared/models/resolved_address.dart';
import '../../../shared/utils/address_format_utils.dart';
import '../../../shared/widgets/address_autocomplete_field.dart';
import '../services/employer_profile_service.dart';
import 'employer_hiring_preferences_page.dart';

class EmployerBusinessLocationPage extends StatefulWidget {
  final bool isEditing;

  const EmployerBusinessLocationPage({super.key, this.isEditing = false});

  @override
  State<EmployerBusinessLocationPage> createState() =>
      _EmployerBusinessLocationPageState();
}

class _EmployerBusinessLocationPageState
    extends State<EmployerBusinessLocationPage>
    with SingleTickerProviderStateMixin {
  final EmployerProfileService _profileService = EmployerProfileService();
  final TextEditingController _businessAddressController =
      TextEditingController();
  final GlobalKey<AddressAutocompleteFieldState> _addressFieldKey = GlobalKey();

  bool _isLoading = false;
  bool _isPreloading = true;
  bool _isFormComplete = false;
  bool _isPhysicalBusiness = true;
  ResolvedAddress? _resolvedAddress;

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
    _businessAddressController.addListener(_updateFormComplete);
    _animationController.forward();
    _loadExistingProfile();
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
      CurvedAnimation(parent: _animationController, curve: intervals[index]),
    );
  }

  @override
  void dispose() {
    _businessAddressController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updateFormComplete() {
    final isComplete = !_isPhysicalBusiness || _resolvedAddress != null;

    if (_isFormComplete != isComplete) {
      setState(() {
        _isFormComplete = isComplete;
      });
    }
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await _profileService.getEmployerProfile();
      if (!mounted) return;

      if (profile != null) {
        _businessAddressController.text = _readString(
          profile,
          'businessAddress',
        );
        _isPhysicalBusiness = _readBool(
          profile,
          'isPhysicalBusiness',
          _isPhysicalBusiness,
        );
        final location = profile['businessLocation'] ?? profile['location'];
        final placeId = _readString(profile, 'businessPlaceId');
        if (location is Map && placeId.isNotEmpty) {
          final latitude = _readNullableDouble(location['lat']);
          final longitude = _readNullableDouble(location['lng']);
          if (latitude != null && longitude != null) {
            _resolvedAddress = ResolvedAddress(
              formattedAddress: _businessAddressController.text,
              placeId: placeId,
              latitude: latitude,
              longitude: longitude,
              country: _readString(profile, 'businessCountry'),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not load your saved business location.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPreloading = false);
        _updateFormComplete();
      }
    }
  }

  String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value == null ? '' : value.toString();
  }

  bool _readBool(Map<String, dynamic> data, String key, bool fallback) {
    final value = data[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  double? _readNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  Future<void> _handleContinue() async {
    final address = _businessAddressController.text.trim();
    final resolved = _resolvedAddress;

    if (_isPhysicalBusiness && resolved == null) {
      _showError('Please select a valid address from the list.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _profileService.saveBusinessLocation(
        businessAddress: _isPhysicalBusiness
            ? formatAddressForDisplay(address)
            : null,
        isPhysicalBusiness: _isPhysicalBusiness,
        locationPermissionGranted: false,
        placeId: _isPhysicalBusiness ? resolved?.placeId : null,
        country: _isPhysicalBusiness ? resolved?.country : null,
        latitude: _isPhysicalBusiness ? resolved?.latitude : null,
        longitude: _isPhysicalBusiness ? resolved?.longitude : null,
      );

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployerHiringPreferencesPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save location: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isPreloading;
    final canContinue = !isBusy && _isFormComplete;

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
                Image.asset('assets/images/wurkit_logo.png', height: 92),
              ),
              const SizedBox(height: 18),
              _buildAnimatedItem(
                1,
                Column(
                  children: [
                    Text(
                      'Where is your business located?',
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
                      'This helps us connect you with nearby available workers.',
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
              _buildAnimatedItem(
                2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isPhysicalBusiness)
                      AddressAutocompleteField(
                        key: _addressFieldKey,
                        controller: _businessAddressController,
                        enabled: !isBusy,
                        decoration: AppInputDecorations.authField(
                          label: 'Business address',
                          hint: 'Start typing and select an address',
                        ),
                        initialAddress: _resolvedAddress,
                        onAddressChanged: (address) {
                          setState(() {
                            _resolvedAddress = address;
                          });
                          _updateFormComplete();
                        },
                      ),
                    const SizedBox(height: AppSpacing.field),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.field),
              _buildAnimatedItem(
                4,
                SwitchListTile(
                  title: Text(
                    'This business has a physical location',
                    style: AppTextStyles.body.copyWith(color: AppColors.white),
                  ),
                  value: _isPhysicalBusiness,
                  onChanged: isBusy
                      ? null
                      : (value) {
                          setState(() {
                            _isPhysicalBusiness = value;
                          });
                          _updateFormComplete();
                        },
                  activeColor: AppColors.coralAccent,
                  activeTrackColor: AppColors.coralAccent.withOpacity(0.3),
                  inactiveThumbColor: AppColors.border,
                  inactiveTrackColor: AppColors.border.withOpacity(0.3),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 32),
              _buildAnimatedItem(
                6,
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: canContinue ? _handleContinue : null,
                    style: AppButtonStyles.primary(
                      backgroundColor: AppColors.coralAccent,
                      foregroundColor: AppColors.navyBg,
                      disabledBackgroundColor: AppColors.coralAccent
                          .withOpacity(0.35),
                    ),
                    child: isBusy
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.navyBg,
                            ),
                          )
                        : Text(
                            widget.isEditing ? 'Save changes' : 'Continue',
                            style: AppTextStyles.buttonLabel(
                              color: AppColors.navyBg,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

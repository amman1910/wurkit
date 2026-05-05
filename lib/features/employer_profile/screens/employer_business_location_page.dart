import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_ui.dart';
import '../services/employer_profile_service.dart';
import 'employer_hiring_preferences_page.dart';

class EmployerBusinessLocationPage extends StatefulWidget {
  final bool isEditing;

  const EmployerBusinessLocationPage({super.key, this.isEditing = false});

  @override
  State<EmployerBusinessLocationPage> createState() => _EmployerBusinessLocationPageState();
}

class _EmployerBusinessLocationPageState extends State<EmployerBusinessLocationPage>
    with SingleTickerProviderStateMixin {
  final EmployerProfileService _profileService = EmployerProfileService();
  final TextEditingController _businessAddressController = TextEditingController();

  bool _isLoading = false;
  bool _isPreloading = true;
  bool _isFormComplete = false;
  bool _isPhysicalBusiness = true;
  bool _isDetectingLocation = false;
  String? _selectedCity;
  double? _latitude;
  double? _longitude;
  bool _locationCaptured = false;

  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  static final List<String> _cities = [
    'Jerusalem',
    'Tel Aviv',
    'Haifa',
    'Beersheba',
    'Rishon LeZion',
    'Petah Tikva',
    'Netanya',
    'Ashdod',
    'Ashkelon',
    'Nazareth',
    'Eilat',
  ];

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
      CurvedAnimation(
        parent: _animationController,
        curve: intervals[index],
      ),
    );
  }

  @override
  void dispose() {
    _businessAddressController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _updateFormComplete() {
    final addressValid = _businessAddressController.text.trim().isNotEmpty;
    final cityValid = _selectedCity != null;
    final isComplete = addressValid && cityValid;

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
        _businessAddressController.text = _readString(profile, 'businessAddress');
        final city = _readString(profile, 'city');
        if (city.isNotEmpty) {
          if (!_cities.contains(city)) {
            _cities.add(city);
          }
          _selectedCity = city;
        }
        _isPhysicalBusiness = _readBool(profile, 'isPhysicalBusiness', _isPhysicalBusiness);
        _locationCaptured = _readBool(profile, 'locationPermissionGranted', false);

        final location = profile['location'];
        if (location is Map) {
          _latitude = _readNullableDouble(location['lat']);
          _longitude = _readNullableDouble(location['lng']);
          _locationCaptured = _latitude != null && _longitude != null;
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isDetectingLocation = true;
    });

    try {
      await _profileService.requestLocationPermission();

      final position = await _profileService.getCurrentPosition();

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _locationCaptured = true;
          _isDetectingLocation = false;
        });
        _showSuccess('Location detected');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
        _showError(e.toString());
      }
    }
  }

  Future<void> _handleContinue() async {
    final address = _businessAddressController.text.trim();
    final city = _selectedCity;

    if (address.isEmpty) {
      _showError('Please enter your business address');
      return;
    }

    if (city == null) {
      _showError('Please select your city');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _profileService.saveBusinessLocation(
        businessAddress: address,
        city: city,
        isPhysicalBusiness: _isPhysicalBusiness,
        locationPermissionGranted: _locationCaptured,
        latitude: _latitude,
        longitude: _longitude,
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
                    TextFormField(
                      controller: _businessAddressController,
                      enabled: !isBusy,
                      style: AppTextStyles.input,
                      decoration: AppInputDecorations.authField(
                        label: 'Business address',
                        hint: 'Street and number',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.field),
                    DropdownButtonFormField<String>(
                      value: _selectedCity,
                      onChanged: isBusy ? null : (String? newValue) {
                        setState(() {
                          _selectedCity = newValue;
                        });
                        _updateFormComplete();
                      },
                      items: _cities.map((city) {
                        return DropdownMenuItem<String>(
                          value: city,
                          child: Text(city),
                        );
                      }).toList(),
                      style: AppTextStyles.input,
                      decoration: AppInputDecorations.authField(
                        label: 'City',
                        hint: 'Select a city',
                      ),
                      dropdownColor: AppColors.surface,
                    ),
                    const SizedBox(height: AppSpacing.field),
                  ],
                ),
              ),
              _buildAnimatedItem(
                3,
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use current location',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.white,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_locationCaptured)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.coralAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Location captured',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.coralAccent,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isBusy || _isDetectingLocation ? null : _detectCurrentLocation,
                          icon: _isDetectingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyBg),
                                  ),
                                )
                              : const Icon(Icons.location_on_rounded),
                          label: Text(
                            _isDetectingLocation ? 'Detecting...' : 'Detect location',
                            style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coralAccent,
                            disabledBackgroundColor: AppColors.coralAccent.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Location is optional. You can continue without it.',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.lightText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.field),
              _buildAnimatedItem(
                4,
                SwitchListTile(
                  title: Text(
                    'This business has a physical location',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  value: _isPhysicalBusiness,
                  onChanged: isBusy ? null : (value) {
                    setState(() {
                      _isPhysicalBusiness = value;
                    });
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
                      disabledBackgroundColor: AppColors.coralAccent.withOpacity(0.35),
                    ),
                    child: isBusy
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.navyBg),
                          )
                        : Text(
                            widget.isEditing ? 'Save changes' : 'Continue',
                            style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
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

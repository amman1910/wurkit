import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_ui.dart';
import '../services/employee_profile_service.dart';
import 'employee_experience_summary_page.dart';

class EmployeeAvailabilityLocationPage extends StatefulWidget {
  final bool isEditing;

  const EmployeeAvailabilityLocationPage({super.key, this.isEditing = false});

  @override
  State<EmployeeAvailabilityLocationPage> createState() => _EmployeeAvailabilityLocationPageState();
}

class _EmployeeAvailabilityLocationPageState extends State<EmployeeAvailabilityLocationPage>
    with SingleTickerProviderStateMixin {
  final EmployeeProfileService _profileService = EmployeeProfileService();

  // State variables
  bool _isLoading = false;
  bool _isPreloading = true;
  bool _locationPermissionHandled = false;
  bool _locationPermissionGranted = false;
  double? _latitude;
  double? _longitude;
  String _locationStatusMessage = '';

  double _radiusKm = 10;

  bool _isAvailableNow = false;
  bool _canWorkShortNotice = false;
  bool _canWorkToday = false;

  List<String> _selectedDays = [];
  List<String> _selectedShiftTypes = [];

  // Animation
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

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

  static const List<double> radiusOptions = [2, 5, 10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _animations = List.generate(
      11, // Number of animated sections
      (index) => _createAnimation(index),
    );
    _animationController.forward();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      const Interval(0.7, 0.9, curve: Curves.easeOutCubic),
      const Interval(0.75, 0.95, curve: Curves.easeOutCubic),
      const Interval(0.8, 1.0, curve: Curves.easeOutCubic),
      const Interval(0.85, 1.0, curve: Curves.easeOutCubic),
    ];
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: intervals[index],
      ),
    );
  }

  bool get _isFormValid {
    return (widget.isEditing || _locationPermissionHandled) &&
           _selectedDays.isNotEmpty &&
           _selectedShiftTypes.isNotEmpty;
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await _profileService.getCurrentEmployeeProfile();
      if (!mounted) return;

      if (profile != null) {
        final location = profile['location'];
        _radiusKm = _readDouble(profile, 'preferredWorkRadiusKm', _radiusKm)
            .clamp(2, 30)
            .toDouble();
        _isAvailableNow = _readBool(profile, 'availableNow', _readBool(profile, 'isAvailableNow', false));
        _canWorkShortNotice = _readBool(
          profile,
          'canWorkOnShortNotice',
          _readBool(profile, 'canWorkShortNotice', false),
        );
        _canWorkToday = _readBool(profile, 'canWorkToday', false);
        _selectedDays = _readStringList(profile, 'availableDays')
            .where(availableDays.contains)
            .toList();
        _selectedShiftTypes = _readStringList(profile, 'preferredShiftTypes')
            .where(shiftTypes.contains)
            .toList();
        _locationPermissionGranted = _readBool(profile, 'locationPermissionGranted', false);
        _locationPermissionHandled = profile.containsKey('locationPermissionGranted') || location is Map;

        if (location is Map) {
          _latitude = _readNullableDouble(location['lat']);
          _longitude = _readNullableDouble(location['lng']);
        }

        if (_locationPermissionHandled) {
          _locationStatusMessage = _locationPermissionGranted
              ? 'Location enabled! We\'ll find jobs near you.'
              : 'Location access is not enabled. You can continue without location.';
        }
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not load your saved availability.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPreloading = false);
      }
    }
  }

  List<String> _readStringList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  bool _readBool(Map<String, dynamic> data, String key, bool fallback) {
    final value = data[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  double _readDouble(Map<String, dynamic> data, String key, double fallback) {
    final value = data[key];
    return _readNullableDouble(value) ?? fallback;
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

  Future<void> _handleLocationPermission() async {
    setState(() {
      _locationPermissionHandled = false;
      _locationStatusMessage = 'Checking location services...';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationPermissionHandled = true;
          _locationPermissionGranted = false;
          _locationStatusMessage = 'Location services are turned off. You can continue without location, but matches may be less accurate.';
        });
        return;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationPermissionHandled = true;
            _locationPermissionGranted = false;
            _locationStatusMessage = 'Location access denied. You can continue without location, but matches may be less accurate.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationPermissionHandled = true;
          _locationPermissionGranted = false;
          _locationStatusMessage = 'Location permission permanently denied. Please enable location permission in app settings. You can continue without location, but matches may be less accurate.';
        });
        return;
      }

      // Permission granted, get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _locationPermissionHandled = true;
        _locationPermissionGranted = true;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationStatusMessage = 'Location enabled! We\'ll find jobs near you.';
      });
    } catch (e) {
      setState(() {
        _locationPermissionHandled = true;
        _locationPermissionGranted = false;
        _locationStatusMessage = 'Unable to get location. You can continue without location, but matches may be less accurate.';
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      await _profileService.saveAvailabilityAndLocation(
        locationPermissionGranted: _locationPermissionGranted,
        latitude: _latitude,
        longitude: _longitude,
        preferredWorkRadiusKm: _radiusKm,
        isAvailableNow: _isAvailableNow,
        availableDays: _selectedDays,
        preferredShiftTypes: _selectedShiftTypes,
        canWorkShortNotice: _canWorkShortNotice,
        canWorkToday: _canWorkToday,
      );

      if (mounted) {
        if (widget.isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EmployeeExperienceSummaryPage(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save availability: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isPreloading;

    return Scaffold(
      backgroundColor: AppColors.coralAccent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Logo
              FadeTransition(
                opacity: _animations[0],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[0]),
                  child: Image.asset(
                    'assets/images/wurkit_logo_navy.png',
                    height: 70,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              FadeTransition(
                opacity: _animations[1],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[1]),
                  child: Text(
                    'When and where can you work?',
                    style: GoogleFonts.nunito(
                      color: AppColors.navyBg,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              FadeTransition(
                opacity: _animations[2],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[2]),
                  child: Text(
                    'This helps us find jobs that fit your schedule and area',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navyBg.withOpacity(0.8),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Location Access Section
              FadeTransition(
                opacity: _animations[3],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[3]),
                  child: _buildLocationSection(),
                ),
              ),

              const SizedBox(height: 24),

              // Work Radius Section
              FadeTransition(
                opacity: _animations[4],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[4]),
                  child: _buildRadiusSection(),
                ),
              ),

              const SizedBox(height: 24),

              // Availability Status Section
              FadeTransition(
                opacity: _animations[5],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[5]),
                  child: _buildAvailabilitySection(),
                ),
              ),

              const SizedBox(height: 24),

              // Available Days Section
              FadeTransition(
                opacity: _animations[6],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[6]),
                  child: _buildDaysSection(),
                ),
              ),

              const SizedBox(height: 24),

              // Shift Types Section
              FadeTransition(
                opacity: _animations[7],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[7]),
                  child: _buildShiftTypesSection(),
                ),
              ),

              const SizedBox(height: 40),

              // Continue Button
              FadeTransition(
                opacity: _animations[8],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[8]),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isFormValid && !isBusy ? _handleContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBg,
                        disabledBackgroundColor: AppColors.navyBg.withOpacity(0.45),
                        shape: const StadiumBorder(),
                      ),
                      child: isBusy
                          ? const CircularProgressIndicator(
                              color: AppColors.coralAccent,
                            )
                          : Text(
                              widget.isEditing ? 'Save changes' : 'Continue',
                              style: AppTextStyles.buttonLabel(color: AppColors.coralAccent),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Back Button
              FadeTransition(
                opacity: _animations[9],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[9]),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'Back',
                        style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: AppColors.coralAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Use your current location',
                style: GoogleFonts.nunito(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We use your location to find jobs near you',
            style: AppTextStyles.body.copyWith(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (!_locationPermissionHandled) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _handleLocationPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coralAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  'Enable location',
                  style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _locationPermissionGranted
                    ? AppColors.coralAccent.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _locationPermissionGranted
                      ? AppColors.coralAccent.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _locationPermissionGranted ? Icons.check_circle : Icons.info,
                    color: _locationPermissionGranted ? AppColors.coralAccent : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _locationStatusMessage,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadiusSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Work Radius',
            style: GoogleFonts.nunito(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How far are you willing to travel for work?',
            style: AppTextStyles.body.copyWith(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Preferred radius: ${_radiusKm.toInt()} km',
            style: GoogleFonts.nunito(
              color: AppColors.coralAccent,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Slider(
            value: _radiusKm,
            min: 2,
            max: 30,
            divisions: 5,
            activeColor: AppColors.coralAccent,
            inactiveColor: AppColors.surface.withOpacity(0.5),
            onChanged: (value) {
              setState(() {
                _radiusKm = radiusOptions.reduce((a, b) =>
                    (value - a).abs() < (value - b).abs() ? a : b);
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: radiusOptions.map((radius) {
              return Text(
                '${radius.toInt()}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability Status',
            style: GoogleFonts.nunito(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSwitchRow(
            title: 'Available now',
            subtitle: 'Ready to start working immediately',
            value: _isAvailableNow,
            onChanged: (value) => setState(() => _isAvailableNow = value),
          ),
          const SizedBox(height: 16),
          _buildSwitchRow(
            title: 'Can work on short notice',
            subtitle: 'Available for same-day or next-day jobs',
            value: _canWorkShortNotice,
            onChanged: (value) => setState(() => _canWorkShortNotice = value),
          ),
          const SizedBox(height: 16),
          _buildSwitchRow(
            title: 'Can work today',
            subtitle: 'Available for work starting today',
            value: _canWorkToday,
            onChanged: (value) => setState(() => _canWorkToday = value),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Days',
            style: GoogleFonts.nunito(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select the days you\'re available to work',
            style: AppTextStyles.body.copyWith(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableDays.map((day) {
              final isSelected = _selectedDays.contains(day);
              return FilterChip(
                label: Text(day),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  });
                },
                backgroundColor: AppColors.surface.withOpacity(0.5),
                selectedColor: AppColors.coralAccent,
                checkmarkColor: AppColors.navyBg,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.navyBg : AppColors.white,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftTypesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Shift Types',
            style: GoogleFonts.nunito(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What times of day work best for you?',
            style: AppTextStyles.body.copyWith(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shiftTypes.map((shift) {
              final isSelected = _selectedShiftTypes.contains(shift);
              return FilterChip(
                label: Text(shift),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedShiftTypes.add(shift);
                    } else {
                      _selectedShiftTypes.remove(shift);
                    }
                  });
                },
                backgroundColor: AppColors.surface.withOpacity(0.5),
                selectedColor: AppColors.coralAccent,
                checkmarkColor: AppColors.navyBg,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.navyBg : AppColors.white,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.lightText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.coralAccent,
          activeTrackColor: AppColors.coralAccent.withOpacity(0.3),
        ),
      ],
    );
  }
}

class OnboardingCompletePlaceholder extends StatelessWidget {
  const OnboardingCompletePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.coralAccent,
      body: const Center(
        child: Text(
          'Onboarding Complete!\nWelcome to Wurkit 🎉',
          style: TextStyle(color: AppColors.navyBg, fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

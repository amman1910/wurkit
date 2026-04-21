import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/theme/app_ui.dart';
import '../services/employee_profile_service.dart';
import 'employee_work_preferences_page.dart';

class EmployeeBasicInfoPage extends StatefulWidget {
  const EmployeeBasicInfoPage({super.key});

  @override
  State<EmployeeBasicInfoPage> createState() => _EmployeeBasicInfoPageState();
}

class _EmployeeBasicInfoPageState extends State<EmployeeBasicInfoPage>
    with SingleTickerProviderStateMixin {
  final EmployeeProfileService _profileService = EmployeeProfileService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = false;
  bool _isFormComplete = false;
  File? _selectedImageFile;

  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _animations = List.generate(
      8,
      (index) => _createAnimation(index),
    );
    _nameController.addListener(_updateFormComplete);
    _phoneController.addListener(_updateFormComplete);
    _ageController.addListener(_updateFormComplete);
    _animationController.forward();
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
      const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
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
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isValidPhoneNumber(String phone) {
    // Basic validation: at least 10 digits, only numbers and common separators
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length >= 10;
  }

  Future<void> _handleContinue() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final age = _ageController.text.trim();

    if (name.isEmpty || name.length < 2) {
      _showError('Please enter your name');
      return;
    }

    if (phone.isEmpty || !_isValidPhoneNumber(phone)) {
      _showError('Please enter a valid phone number');
      return;
    }

    if (age.isEmpty || int.tryParse(age) == null) {
      _showError('Please enter a valid age');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.saveBasicInfo(
        name: name,
        phoneNumber: phone,
        ageRange: age,
        profileImageUrl: null, // Placeholder
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployeeWorkPreferencesPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSkip() async {
    // TODO: Navigate to next step or allow skipping
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skipped for now')),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void _updateFormComplete() {
    final isComplete = _nameController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _ageController.text.trim().isNotEmpty;

    if (_isFormComplete != isComplete) {
      setState(() {
        _isFormComplete = isComplete;
      });
    }
  }

  Future<void> _pickAndCropImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: AppColors.navyBg,
            toolbarWidgetColor: AppColors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _selectedImageFile = File(croppedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to select or crop image: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _animations[0],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[0]),
                  child: Image.asset(
                    'assets/images/wurkit_logo_navy.png',
                    height: 100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: _animations[1],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[1]),
                  child: Text(
                    'Let’s set up your worker profile',
                    style: GoogleFonts.nunito(
                      color: AppColors.navyBg,
                      fontSize: 34,
                      fontWeight: FontWeight.w600, 
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Profile image placeholder
              FadeTransition(
                opacity: _animations[2],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[2]),
                  child: GestureDetector(
                    onTap: _pickAndCropImage,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surface,
                          backgroundImage: _selectedImageFile != null
                              ? FileImage(_selectedImageFile!)
                              : null,
                          child: _selectedImageFile == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: AppColors.white,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAndCropImage,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.navyBg,
                              child: Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: AppColors.coralAccent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _animations[3],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[3]),
                  child: Text(
                    'Add photo',
                    style: TextStyle(
                      color: AppColors.navyBg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Name field
              FadeTransition(
                opacity: _animations[4],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[4]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.input,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: AppTextStyles.input.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Phone field
              FadeTransition(
                opacity: _animations[5],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[5]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.input,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: AppTextStyles.input.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Age field
              FadeTransition(
                opacity: _animations[6],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[6]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.input,
                      border: Border.all(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: AppTextStyles.input.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Buttons
              FadeTransition(
                opacity: _animations[7],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[7]),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isFormComplete && !_isLoading ? _handleContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBg,
                        disabledBackgroundColor: AppColors.navyBg.withOpacity(0.45),
                        shape: const StadiumBorder(),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text(
                              'Continue',
                              style: AppTextStyles.buttonLabel(color: AppColors.coralAccent),
                            ),
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
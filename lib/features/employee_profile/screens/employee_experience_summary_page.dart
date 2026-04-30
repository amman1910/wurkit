import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_ui.dart';
import '../../employee_home/screens/employee_main_navigation_page.dart';
import '../services/employee_profile_service.dart';

class _ExperienceItem {
  final TextEditingController jobTitleController;
  final TextEditingController workplaceController;
  final TextEditingController durationController;
  final TextEditingController descriptionController;
  String? selectedCategory;

  _ExperienceItem({
    required this.jobTitleController,
    required this.workplaceController,
    required this.durationController,
    required this.descriptionController,
  });

  void dispose() {
    jobTitleController.dispose();
    workplaceController.dispose();
    durationController.dispose();
    descriptionController.dispose();
  }

  Map<String, dynamic> toMap() {
    return {
      'jobTitle': jobTitleController.text.trim(),
      'workplace': workplaceController.text.trim(),
      'category': selectedCategory ?? '',
      'duration': durationController.text.trim(),
      'description': descriptionController.text.trim(),
    };
  }
}

class EmployeeExperienceSummaryPage extends StatefulWidget {
  const EmployeeExperienceSummaryPage({super.key});

  @override
  State<EmployeeExperienceSummaryPage> createState() =>
      _EmployeeExperienceSummaryPageState();
}

class _EmployeeExperienceSummaryPageState extends State<EmployeeExperienceSummaryPage>
    with SingleTickerProviderStateMixin {
  final EmployeeProfileService _profileService = EmployeeProfileService();
  final TextEditingController _bioController = TextEditingController();

  final List<_ExperienceItem> _experiences = [];
  bool _isLoading = false;

  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  static const List<String> experienceCategories = [
    'Restaurant',
    'Retail',
    'Events',
    'Warehouse',
    'Cleaning',
    'Delivery',
    'Office Support',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _animations = List.generate(
      8, // Number of animated sections
      (index) => _createAnimation(index),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bioController.dispose();
    for (final exp in _experiences) {
      exp.dispose();
    }
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
    ];
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: intervals[index],
      ),
    );
  }

  bool _validateExperience(_ExperienceItem exp) {
    return exp.jobTitleController.text.trim().isNotEmpty &&
        exp.workplaceController.text.trim().isNotEmpty &&
        (exp.selectedCategory != null && exp.selectedCategory!.isNotEmpty);
  }

  void _addExperience() {
    if (_experiences.length < 3) {
      setState(() {
        _experiences.add(
          _ExperienceItem(
            jobTitleController: TextEditingController(),
            workplaceController: TextEditingController(),
            durationController: TextEditingController(),
            descriptionController: TextEditingController(),
          ),
        );
      });
    }
  }

  void _removeExperience(int index) {
    setState(() {
      _experiences[index].dispose();
      _experiences.removeAt(index);
    });
  }

  Future<void> _handleFinish() async {
    // Validate all experiences if they exist
    for (final exp in _experiences) {
      if (!_validateExperience(exp)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please fill in Job Title, Workplace, and Category for all experience entries.',
              ),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Build list of valid experiences
      final pastExperiences = _experiences.map((exp) => exp.toMap()).toList();

      await _profileService.saveExperienceAndSummary(
        shortBio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        pastExperiences: pastExperiences,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployeeMainNavigationPage(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete onboarding: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildShortBioSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Short bio',
            style: GoogleFonts.nunito(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tell employers a little about yourself',
            style: AppTextStyles.body.copyWith(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 200,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              hintText: 'Friendly and reliable worker with customer service experience...',
              hintStyle: AppTextStyles.hint,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_bioController.text.length}/200',
              style: AppTextStyles.label.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceCard(int index, _ExperienceItem exp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Experience ${index + 1}',
                style: GoogleFonts.nunito(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.coralAccent),
                onPressed: () => _removeExperience(index),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Job Title
          TextFormField(
            controller: exp.jobTitleController,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Job Title *',
              labelStyle: AppTextStyles.label,
              hintText: 'e.g., Cashier, Barista',
              hintStyle: AppTextStyles.hint,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Workplace
          TextFormField(
            controller: exp.workplaceController,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Workplace *',
              labelStyle: AppTextStyles.label,
              hintText: 'e.g., Joe\'s Coffee, Target',
              hintStyle: AppTextStyles.hint,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // Category
          DropdownButtonFormField<String>(
            initialValue: exp.selectedCategory,
            items: experienceCategories
                .map(
                  (cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                exp.selectedCategory = value;
              });
            },
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Category *',
              labelStyle: AppTextStyles.label,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Duration
          TextFormField(
            controller: exp.durationController,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Duration',
              labelStyle: AppTextStyles.label,
              hintText: 'e.g., 6 months, 1 year, Summer 2025',
              hintStyle: AppTextStyles.hint,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Description
          TextFormField(
            controller: exp.descriptionController,
            maxLines: 3,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: AppTextStyles.label,
              hintText: 'Brief description of your responsibilities...',
              hintStyle: AppTextStyles.hint,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: const BorderSide(color: AppColors.coralAccent, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Past work experience',
                style: GoogleFonts.nunito(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add up to 3 previous jobs if relevant',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.lightText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (_experiences.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: Text(
                'You can add experience entries only if you want employers to know more.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.lightText,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              spacing: 16,
              children: List.generate(
                _experiences.length,
                (index) => _buildExperienceCard(index, _experiences[index]),
              ),
            ),
          ),
      ],
    );
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
                    'Tell employers a bit about you',
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
                    'This helps employers understand your background',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navyBg.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Short Bio Section
              FadeTransition(
                opacity: _animations[3],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[3]),
                  child: _buildShortBioSection(),
                ),
              ),

              const SizedBox(height: 24),

              // Experience Section
              FadeTransition(
                opacity: _animations[4],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[4]),
                  child: _buildExperienceSection(),
                ),
              ),

              const SizedBox(height: 20),

              // Add Experience Button
              if (_experiences.length < 3)
                FadeTransition(
                  opacity: _animations[5],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(_animations[5]),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _addExperience,
                        icon: const Icon(Icons.add),
                        label: const Text('Add experience'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.navyBg,
                          side: const BorderSide(
                            color: AppColors.navyBg,
                            width: 2,
                          ),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 0),

              const SizedBox(height: 40),

              // Finish Button
              FadeTransition(
                opacity: _animations[6],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[6]),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: !_isLoading ? _handleFinish : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBg,
                        disabledBackgroundColor: AppColors.navyBg.withValues(alpha: 0.45),
                        shape: const StadiumBorder(),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: AppColors.coralAccent,
                            )
                          : Text(
                              'Finish',
                              style: AppTextStyles.buttonLabel(color: AppColors.coralAccent),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Back Button
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
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navyBg,
                        side: const BorderSide(
                          color: AppColors.navyBg,
                          width: 2,
                        ),
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

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

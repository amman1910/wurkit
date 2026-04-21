import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_ui.dart';
import '../services/employee_profile_service.dart';
import 'employee_availability_location_page.dart';

class EmployeeWorkPreferencesPage extends StatefulWidget {
  const EmployeeWorkPreferencesPage({super.key});

  @override
  State<EmployeeWorkPreferencesPage> createState() => _EmployeeWorkPreferencesPageState();
}

class _EmployeeWorkPreferencesPageState extends State<EmployeeWorkPreferencesPage>
    with SingleTickerProviderStateMixin {
  final EmployeeProfileService _profileService = EmployeeProfileService();

  // State variables
  List<String> selectedCategories = [];
  List<String> selectedRoles = [];
  List<String> selectedSkills = [];
  String? experienceLevel;
  double salary = 40;
  List<String> selectedJobTypes = [];
  bool isLoading = false;

  // Other options state
  bool isOtherCategorySelected = false;
  bool isOtherRoleSelected = false;
  bool isOtherSkillSelected = false;
  late TextEditingController customCategoryController;
  late TextEditingController customRoleController;
  late TextEditingController customSkillController;

  // Animation
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  // Data models
  static const Map<String, List<String>> rolesByCategory = {
    'Restaurant': ['Waiter', 'Barista', 'Kitchen Assistant', 'Host', 'Dishwasher'],
    'Retail': ['Cashier', 'Sales Associate', 'Stock Clerk', 'Customer Service'],
    'Warehouse': ['Picker', 'Loader', 'Forklift Operator', 'Inventory Clerk'],
    'Office': ['Administrative Assistant', 'Data Entry', 'Receptionist'],
    'Healthcare': ['Medical Assistant', 'Home Health Aide', 'Pharmacy Tech'],
    'Hospitality': ['Housekeeper', 'Concierge', 'Event Staff'],
    'Delivery': ['Driver', 'Courier', 'Package Handler'],
    'Construction': ['Laborer', 'Helper', 'Site Assistant'],
  };

  static const List<String> availableSkills = [
    'Customer Service',
    'Cash Handling',
    'Food Service',
    'Cleaning',
    'Heavy Lifting',
    'Driving',
    'Computer Skills',
    'Multilingual',
    'First Aid',
    'Inventory Management',
    'Time Management',
    'Teamwork',
  ];

  static const List<String> experienceLevels = [
    'No experience',
    'Beginner',
    'Some experience',
    'Experienced',
  ];

  static const List<String> jobTypes = [
    'One-time shifts',
    'Temporary jobs',
    'Weekend jobs',
    'Flexible part-time',
  ];

  @override
  void initState() {
    super.initState();
    customCategoryController = TextEditingController();
    customRoleController = TextEditingController();
    customSkillController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _animations = List.generate(
      11, // Number of animated sections
      (index) => _createAnimation(index),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    customCategoryController.dispose();
    customRoleController.dispose();
    customSkillController.dispose();
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

  Future<void> _handleContinue() async {
    setState(() => isLoading = true);

    try {
      // Prepare final lists with custom values
      List<String> finalCategories = selectedCategories.toList();
      if (isOtherCategorySelected && customCategoryController.text.trim().isNotEmpty) {
        String custom = customCategoryController.text.trim();
        if (!finalCategories.contains(custom)) finalCategories.add(custom);
      }

      List<String> finalRoles = selectedRoles.toList();
      if (isOtherRoleSelected && customRoleController.text.trim().isNotEmpty) {
        String custom = customRoleController.text.trim();
        if (!finalRoles.contains(custom)) finalRoles.add(custom);
      }

      List<String> finalSkills = selectedSkills.toList();
      if (isOtherSkillSelected && customSkillController.text.trim().isNotEmpty) {
        String custom = customSkillController.text.trim();
        if (!finalSkills.contains(custom)) finalSkills.add(custom);
      }

      await _profileService.saveWorkPreferences(
        jobCategories: finalCategories,
        preferredRoles: finalRoles,
        skills: finalSkills,
        experienceLevel: experienceLevel,
        salaryExpectation: salary,
        preferredJobTypes: selectedJobTypes,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployeeAvailabilityLocationPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
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
                    height: 80,
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
                    'What kind of work are you looking for?',
                    style: GoogleFonts.nunito(
                      color: AppColors.navyBg,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
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
                    'This helps us match you with the right jobs',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.navyBg.withOpacity(0.8),
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Job Categories
              FadeTransition(
                opacity: _animations[3],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[3]),
                  child: _buildSection(
                    title: 'Job Categories',
                    subtitle: 'Select all that interest you',
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...rolesByCategory.keys.map((category) => FilterChip(
                              label: Text(category),
                              selected: selectedCategories.contains(category),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedCategories.add(category);
                                  } else {
                                    selectedCategories.remove(category);
                                    // Remove roles from unselected categories
                                    final categoryRoles = rolesByCategory[category] ?? [];
                                    selectedRoles.removeWhere((role) => categoryRoles.contains(role));
                                  }
                                });
                              },
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.coralAccent,
                              checkmarkColor: AppColors.navyBg,
                              labelStyle: TextStyle(
                                color: selectedCategories.contains(category)
                                    ? AppColors.navyBg
                                    : AppColors.white,
                              ),
                            )),
                            FilterChip(
                              label: const Text('Other'),
                              selected: isOtherCategorySelected,
                              onSelected: (selected) {
                                setState(() {
                                  isOtherCategorySelected = selected;
                                  if (!selected) {
                                    customCategoryController.clear();
                                  }
                                });
                              },
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.coralAccent,
                              checkmarkColor: AppColors.navyBg,
                              labelStyle: TextStyle(
                                color: isOtherCategorySelected
                                    ? AppColors.navyBg
                                    : AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        if (isOtherCategorySelected) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.input,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextFormField(
                              controller: customCategoryController,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter another category',
                                hintStyle: AppTextStyles.hint,
                              ),
                              style: AppTextStyles.input,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preferred Roles (only show if categories selected)
              if (selectedCategories.isNotEmpty)
                FadeTransition(
                  opacity: _animations[4],
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(_animations[4]),
                    child: _buildSection(
                      title: 'Preferred Roles',
                      subtitle: 'Choose specific positions you\'re interested in',
                    child: _buildSection(
                      title: 'Preferred Roles',
                      subtitle: 'Choose specific positions you\'re interested in',
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...selectedCategories
                                  .expand((category) => rolesByCategory[category] ?? [])
                                  .toSet()
                                  .map((role) => FilterChip(
                                label: Text(role),
                                selected: selectedRoles.contains(role),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedRoles.add(role);
                                    } else {
                                      selectedRoles.remove(role);
                                    }
                                  });
                                },
                                backgroundColor: AppColors.surface,
                                selectedColor: AppColors.coralAccent,
                                checkmarkColor: AppColors.navyBg,
                                labelStyle: TextStyle(
                                  color: selectedRoles.contains(role)
                                      ? AppColors.navyBg
                                      : AppColors.white,
                                ),
                              )),
                              FilterChip(
                                label: const Text('Other'),
                                selected: isOtherRoleSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    isOtherRoleSelected = selected;
                                    if (!selected) {
                                      customRoleController.clear();
                                    }
                                  });
                                },
                                backgroundColor: AppColors.surface,
                                selectedColor: AppColors.coralAccent,
                                checkmarkColor: AppColors.navyBg,
                                labelStyle: TextStyle(
                                  color: isOtherRoleSelected
                                      ? AppColors.navyBg
                                      : AppColors.white,
                                ),
                              ),
                            ],
                          ),
                          if (isOtherRoleSelected) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.input,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextFormField(
                                controller: customRoleController,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter another role',
                                  hintStyle: AppTextStyles.hint,
                                ),
                                style: AppTextStyles.input,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ),
                  ),
                ),

              if (selectedCategories.isNotEmpty) const SizedBox(height: 24),

              // Skills
              FadeTransition(
                opacity: _animations[5],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[5]),
                  child: _buildSection(
                    title: 'Skills',
                    subtitle: 'What skills do you have?',
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...availableSkills.map((skill) => FilterChip(
                              label: Text(skill),
                              selected: selectedSkills.contains(skill),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedSkills.add(skill);
                                  } else {
                                    selectedSkills.remove(skill);
                                  }
                                });
                              },
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.coralAccent,
                              checkmarkColor: AppColors.navyBg,
                              labelStyle: TextStyle(
                                color: selectedSkills.contains(skill)
                                    ? AppColors.navyBg
                                    : AppColors.white,
                              ),
                            )),
                            FilterChip(
                              label: const Text('Other'),
                              selected: isOtherSkillSelected,
                              onSelected: (selected) {
                                setState(() {
                                  isOtherSkillSelected = selected;
                                  if (!selected) {
                                    customSkillController.clear();
                                  }
                                });
                              },
                              backgroundColor: AppColors.surface,
                              selectedColor: AppColors.coralAccent,
                              checkmarkColor: AppColors.navyBg,
                              labelStyle: TextStyle(
                                color: isOtherSkillSelected
                                    ? AppColors.navyBg
                                    : AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        if (isOtherSkillSelected) ...[
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.input,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextFormField(
                              controller: customSkillController,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter another skill',
                                hintStyle: AppTextStyles.hint,
                              ),
                              style: AppTextStyles.input,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Experience Level
              FadeTransition(
                opacity: _animations[6],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[6]),
                  child: _buildSection(
                    title: 'Experience Level',
                    subtitle: 'How much work experience do you have?',
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.input,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: experienceLevel,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        dropdownColor: AppColors.surface,
                        style: AppTextStyles.input,
                        items: experienceLevels.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(level),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            experienceLevel = value;
                          });
                        },
                        hint: Text(
                          'Select experience level',
                          style: AppTextStyles.hint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Salary Expectation
              FadeTransition(
                opacity: _animations[7],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[7]),
                  child: _buildSection(
                    title: 'Salary Expectation',
                    subtitle: 'Minimum hourly rate you\'re willing to accept',
                    child: Column(
                      children: [
                        Text(
                          '\$${salary.toStringAsFixed(0)}/hour',
                          style: GoogleFonts.nunito(
                            color: AppColors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: salary,
                          min: 30,
                          max: 80,
                          divisions: 50,
                          activeColor: AppColors.coralAccent,
                          inactiveColor: AppColors.surface,
                          onChanged: (value) {
                            setState(() {
                              salary = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Job Type
              FadeTransition(
                opacity: _animations[8],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[8]),
                  child: _buildSection(
                    title: 'Preferred Job Types',
                    subtitle: 'What type of work arrangements suit you?',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: jobTypes.map((type) {
                        return FilterChip(
                          label: Text(type),
                          selected: selectedJobTypes.contains(type),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedJobTypes.add(type);
                              } else {
                                selectedJobTypes.remove(type);
                              }
                            });
                          },
                          backgroundColor: AppColors.surface,
                          selectedColor: AppColors.coralAccent,
                          checkmarkColor: AppColors.navyBg,
                          labelStyle: TextStyle(
                            color: selectedJobTypes.contains(type)
                                ? AppColors.navyBg
                                : AppColors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Continue Button
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
                    child: ElevatedButton(
                      onPressed: !isLoading ? _handleContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navyBg,
                        disabledBackgroundColor: AppColors.navyBg.withOpacity(0.45),
                        shape: const StadiumBorder(),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: AppColors.coralAccent,
                            )
                          : Text(
                              'Continue',
                              style: AppTextStyles.buttonLabel(color: AppColors.coralAccent),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Back Button
              FadeTransition(
                opacity: _animations[10],
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.35),
                    end: Offset.zero,
                  ).animate(_animations[10]),
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

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
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
            title,
            style: GoogleFonts.nunito(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.body.copyWith(
              color: AppColors.lightText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class NextScreenPlaceholder extends StatelessWidget {
  const NextScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.coralAccent,
      body: const Center(
        child: Text(
          'Next Screen - Coming Soon!',
          style: TextStyle(color: AppColors.navyBg, fontSize: 24),
        ),
      ),
    );
  }
}
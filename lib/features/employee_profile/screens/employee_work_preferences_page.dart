import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_ui.dart';
import '../services/employee_profile_service.dart';
import 'employee_availability_location_page.dart';

class EmployeeWorkPreferencesPage extends StatefulWidget {
  final bool isEditing;

  const EmployeeWorkPreferencesPage({super.key, this.isEditing = false});

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
  bool isPreloading = true;

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
    'Restaurant & Food Service': [
      'Waiter',
      'Barista',
      'Kitchen Assistant',
      'Host',
      'Dishwasher',
      'Food Runner',
      'Bartender',
      'Cook Helper',
      'Catering Staff',
    ],
    'Retail & Stores': [
      'Cashier',
      'Sales Associate',
      'Stock Clerk',
      'Customer Service',
      'Shelf Organizer',
      'Store Assistant',
      'Inventory Assistant',
      'Gift Wrapper',
    ],
    'Events': [
      'Event Staff',
      'Usher',
      'Ticket Checker',
      'Setup Crew',
      'Cleanup Crew',
      'Promoter',
      'Brand Ambassador',
      'Security Assistant',
      'Catering Assistant',
    ],
    'Warehouse & Logistics': [
      'Picker',
      'Packer',
      'Loader',
      'Forklift Operator',
      'Inventory Clerk',
      'Sorting Assistant',
      'Packing Assistant',
      'Stockroom Assistant',
    ],
    'Delivery & Driving': [
      'Driver',
      'Courier',
      'Package Handler',
      'Food Delivery',
      'Grocery Delivery',
      'Moving Helper',
      'Errand Runner',
    ],
    'Cleaning & Maintenance': [
      'Cleaner',
      'House Cleaner',
      'Office Cleaner',
      'Dishwashing Support',
      'Laundry Assistant',
      'Maintenance Helper',
      'Gardening Assistant',
      'Window Cleaning',
    ],
    'Babysitting & Childcare': [
      'Babysitter',
      'Nanny Assistant',
      'After-school Helper',
      'Child Activity Helper',
      'School Pickup Helper',
      'Homework Helper',
    ],
    'Pet Care': [
      'Dog Walker',
      'Pet Sitter',
      'Pet Feeding',
      'Pet Grooming Assistant',
      'Dog Daycare Helper',
    ],
    'Home Help': [
      'Home Assistant',
      'Elderly Companion',
      'Elderly Assistance',
      'House Sitting',
      'Meal Prep Helper',
      'Shopping Helper',
      'Organization Helper',
    ],
    'Tutoring & Education': [
      'Private Tutor',
      'Homework Tutor',
      'Math Tutor',
      'English Tutor',
      'Hebrew Tutor',
      'Computer Tutor',
      'Exam Prep Helper',
    ],
    'Office & Admin': [
      'Administrative Assistant',
      'Data Entry',
      'Receptionist',
      'Office Assistant',
      'Document Scanning',
      'Filing Assistant',
      'Call Center Assistant',
    ],
    'Customer Service': [
      'Customer Support',
      'Front Desk',
      'Reception Helper',
      'Phone Support',
      'Online Chat Support',
      'Guest Relations',
    ],
    'Hospitality & Hotels': [
      'Housekeeper',
      'Concierge Assistant',
      'Hotel Reception Assistant',
      'Room Service Helper',
      'Bellhop',
      'Guest Service Assistant',
    ],
    'Healthcare Support': [
      'Medical Assistant',
      'Home Health Aide',
      'Pharmacy Assistant',
      'Clinic Receptionist',
      'Patient Support Assistant',
    ],
    'Construction & Manual Labor': [
      'Laborer',
      'Helper',
      'Site Assistant',
      'Painter Helper',
      'Renovation Helper',
      'Furniture Assembly Helper',
      'Moving Assistant',
    ],
    'Beauty & Wellness': [
      'Salon Assistant',
      'Spa Assistant',
      'Reception Assistant',
      'Makeup Assistant',
      'Fitness Studio Assistant',
    ],
    'Marketing & Promotions': [
      'Promoter',
      'Flyer Distributor',
      'Brand Ambassador',
      'Social Media Helper',
      'Content Assistant',
      'Survey Collector',
    ],
    'Tech & Digital Help': [
      'Computer Setup Helper',
      'Phone Setup Helper',
      'Basic Tech Support',
      'Website Content Assistant',
      'Social Media Assistant',
      'Photo Upload Assistant',
    ],
    'Other': [
      'General Helper',
      'Flexible Worker',
      'Short-notice Helper',
    ],
  };

  static const Map<String, IconData> categoryIcons = {
    'Restaurant & Food Service': Icons.restaurant_rounded,
    'Retail & Stores': Icons.storefront_rounded,
    'Events': Icons.celebration_rounded,
    'Warehouse & Logistics': Icons.warehouse_rounded,
    'Delivery & Driving': Icons.delivery_dining_rounded,
    'Cleaning & Maintenance': Icons.cleaning_services_rounded,
    'Babysitting & Childcare': Icons.child_care_rounded,
    'Pet Care': Icons.pets_rounded,
    'Home Help': Icons.home_rounded,
    'Tutoring & Education': Icons.school_rounded,
    'Office & Admin': Icons.business_center_rounded,
    'Customer Service': Icons.support_agent_rounded,
    'Hospitality & Hotels': Icons.hotel_rounded,
    'Healthcare Support': Icons.local_hospital_rounded,
    'Construction & Manual Labor': Icons.construction_rounded,
    'Beauty & Wellness': Icons.spa_rounded,
    'Marketing & Promotions': Icons.campaign_rounded,
    'Tech & Digital Help': Icons.computer_rounded,
    'Other': Icons.more_horiz_rounded,
    'Restaurant': Icons.restaurant_rounded,
    'Retail': Icons.storefront_rounded,
    'Warehouse': Icons.warehouse_rounded,
    'Office': Icons.business_center_rounded,
    'Healthcare': Icons.local_hospital_rounded,
    'Hospitality': Icons.hotel_rounded,
    'Delivery': Icons.delivery_dining_rounded,
    'Construction': Icons.construction_rounded,
  };

  static const Map<String, IconData> roleIcons = {
    'Waiter': Icons.room_service_rounded,
    'Barista': Icons.local_cafe_rounded,
    'Kitchen Assistant': Icons.kitchen_rounded,
    'Host': Icons.person_pin_rounded,
    'Dishwasher': Icons.wash_rounded,
    'Food Runner': Icons.directions_run_rounded,
    'Bartender': Icons.local_bar_rounded,
    'Cook Helper': Icons.restaurant_menu_rounded,
    'Catering Staff': Icons.room_service_rounded,
    'Cashier': Icons.point_of_sale_rounded,
    'Sales Associate': Icons.sell_rounded,
    'Stock Clerk': Icons.inventory_2_rounded,
    'Customer Service': Icons.support_agent_rounded,
    'Shelf Organizer': Icons.view_module_rounded,
    'Store Assistant': Icons.storefront_rounded,
    'Inventory Assistant': Icons.inventory_rounded,
    'Gift Wrapper': Icons.card_giftcard_rounded,
    'Event Staff': Icons.celebration_rounded,
    'Usher': Icons.event_seat_rounded,
    'Ticket Checker': Icons.confirmation_number_rounded,
    'Setup Crew': Icons.build_rounded,
    'Cleanup Crew': Icons.cleaning_services_rounded,
    'Promoter': Icons.campaign_rounded,
    'Brand Ambassador': Icons.record_voice_over_rounded,
    'Security Assistant': Icons.security_rounded,
    'Catering Assistant': Icons.room_service_rounded,
    'Picker': Icons.manage_search_rounded,
    'Packer': Icons.inventory_2_rounded,
    'Loader': Icons.local_shipping_rounded,
    'Forklift Operator': Icons.precision_manufacturing_rounded,
    'Inventory Clerk': Icons.fact_check_rounded,
    'Sorting Assistant': Icons.sort_rounded,
    'Packing Assistant': Icons.inventory_2_rounded,
    'Stockroom Assistant': Icons.warehouse_rounded,
    'Driver': Icons.directions_car_rounded,
    'Courier': Icons.delivery_dining_rounded,
    'Package Handler': Icons.inventory_2_rounded,
    'Food Delivery': Icons.delivery_dining_rounded,
    'Grocery Delivery': Icons.shopping_bag_rounded,
    'Moving Helper': Icons.move_up_rounded,
    'Errand Runner': Icons.directions_run_rounded,
    'Cleaner': Icons.cleaning_services_rounded,
    'House Cleaner': Icons.home_rounded,
    'Office Cleaner': Icons.business_rounded,
    'Laundry Assistant': Icons.local_laundry_service_rounded,
    'Maintenance Helper': Icons.handyman_rounded,
    'Gardening Assistant': Icons.grass_rounded,
    'Window Cleaning': Icons.window_rounded,
    'Babysitter': Icons.child_care_rounded,
    'Nanny Assistant': Icons.child_friendly_rounded,
    'After-school Helper': Icons.school_rounded,
    'Child Activity Helper': Icons.toys_rounded,
    'School Pickup Helper': Icons.directions_car_rounded,
    'Homework Helper': Icons.menu_book_rounded,
    'Dog Walker': Icons.pets_rounded,
    'Pet Sitter': Icons.pets_rounded,
    'Pet Feeding': Icons.pets_rounded,
    'Pet Grooming Assistant': Icons.content_cut_rounded,
    'Dog Daycare Helper': Icons.pets_rounded,
    'Home Assistant': Icons.home_rounded,
    'Elderly Companion': Icons.elderly_rounded,
    'Elderly Assistance': Icons.volunteer_activism_rounded,
    'House Sitting': Icons.house_rounded,
    'Meal Prep Helper': Icons.restaurant_menu_rounded,
    'Shopping Helper': Icons.shopping_cart_rounded,
    'Organization Helper': Icons.inventory_rounded,
    'Private Tutor': Icons.school_rounded,
    'Homework Tutor': Icons.menu_book_rounded,
    'Math Tutor': Icons.calculate_rounded,
    'English Tutor': Icons.translate_rounded,
    'Hebrew Tutor': Icons.language_rounded,
    'Computer Tutor': Icons.computer_rounded,
    'Exam Prep Helper': Icons.edit_note_rounded,
    'Administrative Assistant': Icons.badge_rounded,
    'Data Entry': Icons.keyboard_rounded,
    'Receptionist': Icons.support_agent_rounded,
    'Office Assistant': Icons.business_center_rounded,
    'Document Scanning': Icons.document_scanner_rounded,
    'Filing Assistant': Icons.folder_rounded,
    'Call Center Assistant': Icons.call_rounded,
    'Medical Assistant': Icons.local_hospital_rounded,
    'Home Health Aide': Icons.health_and_safety_rounded,
    'Pharmacy Assistant': Icons.medication_rounded,
    'Clinic Receptionist': Icons.local_hospital_rounded,
    'Patient Support Assistant': Icons.volunteer_activism_rounded,
    'Laborer': Icons.construction_rounded,
    'Helper': Icons.handyman_rounded,
    'Site Assistant': Icons.engineering_rounded,
    'Painter Helper': Icons.format_paint_rounded,
    'Renovation Helper': Icons.construction_rounded,
    'Furniture Assembly Helper': Icons.chair_rounded,
    'Moving Assistant': Icons.move_up_rounded,
    'Salon Assistant': Icons.spa_rounded,
    'Spa Assistant': Icons.spa_rounded,
    'Makeup Assistant': Icons.face_retouching_natural_rounded,
    'Fitness Studio Assistant': Icons.fitness_center_rounded,
    'Flyer Distributor': Icons.local_post_office_rounded,
    'Social Media Helper': Icons.public_rounded,
    'Content Assistant': Icons.edit_rounded,
    'Survey Collector': Icons.assignment_rounded,
    'Computer Setup Helper': Icons.computer_rounded,
    'Phone Setup Helper': Icons.phone_android_rounded,
    'Basic Tech Support': Icons.support_agent_rounded,
    'Website Content Assistant': Icons.web_rounded,
    'Social Media Assistant': Icons.public_rounded,
    'Photo Upload Assistant': Icons.photo_camera_rounded,
    'General Helper': Icons.work_outline_rounded,
    'Flexible Worker': Icons.autorenew_rounded,
    'Short-notice Helper': Icons.flash_on_rounded,
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
    'Working with Children',
    'Pet Care',
    'Tutoring',
    'Cooking',
    'Organization',
    'Sales',
    'Communication',
    'Phone Support',
    'Basic Tech Support',
    'Event Setup',
    'Reliability',
    'Fast Learner',
    'Physical Work',
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
    _loadExistingProfile();
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

  Future<void> _loadExistingProfile() async {
    try {
      final profile = await _profileService.getCurrentEmployeeProfile();
      if (!mounted) return;

      if (profile != null) {
        final categories = _readStringList(profile, 'jobCategories');
        final roles = _readStringList(profile, 'preferredRoles');
        final savedSkills = _readStringList(profile, 'skills');
        final knownRoles = rolesByCategory.values.expand((items) => items).toSet();

        selectedCategories = categories.where(rolesByCategory.containsKey).toList();
        final customCategories = categories.where((item) => !rolesByCategory.containsKey(item)).toList();
        if (customCategories.isNotEmpty) {
          isOtherCategorySelected = true;
          customCategoryController.text = customCategories.first;
        }

        selectedRoles = roles.where(knownRoles.contains).toList();
        final customRoles = roles.where((item) => !knownRoles.contains(item)).toList();
        if (customRoles.isNotEmpty) {
          isOtherRoleSelected = true;
          customRoleController.text = customRoles.first;
        }

        selectedSkills = savedSkills.where(availableSkills.contains).toList();
        final customSkills = savedSkills.where((item) => !availableSkills.contains(item)).toList();
        if (customSkills.isNotEmpty) {
          isOtherSkillSelected = true;
          customSkillController.text = customSkills.first;
        }

        final savedExperienceLevel = _readString(profile, 'experienceLevel');
        if (experienceLevels.contains(savedExperienceLevel)) {
          experienceLevel = savedExperienceLevel;
        }

        salary = _readDouble(profile, 'salaryExpectation', salary)
            .clamp(30, 80)
            .toDouble();
        selectedJobTypes = _readStringList(profile, 'preferredJobTypes')
            .where(jobTypes.contains)
            .toList();
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not load your saved work preferences.');
      }
    } finally {
      if (mounted) {
        setState(() => isPreloading = false);
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

  String _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value == null ? '' : value.toString();
  }

  double _readDouble(Map<String, dynamic> data, String key, double fallback) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
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
        if (widget.isEditing) {
          Navigator.pop(context);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EmployeeAvailabilityLocationPage(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save preferences: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = isLoading || isPreloading;

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
                              avatar: Icon(
                                categoryIcons[category] ?? Icons.work_outline_rounded,
                                size: 18,
                                color: selectedCategories.contains(category)
                                    ? AppColors.navyBg
                                    : AppColors.coralAccent,
                              ),
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
                              avatar: Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                                color: isOtherCategorySelected
                                    ? AppColors.navyBg
                                    : AppColors.coralAccent,
                              ),
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
              if (selectedCategories.isNotEmpty || isOtherCategorySelected)
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
                                avatar: Icon(
                                  roleIcons[role] ?? Icons.work_outline_rounded,
                                  size: 16,
                                  color: selectedRoles.contains(role)
                                      ? AppColors.navyBg
                                      : AppColors.coralAccent,
                                ),
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
                                avatar: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 16,
                                  color: isOtherRoleSelected
                                      ? AppColors.navyBg
                                      : AppColors.coralAccent,
                                ),
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

              if (selectedCategories.isNotEmpty || isOtherCategorySelected) const SizedBox(height: 24),

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
                      onPressed: !isBusy ? _handleContinue : null,
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

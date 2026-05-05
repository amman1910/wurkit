import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_ui.dart';
import '../services/employer_profile_service.dart';
import 'employer_profile_summary_page.dart';

class EmployerHiringPreferencesPage extends StatefulWidget {
  final bool isEditing;

  const EmployerHiringPreferencesPage({super.key, this.isEditing = false});

  @override
  State<EmployerHiringPreferencesPage> createState() => _EmployerHiringPreferencesPageState();
}

class _EmployerHiringPreferencesPageState extends State<EmployerHiringPreferencesPage>
    with SingleTickerProviderStateMixin {
  final EmployerProfileService _profileService = EmployerProfileService();

  bool _isLoading = false;
  bool _isPreloading = true;
  bool _isFormComplete = false;
  bool _urgentHiringEnabled = true;
  bool _usuallyNeedsShortNoticeWorkers = true;
  RangeValues _hourlyRateRange = const RangeValues(40, 60);
  String? _preferredExperienceLevel;
  final Set<String> _selectedHiringCategories = {};
  final Set<String> _selectedRequiredSkills = {};
  final Set<String> _selectedShiftTypes = {};

  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  final List<String> _hiringCategoryOptions = [
    'Waiters',
    'Cashiers',
    'Kitchen Help',
    'Cleaners',
    'Delivery Drivers',
    'Warehouse Workers',
    'Event Staff',
    'Sales Assistants',
    'Baristas',
    'Security',
  ];

  final List<String> _requiredSkillOptions = [
    'Customer Service',
    'Fast Learner',
    'Physical Work',
    'Teamwork',
    'Hebrew',
    'English',
    'Driving License',
    'Cash Register',
    'Food Handling',
    'Cleaning',
  ];

  final List<String> _shiftTypeOptions = [
    'Morning',
    'Afternoon',
    'Evening',
    'Night',
    'Weekend',
    'Flexible',
  ];

  bool _showCustomHiringCategoryInput = false;
  bool _showCustomRequiredSkillInput = false;
  bool _showCustomShiftTypeInput = false;
  final TextEditingController _customHiringCategoryController = TextEditingController();
  final TextEditingController _customRequiredSkillController = TextEditingController();
  final TextEditingController _customShiftTypeController = TextEditingController();

  final List<String> _experienceLevelOptions = [
    'No experience needed',
    'Basic experience',
    'Experienced',
  ];
  bool _showCustomExperienceInput = false;
  final TextEditingController _customExperienceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _animations = List.generate(8, (index) => _createAnimation(index));
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
    _animationController.dispose();
    _customHiringCategoryController.dispose();
    _customRequiredSkillController.dispose();
    _customShiftTypeController.dispose();
    _customExperienceController.dispose();
    super.dispose();
  }

  void _updateFormComplete() {
    final categoriesValid = _selectedHiringCategories.isNotEmpty;
    final shiftsValid = _selectedShiftTypes.isNotEmpty;
    final experienceValid = _preferredExperienceLevel != null;
    final isComplete = categoriesValid && shiftsValid && experienceValid;

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
        _setSelectedOptions(
          savedValues: _readStringList(profile, 'hiringCategories'),
          options: _hiringCategoryOptions,
          selectedValues: _selectedHiringCategories,
        );
        _setSelectedOptions(
          savedValues: _readStringList(profile, 'requiredSkills'),
          options: _requiredSkillOptions,
          selectedValues: _selectedRequiredSkills,
        );
        _setSelectedOptions(
          savedValues: _readStringList(profile, 'typicalShiftTypes'),
          options: _shiftTypeOptions,
          selectedValues: _selectedShiftTypes,
        );

        _urgentHiringEnabled = _readBool(profile, 'urgentHiringEnabled', _urgentHiringEnabled);
        _usuallyNeedsShortNoticeWorkers = _readBool(
          profile,
          'usuallyNeedsShortNoticeWorkers',
          _usuallyNeedsShortNoticeWorkers,
        );

        final minRate = _readDouble(profile, 'defaultHourlyRateMin', _hourlyRateRange.start);
        final maxRate = _readDouble(profile, 'defaultHourlyRateMax', _hourlyRateRange.end);
        final safeMinRate = minRate.clamp(30, 120).toDouble();
        final safeMaxRate = maxRate.clamp(30, 120).toDouble();
        _hourlyRateRange = RangeValues(
          safeMinRate <= safeMaxRate ? safeMinRate : safeMaxRate,
          safeMaxRate >= safeMinRate ? safeMaxRate : safeMinRate,
        );

        final experience = _readString(profile, 'preferredExperienceLevel');
        if (experience.isNotEmpty) {
          if (!_experienceLevelOptions.contains(experience)) {
            _experienceLevelOptions.add(experience);
          }
          _preferredExperienceLevel = experience;
        }
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not load your saved hiring preferences.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPreloading = false);
        _updateFormComplete();
      }
    }
  }

  void _setSelectedOptions({
    required List<String> savedValues,
    required List<String> options,
    required Set<String> selectedValues,
  }) {
    for (final value in savedValues) {
      if (!options.contains(value)) {
        options.add(value);
      }
      selectedValues.add(value);
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

  bool _readBool(Map<String, dynamic> data, String key, bool fallback) {
    final value = data[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
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
    if (_selectedHiringCategories.isEmpty) {
      _showError('Please select at least one worker category');
      return;
    }

    if (_selectedShiftTypes.isEmpty) {
      _showError('Please select at least one shift type');
      return;
    }

    if (_preferredExperienceLevel == null) {
      _showError('Please select preferred experience level');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _profileService.saveHiringPreferences(
        hiringCategories: _selectedHiringCategories.toList(),
        requiredSkills: _selectedRequiredSkills.toList(),
        typicalShiftTypes: _selectedShiftTypes.toList(),
        urgentHiringEnabled: _urgentHiringEnabled,
        usuallyNeedsShortNoticeWorkers: _usuallyNeedsShortNoticeWorkers,
        defaultHourlyRateMin: _hourlyRateRange.start,
        defaultHourlyRateMax: _hourlyRateRange.end,
        preferredExperienceLevel: _preferredExperienceLevel!,
      );

      if (!mounted) return;

      if (widget.isEditing) {
        Navigator.pop(context);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployerProfileSummaryPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save preferences: ${e.toString()}');
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

  Widget _buildCustomInput({
    required TextEditingController controller,
    required VoidCallback onAdd,
    required String hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              style: AppTextStyles.body.copyWith(color: AppColors.white),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTextStyles.body.copyWith(color: AppColors.lightText.withOpacity(0.8)),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.coralAccent),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: onAdd,
              style: AppButtonStyles.primary(
                backgroundColor: AppColors.coralAccent,
                foregroundColor: AppColors.navyBg,
              ),
              child: Text(
                'Add',
                style: AppTextStyles.buttonLabel(color: AppColors.navyBg),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomMultiSelectOption({
    required String sectionName,
    required List<String> options,
    required Set<String> selectedValues,
    required TextEditingController controller,
    required void Function(bool) setShowCustom,
  }) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      _showError('Please enter a custom $sectionName');
      return;
    }

    final normalized = value.toLowerCase();
    if (options.any((option) => option.toLowerCase() == normalized)) {
      _showError('This custom $sectionName already exists');
      return;
    }

    setState(() {
      options.add(value);
      selectedValues.add(value);
      controller.clear();
      setShowCustom(false);
    });
    _updateFormComplete();
  }

  void _addCustomSingleSelectOption({
    required String sectionName,
    required List<String> options,
    required TextEditingController controller,
    required void Function(bool) setShowCustom,
    required void Function(String) setSelectedValue,
  }) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      _showError('Please enter a custom $sectionName');
      return;
    }

    final normalized = value.toLowerCase();
    if (options.any((option) => option.toLowerCase() == normalized)) {
      _showError('This custom $sectionName already exists');
      return;
    }

    setState(() {
      options.add(value);
      setSelectedValue(value);
      controller.clear();
      setShowCustom(false);
    });
    _updateFormComplete();
  }

  Widget _buildMultiSelectChipSection({
    required String label,
    required List<String> options,
    required Set<String> selectedOptions,
    required bool showCustomInput,
    required TextEditingController controller,
    required VoidCallback onOtherTap,
    required VoidCallback onAddCustom,
    required void Function(Set<String>) onSelectionChanged,
    required String customHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.lightText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...options.map((option) {
              final isSelected = selectedOptions.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (isSelected) {
                  setState(() {
                    if (isSelected) {
                      selectedOptions.add(option);
                    } else {
                      selectedOptions.remove(option);
                    }
                    onSelectionChanged(selectedOptions);
                  });
                  _updateFormComplete();
                },
                selectedColor: AppColors.coralAccent,
                backgroundColor: AppColors.surface,
                checkmarkColor: AppColors.navyBg,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.navyBg : AppColors.lightText,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.coralAccent : AppColors.border,
                ),
              );
            }),
            FilterChip(
              label: const Text('Other'),
              selected: false,
              onSelected: (_) => onOtherTap(),
              selectedColor: AppColors.coralAccent,
              backgroundColor: AppColors.surface,
              checkmarkColor: AppColors.navyBg,
              labelStyle: AppTextStyles.body.copyWith(
                color: AppColors.lightText,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: AppColors.border),
            ),
          ],
        ),
        if (showCustomInput) _buildCustomInput(controller: controller, onAdd: onAddCustom, hintText: customHint),
      ],
    );
  }

  Widget _buildSingleSelectChipSection({
    required String label,
    required List<String> options,
    required String? selectedOption,
    required bool showCustomInput,
    required TextEditingController controller,
    required VoidCallback onOtherTap,
    required VoidCallback onAddCustom,
    required void Function(String?) onSelectionChanged,
    required String customHint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: AppColors.lightText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...options.map((option) {
              final isSelected = selectedOption == option;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    onSelectionChanged(selected ? option : null);
                  });
                  _updateFormComplete();
                },
                selectedColor: AppColors.coralAccent,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.navyBg : AppColors.lightText,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.coralAccent : AppColors.border,
                ),
              );
            }),
            ChoiceChip(
              label: const Text('Other'),
              selected: false,
              onSelected: (_) => onOtherTap(),
              selectedColor: AppColors.coralAccent,
              backgroundColor: AppColors.surface,
              labelStyle: AppTextStyles.body.copyWith(
                color: AppColors.lightText,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: AppColors.border),
            ),
          ],
        ),
        if (showCustomInput) _buildCustomInput(controller: controller, onAdd: onAddCustom, hintText: customHint),
      ],
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
                      'What kind of workers do you need?',
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
                      'Set your hiring preferences so we can help you find relevant workers faster.',
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
        
                    const SizedBox(height: 10),
                    _buildMultiSelectChipSection(
                      label: 'Hiring categories',
                      options: _hiringCategoryOptions,
                      selectedOptions: _selectedHiringCategories,
                      showCustomInput: _showCustomHiringCategoryInput,
                      controller: _customHiringCategoryController,
                      onOtherTap: () => setState(() => _showCustomHiringCategoryInput = true),
                      onAddCustom: () => _addCustomMultiSelectOption(
                        sectionName: 'hiring category',
                        options: _hiringCategoryOptions,
                        selectedValues: _selectedHiringCategories,
                        controller: _customHiringCategoryController,
                        setShowCustom: (visible) => _showCustomHiringCategoryInput = visible,
                      ),
                      onSelectionChanged: (_) {},
                      customHint: 'Enter a custom worker category',
                    ),
                    const SizedBox(height: AppSpacing.field),
                    _buildMultiSelectChipSection(
                      label: 'Required skills (optional)',
                      options: _requiredSkillOptions,
                      selectedOptions: _selectedRequiredSkills,
                      showCustomInput: _showCustomRequiredSkillInput,
                      controller: _customRequiredSkillController,
                      onOtherTap: () => setState(() => _showCustomRequiredSkillInput = true),
                      onAddCustom: () => _addCustomMultiSelectOption(
                        sectionName: 'required skill',
                        options: _requiredSkillOptions,
                        selectedValues: _selectedRequiredSkills,
                        controller: _customRequiredSkillController,
                        setShowCustom: (visible) => _showCustomRequiredSkillInput = visible,
                      ),
                      onSelectionChanged: (_) {},
                      customHint: 'Enter a custom required skill',
                    ),
                    const SizedBox(height: AppSpacing.field),
                    _buildMultiSelectChipSection(
                      label: 'Typical shift types',
                      options: _shiftTypeOptions,
                      selectedOptions: _selectedShiftTypes,
                      showCustomInput: _showCustomShiftTypeInput,
                      controller: _customShiftTypeController,
                      onOtherTap: () => setState(() => _showCustomShiftTypeInput = true),
                      onAddCustom: () => _addCustomMultiSelectOption(
                        sectionName: 'shift type',
                        options: _shiftTypeOptions,
                        selectedValues: _selectedShiftTypes,
                        controller: _customShiftTypeController,
                        setShowCustom: (visible) => _showCustomShiftTypeInput = visible,
                      ),
                      onSelectionChanged: (_) {},
                      customHint: 'Enter a custom shift type',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.field),
              _buildAnimatedItem(
                3,
                SwitchListTile(
                  title: Text(
                    'Enable urgent hiring',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Allow this business to post urgent same-day jobs.',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.lightText,
                      fontSize: 12,
                    ),
                  ),
                  value: _urgentHiringEnabled,
                  onChanged: (value) {
                    setState(() {
                      _urgentHiringEnabled = value;
                    });
                  },
                  activeColor: AppColors.coralAccent,
                  activeTrackColor: AppColors.coralAccent.withOpacity(0.3),
                  inactiveThumbColor: AppColors.border,
                  inactiveTrackColor: AppColors.border.withOpacity(0.3),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              _buildAnimatedItem(
                4,
                SwitchListTile(
                  title: Text(
                    'Often need short-notice workers',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  subtitle: Text(
                    'Useful for last-minute replacements and busy shifts.',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.lightText,
                      fontSize: 12,
                    ),
                  ),
                  value: _usuallyNeedsShortNoticeWorkers,
                  onChanged: (value) {
                    setState(() {
                      _usuallyNeedsShortNoticeWorkers = value;
                    });
                  },
                  activeColor: AppColors.coralAccent,
                  activeTrackColor: AppColors.coralAccent.withOpacity(0.3),
                  inactiveThumbColor: AppColors.border,
                  inactiveTrackColor: AppColors.border.withOpacity(0.3),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: AppSpacing.field),
              _buildAnimatedItem(
                5,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default hourly rate range',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '₪${_hourlyRateRange.start.round()} - ₪${_hourlyRateRange.end.round()} per hour',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          RangeSlider(
                            values: _hourlyRateRange,
                            min: 30,
                            max: 120,
                            divisions: 90,
                            activeColor: AppColors.coralAccent,
                            inactiveColor: AppColors.border,
                            labels: RangeLabels(
                              '₪${_hourlyRateRange.start.round()}',
                              '₪${_hourlyRateRange.end.round()}',
                            ),
                            onChanged: (values) {
                              setState(() {
                                _hourlyRateRange = values;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.field),
                    _buildSingleSelectChipSection(
                      label: 'Preferred experience level',
                      options: _experienceLevelOptions,
                      selectedOption: _preferredExperienceLevel,
                      showCustomInput: _showCustomExperienceInput,
                      controller: _customExperienceController,
                      onOtherTap: () => setState(() => _showCustomExperienceInput = true),
                      onAddCustom: () => _addCustomSingleSelectOption(
                        sectionName: 'experience level',
                        options: _experienceLevelOptions,
                        controller: _customExperienceController,
                        setShowCustom: (visible) => _showCustomExperienceInput = visible,
                        setSelectedValue: (value) => _preferredExperienceLevel = value,
                      ),
                      onSelectionChanged: (selected) => _preferredExperienceLevel = selected,
                      customHint: 'Enter a custom experience level',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildAnimatedItem(
                7,
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

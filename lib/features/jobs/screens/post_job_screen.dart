import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_ui.dart';
import '../../../shared/models/resolved_address.dart';
import '../../../shared/utils/address_format_utils.dart';
import '../../../shared/widgets/address_autocomplete_field.dart';
import '../services/job_service.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({
    super.key,
    this.editJobId,
    this.initialJobData,
    this.isEditMode = false,
    this.isDuplicateMode = false,
  });

  final String? editJobId;
  final Map<String, dynamic>? initialJobData;
  final bool isEditMode;
  final bool isDuplicateMode;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _jobService = JobService();
  final _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _addressController = TextEditingController();
  ResolvedAddress? _customResolvedAddress;

  String? _jobCategory;
  String _salaryType = 'Hourly';
  double _salaryAmount = 45;
  String _dateMode = 'asap';
  String _locationType = 'business_address';
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedImageFile;
  Map<String, dynamic>? _employerProfile;
  bool _isLoading = false;
  bool _isProfileLoading = true;
  bool _didApplyInitialJobData = false;
  List<String> _existingImageUrls = const [];
  String? _originalMeaningfulSignature;

  final Set<String> _selectedSkills = {};
  final Set<String> _customSkills = {};
  final List<_ShiftDraft> _shifts = [_ShiftDraft()];

  static const _customCategoryOption = 'Other / Add custom role';

  static const _fallbackCategories = [
    'Waiter / Waitress',
    'Bartender',
    'Kitchen Assistant',
    'Cashier',
    'Retail Assistant',
    'Delivery Driver',
    'Cleaner',
    'Event Staff',
    'Babysitter',
    'Warehouse Worker',
    'Office Assistant',
    'Security',
    'Other',
  ];

  static const _fallbackSkills = [
    'Customer service',
    'Reliability',
    'Teamwork',
    'Communication',
    'Fast learner',
    'English',
    'Hebrew',
    'Time management',
  ];

  static const Map<String, List<String>> _businessTypeCategories = {
    'restaurant': [
      'Waiter / Waitress',
      'Bartender',
      'Kitchen Assistant',
      'Dishwasher',
      'Host / Hostess',
    ],
    'cafe': [
      'Waiter / Waitress',
      'Bartender',
      'Kitchen Assistant',
      'Dishwasher',
      'Host / Hostess',
    ],
    'retail': [
      'Cashier',
      'Sales Assistant',
      'Stock Worker',
      'Customer Service',
    ],
    'event': ['Event Staff', 'Setup Crew', 'Usher', 'Security'],
    'clean': ['Cleaner', 'Housekeeping'],
    'delivery': ['Delivery Driver', 'Courier'],
    'child': ['Babysitter'],
    'office': ['Office Assistant', 'Receptionist', 'Data Entry'],
    'admin': ['Office Assistant', 'Receptionist', 'Data Entry'],
  };

  static const Map<String, List<String>> _skillsByCategory = {
    'Waiter / Waitress': [
      'Customer service',
      'Fast service',
      'Teamwork',
      'English',
      'POS experience',
      'Carrying trays',
      'Restaurant experience',
    ],
    'Bartender': [
      'Customer service',
      'Bar experience',
      'Fast service',
      'Evening availability',
      'Teamwork',
    ],
    'Kitchen Assistant': [
      'Food prep',
      'Cleaning experience',
      'Teamwork',
      'Physical stamina',
      'Fast service',
    ],
    'Dishwasher': [
      'Cleaning experience',
      'Physical stamina',
      'Fast service',
      'Reliability',
    ],
    'Host / Hostess': [
      'Customer service',
      'Communication',
      'English',
      'Restaurant experience',
    ],
    'Delivery Driver': [
      'Driving license',
      'Navigation',
      'Time management',
      'Own vehicle',
      'Customer service',
    ],
    'Courier': ['Navigation', 'Time management', 'Own vehicle', 'Reliability'],
    'Babysitter': [
      'Childcare experience',
      'Patience',
      'Responsibility',
      'First aid',
      'Evening availability',
    ],
    'Cleaner': [
      'Attention to detail',
      'Physical stamina',
      'Reliability',
      'Cleaning experience',
    ],
    'Housekeeping': [
      'Attention to detail',
      'Reliability',
      'Cleaning experience',
    ],
    'Retail Assistant': [
      'Customer service',
      'Sales',
      'POS experience',
      'Inventory handling',
      'Communication',
    ],
    'Sales Assistant': [
      'Customer service',
      'Sales',
      'Communication',
      'POS experience',
    ],
    'Cashier': [
      'POS experience',
      'Customer service',
      'Reliability',
      'Cash handling',
    ],
    'Stock Worker': ['Inventory handling', 'Physical stamina', 'Reliability'],
    'Customer Service': ['Customer service', 'Communication', 'Patience'],
    'Event Staff': [
      'Customer service',
      'Teamwork',
      'Physical stamina',
      'Evening availability',
    ],
    'Setup Crew': ['Physical stamina', 'Teamwork', 'Reliability'],
    'Usher': ['Customer service', 'Communication', 'Evening availability'],
    'Warehouse Worker': [
      'Physical stamina',
      'Inventory handling',
      'Reliability',
      'Teamwork',
    ],
    'Office Assistant': [
      'Communication',
      'Organization',
      'English',
      'Computer skills',
    ],
    'Receptionist': ['Communication', 'Organization', 'Customer service'],
    'Data Entry': ['Computer skills', 'Attention to detail', 'Reliability'],
    'Security': [
      'Responsibility',
      'Reliability',
      'Night availability',
      'Communication',
    ],
    'Other': ['Reliability', 'Teamwork', 'Communication', 'Fast learner'],
  };

  @override
  void initState() {
    super.initState();
    _loadEmployerProfile();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customCategoryController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployerProfile() async {
    try {
      final profile = await _jobService.getCurrentEmployerProfile();
      if (!mounted) return;

      setState(() {
        _employerProfile = profile;
        if (profile != null) {
          _addressController.text =
              _readString(profile['businessAddress']) ?? '';
          _customResolvedAddress = _resolvedAddressFromProfile(profile);
          _applyProfileSalaryDefault(profile);

          final profileCategories = _profileCategories(profile);
          if (profileCategories.length == 1) {
            _jobCategory = profileCategories.first;
          }
        }
        _applyInitialJobDataIfNeeded();
      });
    } catch (_) {
      if (mounted) {
        _showSnack('Could not load business defaults yet.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _applyInitialJobDataIfNeeded();
          _isProfileLoading = false;
        });
      }
    }
  }

  bool get _isEditing => widget.isEditMode || widget.editJobId != null;

  bool get _isDuplicating => widget.isDuplicateMode;

  void _applyInitialJobDataIfNeeded() {
    final data = widget.initialJobData;
    if (_didApplyInitialJobData || data == null) return;

    _didApplyInitialJobData = true;
    _titleController.text = _readString(data['title']) ?? '';
    _descriptionController.text = _readString(data['description']) ?? '';

    final category = _readString(data['jobCategory']);
    if (category != null) {
      if (_categoryOptions.contains(category)) {
        _jobCategory = category;
      } else {
        _jobCategory = _customCategoryOption;
        _customCategoryController.text = category;
      }
    }

    _selectedSkills
      ..clear()
      ..addAll(_readStringList(data['requiredSkills']));
    _customSkills.addAll(_selectedSkills);

    _salaryType = _readString(data['salaryType']) ?? _salaryType;
    _salaryAmount = _readDouble(data['salaryAmount']) ?? _salaryAmount;
    _salaryAmount = _salaryAmount.clamp(_salaryRange.min, _salaryRange.max);

    final startDate = _readDateTime(data['startDate'] ?? data['date']);
    final endDate = _readDateTime(data['endDate']);
    _startDate = startDate;
    _endDate = endDate;
    if (data['startAsSoonAsPossible'] == true || startDate == null) {
      _dateMode = 'asap';
    } else {
      _dateMode = endDate == null ? 'specific' : 'range';
    }

    final location = _readMap(data['location']);
    final locationType = _readString(location['type']);
    if (locationType == 'remote' ||
        locationType == 'business_address' ||
        locationType == 'custom_address') {
      _locationType = locationType!;
    }
    _addressController.text = _readString(location['address']) ?? '';
    final lat = _readDouble(location['lat']);
    final lng = _readDouble(location['lng']);
    final placeId =
        _readString(data['jobPlaceId']) ?? _readString(location['placeId']);
    if (_locationType == 'custom_address' &&
        lat != null &&
        lng != null &&
        placeId != null) {
      _customResolvedAddress = ResolvedAddress(
        formattedAddress: _addressController.text,
        placeId: placeId,
        latitude: lat,
        longitude: lng,
        country:
            _readString(data['jobCountry']) ?? _readString(location['country']),
      );
    }

    final parsedShifts = _readShiftDrafts(data['shifts']);
    _shifts
      ..clear()
      ..addAll(parsedShifts.isEmpty ? [_ShiftDraft()] : parsedShifts);

    _existingImageUrls = _readStringList(data['imageUrls']);
    _originalMeaningfulSignature = _meaningfulJobSignature(data);
  }

  void _applyProfileSalaryDefault(Map<String, dynamic> profile) {
    final min = _readDouble(profile['defaultHourlyRateMin']);
    final max = _readDouble(profile['defaultHourlyRateMax']);
    if (min == null || max == null || min <= 0 || max < min) return;

    final hourlyRange = const _SalaryRange(30, 120, 45);
    _salaryAmount = ((min + max) / 2).clamp(hourlyRange.min, hourlyRange.max);
  }

  bool get _isUrgent {
    if (_dateMode == 'asap') return true;
    final start = _startDate;
    if (start == null) return false;
    final now = DateTime.now();
    return start.isAfter(now.subtract(const Duration(minutes: 1))) &&
        start.difference(now).inHours <= 48;
  }

  List<String> get _categoryOptions {
    final profile = _employerProfile;
    if (profile == null) return _withCustomCategoryOption(_fallbackCategories);

    final categories = _profileCategories(profile);
    if (categories.isNotEmpty) return _withCustomCategoryOption(categories);

    final businessType = _readString(profile['businessType']);
    final derived = _categoriesForBusinessType(businessType);
    return _withCustomCategoryOption(
      derived.isEmpty ? _fallbackCategories : derived,
    );
  }

  List<String> _profileCategories(Map<String, dynamic> profile) {
    return _uniqueStrings(_readStringList(profile['hiringCategories']));
  }

  List<String> get _skillOptions {
    return _uniqueStrings([
      ..._readStringList(_employerProfile?['requiredSkills']),
      ...(_skillsByCategory[_finalJobCategory] ?? const []),
      ..._fallbackSkills,
      ..._customSkills,
      ..._selectedSkills,
    ]);
  }

  _SalaryRange get _salaryRange {
    switch (_salaryType) {
      case 'Daily':
        return const _SalaryRange(200, 1000, 500);
      case 'Fixed':
        return const _SalaryRange(100, 5000, 800);
      default:
        return const _SalaryRange(30, 120, 45);
    }
  }

  void _setSalaryType(String type) {
    final range = type == 'Daily'
        ? const _SalaryRange(200, 1000, 500)
        : type == 'Fixed'
        ? const _SalaryRange(100, 5000, 800)
        : const _SalaryRange(30, 120, 45);

    setState(() {
      _salaryType = type;
      _salaryAmount = _salaryAmount.clamp(range.min, range.max);
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(int index, {required bool isStart}) async {
    final shift = _shifts[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (shift.startTime ?? TimeOfDay.now())
          : (shift.endTime ?? TimeOfDay.now()),
    );

    if (picked == null) return;
    setState(() {
      if (isStart) {
        shift.startTime = picked;
      } else {
        shift.endTime = picked;
      }
    });
  }

  Future<void> _pickJobImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      setState(() => _selectedImageFile = File(pickedFile.path));
    } catch (error) {
      _showSnack('Failed to select image: $error', isError: true);
    }
  }

  Future<void> _editSkills() async {
    final knownOptions = _skillOptions;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SkillsSheet(
        initialSelected: _selectedSkills,
        options: _skillOptions,
      ),
    );

    if (result == null) return;
    setState(() {
      _selectedSkills
        ..clear()
        ..addAll(result);
      _customSkills.addAll(
        result.where((skill) => !knownOptions.contains(skill)),
      );
    });
  }

  Future<void> _saveDraft() async {
    if (_isEditing || _isDuplicating) {
      await _saveJob(publish: false);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty &&
        (_finalJobCategory == null || _finalJobCategory!.isEmpty)) {
      _showSnack(
        'Add a title or category so you can find this draft later.',
        isError: true,
      );
      return;
    }

    await _saveJob(publish: false);
  }

  Future<void> _previewAndPublish() async {
    final error = _publishValidationError();
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }
    if (_isDuplicating && !_hasMeaningfulDuplicateChange()) {
      _showSnack(
        'Please change at least one job detail before publishing the duplicated job.',
        isError: true,
      );
      return;
    }

    final publish = await _showPreviewSheet();
    if (publish == true) {
      await _saveJob(publish: true);
    }
  }

  Future<void> _saveJob({required bool publish}) async {
    final locationError = _locationValidationError();
    if (locationError != null) {
      _showSnack(locationError, isError: true);
      return;
    }
    setState(() => _isLoading = true);

    try {
      var imageUrls = _existingImageUrls;
      if (_selectedImageFile != null) {
        imageUrls = [
          await _jobService.uploadJobImage(imageFile: _selectedImageFile!),
        ];
      }

      final jobData = _buildJobData(imageUrls: imageUrls);
      if (_isEditing && !_isDuplicating) {
        final editJobId = widget.editJobId;
        if (editJobId == null || editJobId.trim().isEmpty) {
          throw Exception('Job to edit is missing');
        }
        await _jobService.updateJob(jobId: editJobId, jobData: jobData);
      } else {
        await _jobService.createJob(publish: publish, jobData: jobData);
      }

      if (!mounted) return;
      _showSnack(
        _isEditing && !_isDuplicating
            ? 'Job updated successfully.'
            : publish
            ? 'Job published successfully.'
            : 'Draft saved.',
      );
      if (_isEditing || _isDuplicating || publish) {
        Navigator.of(context).pop(true);
      } else {
        _resetForm();
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Failed to save job: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic> _buildJobData({List<String> imageUrls = const []}) {
    final startDate = _dateMode == 'asap' ? null : _startDate;
    final endDate = _dateMode == 'range' ? _endDate : null;
    final jobCategory = _finalJobCategory;
    final shifts = _validShifts()
        .map(
          (shift) => {
            'startTime': _formatTimeOfDay(shift.startTime!),
            'endTime': _formatTimeOfDay(shift.endTime!),
          },
        )
        .toList();

    final resolvedLocation = _locationData();
    return {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'jobCategory': jobCategory,
      'jobCategorySource': _isCustomCategory ? 'custom' : 'suggested',
      'requiredSkills': _selectedSkills.toList(),
      'salaryAmount': _salaryAmount.round(),
      'salaryType': _salaryType,
      'startAsSoonAsPossible': _dateMode == 'asap',
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate),
      'urgent': _isUrgent,
      'shifts': shifts,
      'location': {
        'type': resolvedLocation['type'],
        'address': resolvedLocation['address'],
        'lat': resolvedLocation['lat'],
        'lng': resolvedLocation['lng'],
      },
      'jobAddress': resolvedLocation['address'],
      'jobPlaceId': resolvedLocation['placeId'],
      'jobLocation': resolvedLocation['lat'] == null
          ? null
          : {'lat': resolvedLocation['lat'], 'lng': resolvedLocation['lng']},
      'jobCountry': resolvedLocation['country'],
      'imageUrls': imageUrls,
    };
  }

  bool _hasMeaningfulDuplicateChange() {
    final original = _originalMeaningfulSignature;
    if (original == null) return true;
    return _meaningfulJobSignature(
          _buildJobData(imageUrls: _existingImageUrls),
        ) !=
        original;
  }

  Map<String, dynamic> _locationData() {
    if (_locationType == 'remote') {
      return {
        'type': 'remote',
        'address': null,
        'lat': null,
        'lng': null,
        'placeId': null,
        'country': null,
      };
    }

    if (_locationType == 'business_address') {
      final location = _readMap(
        _employerProfile?['businessLocation'] ?? _employerProfile?['location'],
      );
      return {
        'type': 'business_address',
        'address': formatAddressForDisplay(
          _readString(_employerProfile?['businessAddress']) ??
              _addressController.text.trim(),
        ),
        'lat': _readDouble(location['lat']),
        'lng': _readDouble(location['lng']),
        'placeId': _readString(_employerProfile?['businessPlaceId']),
        'country': _readString(_employerProfile?['businessCountry']),
      };
    }

    final selected = _customResolvedAddress;
    return {
      'type': 'custom_address',
      'address': formatAddressForDisplay(
        selected?.formattedAddress ?? _addressController.text.trim(),
      ),
      'lat': selected?.latitude,
      'lng': selected?.longitude,
      'placeId': selected?.placeId,
      'country': selected?.country,
    };
  }

  List<_ShiftDraft> _validShifts() {
    return _shifts.where((shift) {
      final start = shift.startTime;
      final end = shift.endTime;
      return start != null &&
          end != null &&
          _timeMinutes(end) > _timeMinutes(start);
    }).toList();
  }

  String? _publishValidationError() {
    if (_isCustomCategory && _customCategoryController.text.trim().isEmpty) {
      return 'Add a custom job category.';
    }
    if (_finalJobCategory == null || _finalJobCategory!.isEmpty) {
      return 'Choose a job category.';
    }
    if (_titleController.text.trim().isEmpty) {
      return 'Add a job title.';
    }
    if (_salaryAmount <= 0 || _salaryType.isEmpty) {
      return 'Choose a salary amount and type.';
    }
    if (_dateMode == 'specific' && _startDate == null) {
      return 'Choose a start date.';
    }
    if (_dateMode == 'range') {
      if (_startDate == null || _endDate == null) {
        return 'Choose both start and end dates.';
      }
      if (_endDate!.isBefore(_startDate!)) {
        return 'End date cannot be before start date.';
      }
    }
    if (_validShifts().isEmpty) {
      return 'Add at least one valid shift with an end time after the start time.';
    }
    final locationError = _locationValidationError();
    if (locationError != null) return locationError;
    return null;
  }

  String? _locationValidationError() {
    if (_locationType == 'business_address') {
      final address =
          _readString(_employerProfile?['businessAddress']) ??
          _addressController.text.trim();
      if (address.isEmpty) {
        return 'Your business address is missing. Enter a different address or choose remote.';
      }
      if (_readString(_employerProfile?['businessPlaceId']) == null ||
          _readMap(
            _employerProfile?['businessLocation'] ??
                _employerProfile?['location'],
          ).isEmpty) {
        return 'Validate your business address in your profile, or choose a different address.';
      }
    }
    if (_locationType == 'custom_address' && _customResolvedAddress == null) {
      return 'Please select a valid address from the list.';
    }
    return null;
  }

  Future<bool?> _showPreviewSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _JobPreviewSheet(
          title: _titleController.text.trim(),
          category: _finalJobCategory ?? '',
          salary: _salaryText,
          date: _dateText,
          isUrgent: _isUrgent,
          shifts: _validShifts()
              .map(
                (shift) =>
                    '${_formatTimeOfDay(shift.startTime!)} - ${_formatTimeOfDay(shift.endTime!)}',
              )
              .toList(),
          location: _locationText,
          skills: _selectedSkills.toList(),
          imageFile: _selectedImageFile,
        );
      },
    );
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _customCategoryController.clear();
    _addressController.text =
        _readString(_employerProfile?['businessAddress']) ?? '';
    setState(() {
      _jobCategory = _categoryOptions.length == 1
          ? _categoryOptions.first
          : null;
      _selectedSkills.clear();
      _customSkills.clear();
      _salaryType = 'Hourly';
      _salaryAmount = 45;
      if (_employerProfile != null) {
        _applyProfileSalaryDefault(_employerProfile!);
      }
      _dateMode = 'asap';
      _locationType = 'business_address';
      _startDate = null;
      _endDate = null;
      _selectedImageFile = null;
      _shifts
        ..clear()
        ..add(_ShiftDraft());
    });
  }

  String get _salaryText {
    final suffix = _salaryType == 'Hourly'
        ? ' / hour'
        : _salaryType == 'Daily'
        ? ' / day'
        : ' fixed';
    return '\u20AA${_salaryAmount.round()}$suffix';
  }

  String get _dateText {
    if (_dateMode == 'asap') return 'As soon as possible';
    if (_dateMode == 'specific') {
      return _startDate == null ? 'Specific date' : _formatDate(_startDate!);
    }
    if (_startDate == null || _endDate == null) return 'Date range';
    return '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}';
  }

  String get _locationText {
    if (_locationType == 'remote') return 'Remote job';
    final data = _locationData();
    final address = _readString(data['address']);
    return address ?? 'Location not set';
  }

  String get _skillsSummary {
    if (_selectedSkills.isEmpty) return 'No skills selected';
    final skills = _selectedSkills.take(3).join(', ');
    final extra = _selectedSkills.length > 3
        ? ' +${_selectedSkills.length - 3}'
        : '';
    return '$skills$extra';
  }

  bool get _isCustomCategory => _jobCategory == _customCategoryOption;

  String? get _finalJobCategory {
    if (_isCustomCategory) {
      return _readString(_customCategoryController.text);
    }
    return _readString(_jobCategory);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isProfileLoading;
    final range = _salaryRange;
    final categoryOptions = _categoryOptions;

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isDuplicating
              ? 'Duplicate job'
              : _isEditing
              ? 'Edit job'
              : 'Post job',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormSection(
                  title: 'Job details',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          '${categoryOptions.join('|')}|$_jobCategory',
                        ),
                        initialValue: categoryOptions.contains(_jobCategory)
                            ? _jobCategory
                            : null,
                        isExpanded: true,
                        decoration: _compactDecoration(
                          label: 'Job category',
                          hint: 'Choose category',
                        ),
                        dropdownColor: AppColors.surface,
                        style: AppTextStyles.input,
                        items: categoryOptions
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: busy
                            ? null
                            : (value) {
                                setState(() {
                                  _jobCategory = value;
                                  if (value != _customCategoryOption) {
                                    _customCategoryController.clear();
                                  }
                                  _selectedSkills.clear();
                                });
                              },
                      ),
                      if (_isCustomCategory) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customCategoryController,
                          enabled: !busy,
                          style: AppTextStyles.input,
                          onChanged: (_) => setState(() {}),
                          decoration: _compactDecoration(
                            label: 'Custom job category',
                            hint: 'e.g. Barista',
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        enabled: !busy,
                        style: AppTextStyles.input,
                        decoration: _compactDecoration(
                          label: 'Job title',
                          hint: _jobTitleHintForCategory(
                            _jobCategory,
                            _customCategoryController.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        enabled: !busy,
                        maxLines: 2,
                        style: AppTextStyles.input,
                        decoration: _compactDecoration(
                          label: 'Description',
                          hint: 'Optional details workers should know',
                        ),
                      ),
                    ],
                  ),
                ),
                const _FormDivider(),
                _FormSection(
                  title: 'Timing',
                  trailing: _isUrgent
                      ? const _MiniBadge(
                          label: 'Urgent',
                          icon: Icons.bolt_rounded,
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SegmentedOptions(
                        value: _dateMode,
                        compact: true,
                        options: const {
                          'asap': 'ASAP',
                          'specific': 'Date',
                          'range': 'Range',
                        },
                        onChanged: busy
                            ? null
                            : (value) => setState(() => _dateMode = value),
                      ),
                      if (_dateMode != 'asap') ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _PickTile(
                                label: 'Start',
                                value: _startDate == null
                                    ? 'Choose'
                                    : _formatDate(_startDate!),
                                icon: Icons.calendar_today_outlined,
                                onTap: busy
                                    ? null
                                    : () => _pickDate(isStart: true),
                              ),
                            ),
                            if (_dateMode == 'range') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PickTile(
                                  label: 'End',
                                  value: _endDate == null
                                      ? 'Choose'
                                      : _formatDate(_endDate!),
                                  icon: Icons.event_outlined,
                                  onTap: busy
                                      ? null
                                      : () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      ...List.generate(_shifts.length, (index) {
                        final shift = _shifts[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _shifts.length - 1 ? 0 : 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _PickTile(
                                  label: 'Start',
                                  value: shift.startTime == null
                                      ? 'Start'
                                      : _formatTimeOfDay(shift.startTime!),
                                  icon: Icons.schedule_rounded,
                                  onTap: busy
                                      ? null
                                      : () => _pickTime(index, isStart: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PickTile(
                                  label: 'End',
                                  value: shift.endTime == null
                                      ? 'End'
                                      : _formatTimeOfDay(shift.endTime!),
                                  icon: Icons.schedule_outlined,
                                  onTap: busy
                                      ? null
                                      : () => _pickTime(index, isStart: false),
                                ),
                              ),
                              if (index > 0)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: busy
                                      ? null
                                      : () => setState(
                                          () => _shifts.removeAt(index),
                                        ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.lightText,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () => setState(() => _shifts.add(_ShiftDraft())),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add shift'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.coralAccent,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                const _FormDivider(),
                _FormSection(
                  title: 'Location',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SegmentedOptions(
                        value: _locationType,
                        compact: true,
                        options: const {
                          'business_address': 'Business',
                          'custom_address': 'Different',
                          'remote': 'Remote',
                        },
                        onChanged: busy
                            ? null
                            : (value) {
                                setState(() {
                                  _locationType = value;
                                  if (value == 'business_address') {
                                    _addressController.text =
                                        _readString(
                                          _employerProfile?['businessAddress'],
                                        ) ??
                                        '';
                                  } else if (value == 'remote') {
                                    _addressController.clear();
                                    _customResolvedAddress = null;
                                  } else if (value == 'custom_address') {
                                    _addressController.clear();
                                    _customResolvedAddress = null;
                                  }
                                });
                              },
                      ),
                      if (_locationType == 'business_address') ...[
                        const SizedBox(height: 10),
                        _SoftInfo(
                          icon: Icons.storefront_outlined,
                          text: _locationText == 'Location not set'
                              ? 'No saved business address found.'
                              : _locationText,
                        ),
                      ],
                      if (_locationType == 'custom_address') ...[
                        const SizedBox(height: 10),
                        AddressAutocompleteField(
                          controller: _addressController,
                          enabled: !busy,
                          decoration: _compactDecoration(
                            label: 'Address',
                            hint: 'Start typing and select an address',
                          ),
                          initialAddress: _customResolvedAddress,
                          onAddressChanged: (address) {
                            setState(() {
                              _customResolvedAddress = address;
                            });
                          },
                        ),
                      ],
                      if (_locationType == 'remote') ...[
                        const SizedBox(height: 10),
                        const _SoftInfo(
                          icon: Icons.wifi_tethering_rounded,
                          text: 'Workers will see this as a remote job.',
                        ),
                      ],
                    ],
                  ),
                ),
                const _FormDivider(),
                _FormSection(
                  title: 'Pay',
                  trailing: Text(
                    _salaryText,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SegmentedOptions(
                        value: _salaryType,
                        compact: true,
                        options: const {
                          'Hourly': 'Hourly',
                          'Daily': 'Daily',
                          'Fixed': 'Fixed',
                        },
                        onChanged: busy ? null : _setSalaryType,
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: _salaryAmount,
                          min: range.min,
                          max: range.max,
                          divisions: (range.max - range.min).round(),
                          activeColor: AppColors.coralAccent,
                          inactiveColor: AppColors.border,
                          onChanged: busy
                              ? null
                              : (value) =>
                                    setState(() => _salaryAmount = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const _FormDivider(),
                _FormSection(
                  title: 'Requirements',
                  child: Column(
                    children: [
                      _SkillsSummaryTile(
                        count: _selectedSkills.length,
                        summary: _skillsSummary,
                        onTap: busy ? null : _editSkills,
                      ),
                      if (_selectedSkills.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            'Recommended: add a few skills so workers know if they fit.',
                            style: AppTextStyles.label.copyWith(fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _ImageRow(
                        imageFile: _selectedImageFile,
                        onTap: busy ? null : _pickJobImage,
                        onRemove: _selectedImageFile == null || busy
                            ? null
                            : () => setState(() => _selectedImageFile = null),
                      ),
                    ],
                  ),
                ),
                const _FormDivider(),
                _FormSection(
                  title: 'Actions',
                  child: _FormActions(
                    busy: busy,
                    isEditMode: _isEditing && !_isDuplicating,
                    isDuplicateMode: _isDuplicating,
                    onSaveDraft: _saveDraft,
                    onSaveChanges: () => _saveJob(publish: false),
                    onPublish: _previewAndPublish,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.coralAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}

class _SegmentedOptions extends StatelessWidget {
  const _SegmentedOptions({
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: options.entries.map((entry) {
        final selected = entry.key == value;
        return ChoiceChip(
          label: Text(entry.value),
          selected: selected,
          onSelected: onChanged == null ? null : (_) => onChanged!(entry.key),
          selectedColor: AppColors.coralAccent,
          backgroundColor: AppColors.navyBg,
          labelStyle: TextStyle(
            color: selected ? AppColors.navyBg : AppColors.lightText,
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w800,
          ),
          side: BorderSide(
            color: selected ? AppColors.coralAccent : AppColors.border,
          ),
          visualDensity: compact
              ? const VisualDensity(horizontal: -2, vertical: -2)
              : VisualDensity.standard,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.coralAccent, size: 16),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftInfo extends StatelessWidget {
  const _SoftInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navyBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.label.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSummaryTile extends StatelessWidget {
  const _SkillsSummaryTile({
    required this.count,
    required this.summary,
    required this.onTap,
  });

  final int count;
  final String summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.coralAccent,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 0 ? 'Required skills' : '$count selected',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.coralAccent,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.imageFile,
    required this.onTap,
    this.onRemove,
  });

  final File? imageFile;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageFile == null
                  ? const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.coralAccent,
                      size: 22,
                    )
                  : Image.file(imageFile!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job image',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    imageFile == null
                        ? 'Optional, business logo can be used later'
                        : 'Tap to change',
                    style: AppTextStyles.label.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.lightText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkillsSheet extends StatefulWidget {
  const _SkillsSheet({required this.initialSelected, required this.options});

  final Set<String> initialSelected;
  final List<String> options;

  @override
  State<_SkillsSheet> createState() => _SkillsSheetState();
}

class _SkillsSheetState extends State<_SkillsSheet> {
  late final Set<String> _selected = {...widget.initialSelected};
  late List<String> _options = [...widget.options];
  final _searchController = TextEditingController();
  final _customController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _addCustomSkill() {
    final skill = _customController.text.trim();
    if (skill.isEmpty) return;
    setState(() {
      if (!_options.contains(skill)) {
        _options = _uniqueStrings([skill, ..._options]);
      }
      _selected.add(skill);
      _customController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _options.where((skill) {
      return _query.isEmpty || skill.toLowerCase().contains(_query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Required skills',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                style: AppTextStyles.input,
                onChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
                decoration: _compactDecoration(
                  label: 'Search skills',
                  hint: 'Customer service',
                  suffixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.coralAccent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final skill = filtered[index];
                    final checked = _selected.contains(skill);
                    return CheckboxListTile(
                      value: checked,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.coralAccent,
                      checkColor: AppColors.navyBg,
                      title: Text(
                        skill,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          value == true
                              ? _selected.add(skill)
                              : _selected.remove(skill);
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customController,
                      style: AppTextStyles.input,
                      onSubmitted: (_) => _addCustomSkill(),
                      decoration: _compactDecoration(
                        label: 'Add custom skill',
                        hint: 'e.g. Hebrew',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addCustomSkill,
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.coralAccent,
                      foregroundColor: AppColors.navyBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: AppButtonStyles.primary(
                    foregroundColor: AppColors.navyBg,
                  ),
                  child: Text('Done', style: AppTextStyles.buttonLabel()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobPreviewSheet extends StatelessWidget {
  const _JobPreviewSheet({
    required this.title,
    required this.category,
    required this.salary,
    required this.date,
    required this.isUrgent,
    required this.shifts,
    required this.location,
    required this.skills,
    required this.imageFile,
  });

  final String title;
  final String category;
  final String salary;
  final String date;
  final bool isUrgent;
  final List<String> shifts;
  final String location;
  final List<String> skills;
  final File? imageFile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    imageFile!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              if (imageFile != null) const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isUrgent)
                    const _MiniBadge(label: 'Urgent', icon: Icons.bolt_rounded),
                ],
              ),
              const SizedBox(height: 6),
              Text(category, style: AppTextStyles.label),
              const SizedBox(height: 14),
              _PreviewRow(icon: Icons.payments_outlined, text: salary),
              _PreviewRow(icon: Icons.calendar_today_outlined, text: date),
              _PreviewRow(
                icon: Icons.schedule_rounded,
                text: shifts.isEmpty ? 'Shift TBD' : shifts.join(', '),
              ),
              _PreviewRow(icon: Icons.place_outlined, text: location),
              if (skills.isNotEmpty)
                _PreviewRow(
                  icon: Icons.auto_awesome_rounded,
                  text: skills.join(', '),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: AppButtonStyles.secondaryOutline(),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: AppButtonStyles.primary(
                        foregroundColor: AppColors.navyBg,
                      ),
                      child: Text(
                        'Publish',
                        style: AppTextStyles.buttonLabel(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.coralAccent.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.coralAccent,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _ShiftDraft {
  _ShiftDraft();

  TimeOfDay? startTime;
  TimeOfDay? endTime;
}

class _FormActions extends StatelessWidget {
  const _FormActions({
    required this.busy,
    required this.isEditMode,
    required this.isDuplicateMode,
    required this.onSaveDraft,
    required this.onSaveChanges,
    required this.onPublish,
  });

  final bool busy;
  final bool isEditMode;
  final bool isDuplicateMode;
  final VoidCallback onSaveDraft;
  final VoidCallback onSaveChanges;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    if (isEditMode) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: busy ? null : onSaveChanges,
          style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
          child: busy
              ? const _ButtonProgress()
              : Text('Save changes', style: AppTextStyles.buttonLabel()),
        ),
      );
    }

    if (isDuplicateMode) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: busy ? null : onPublish,
          style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
          child: busy
              ? const _ButtonProgress()
              : Text(
                  'Preview & Publish',
                  style: AppTextStyles.buttonLabel(fontSize: 14),
                ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: busy ? null : onSaveDraft,
              style: AppButtonStyles.secondaryOutline(),
              child: const Text('Save draft'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: busy ? null : onPublish,
              style: AppButtonStyles.primary(foregroundColor: AppColors.navyBg),
              child: busy
                  ? const _ButtonProgress()
                  : Text(
                      'Preview & Publish',
                      style: AppTextStyles.buttonLabel(fontSize: 14),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: AppColors.navyBg,
      ),
    );
  }
}

class _SalaryRange {
  const _SalaryRange(this.min, this.max, this.initial);

  final double min;
  final double max;
  final double initial;
}

InputDecoration _compactDecoration({
  required String label,
  String? hint,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: AppTextStyles.label.copyWith(fontSize: 12),
    hintStyle: AppTextStyles.hint.copyWith(fontSize: 13),
    filled: true,
    fillColor: AppColors.navyBg,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.coralAccent, width: 1.6),
    ),
  );
}

String _formatDate(DateTime date) {
  return DateFormat('MMM d, yyyy').format(date);
}

String _formatTimeOfDay(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

int _timeMinutes(TimeOfDay time) {
  return time.hour * 60 + time.minute;
}

List<String> _withCustomCategoryOption(List<String> categories) {
  return _uniqueStrings([
    ...categories,
    _PostJobScreenState._customCategoryOption,
  ]);
}

String _jobTitleHintForCategory(String? category, String? customCategory) {
  final custom = _readString(customCategory);
  if (category == _PostJobScreenState._customCategoryOption) {
    return custom == null
        ? 'Custom role needed for short shift'
        : '$custom needed for short shift';
  }

  switch (category) {
    case 'Waiter / Waitress':
      return 'Waiter needed for evening shift';
    case 'Bartender':
      return 'Bartender needed tonight';
    case 'Barista':
      return 'Barista needed for morning shift';
    case 'Delivery Driver':
      return 'Delivery driver needed today';
    case 'Cashier':
      return 'Cashier needed for short shift';
    case 'Cleaner':
      return 'Cleaner needed for apartment job';
    case 'Event Staff':
      return 'Event staff needed this weekend';
    case 'Babysitter':
      return 'Babysitter needed for evening';
    case 'Other':
      return custom == null
          ? 'Role needed for short shift'
          : '$custom needed for short shift';
    default:
      final role = _readString(category);
      return role == null
          ? 'Waiter needed for evening shift'
          : '$role needed for short shift';
  }
}

List<String> _categoriesForBusinessType(String? businessType) {
  final normalized = businessType?.toLowerCase().trim() ?? '';
  if (normalized.isEmpty) return const [];

  for (final entry in _PostJobScreenState._businessTypeCategories.entries) {
    if (normalized.contains(entry.key)) {
      return entry.value;
    }
  }

  return const [];
}

List<String> _uniqueStrings(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    final key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  return result;
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

ResolvedAddress? _resolvedAddressFromProfile(Map<String, dynamic> profile) {
  final location = _readMap(profile['businessLocation'] ?? profile['location']);
  final lat = _readDouble(location['lat']);
  final lng = _readDouble(location['lng']);
  final placeId = _readString(profile['businessPlaceId']);
  final address = _readString(profile['businessAddress']);
  if (lat == null || lng == null || placeId == null || address == null) {
    return null;
  }
  return ResolvedAddress(
    formattedAddress: address,
    placeId: placeId,
    latitude: lat,
    longitude: lng,
    country: _readString(profile['businessCountry']),
  );
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return null;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<_ShiftDraft> _readShiftDrafts(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((shiftData) {
        return _ShiftDraft()
          ..startTime = _parseTimeOfDay(_readString(shiftData['startTime']))
          ..endTime = _parseTimeOfDay(_readString(shiftData['endTime']));
      })
      .where((shift) {
        return shift.startTime != null || shift.endTime != null;
      })
      .toList();
}

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _meaningfulJobSignature(Map<String, dynamic> data) {
  final meaningful = {
    'title': _readString(data['title']) ?? '',
    'description': _readString(data['description']) ?? '',
    'jobCategory': _readString(data['jobCategory']) ?? '',
    'requiredSkills': _normalizedStringList(data['requiredSkills']),
    'salaryAmount': _readDouble(data['salaryAmount']),
    'salaryType': _readString(data['salaryType']) ?? '',
    'startAsSoonAsPossible': data['startAsSoonAsPossible'] == true,
    'startDate': _normalizedDate(data['startDate'] ?? data['date']),
    'endDate': _normalizedDate(data['endDate']),
    'shifts': _normalizedShifts(data['shifts']),
    'location': _normalizedLocation(data['location']),
    'urgent': data['urgent'] == true,
  };
  return jsonEncode(meaningful);
}

List<String> _normalizedStringList(Object? value) {
  final list = _readStringList(value);
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

String? _normalizedDate(Object? value) {
  final date = _readDateTime(value);
  if (date == null) return _readString(value);
  return DateTime(date.year, date.month, date.day).toIso8601String();
}

List<Map<String, String>> _normalizedShifts(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((shiftData) {
    return {
      'startTime': _readString(shiftData['startTime']) ?? '',
      'endTime': _readString(shiftData['endTime']) ?? '',
    };
  }).toList();
}

Map<String, Object?> _normalizedLocation(Object? value) {
  final location = _readMap(value);
  return {
    'type': _readString(location['type']) ?? '',
    'address': _readString(location['address']) ?? '',
    'lat': _readDouble(location['lat']),
    'lng': _readDouble(location['lng']),
  };
}

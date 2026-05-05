import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_ui.dart';
import '../services/job_service.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobService = JobService();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();

  // Form data
  DateTime? _selectedDate;
  String? _selectedSalaryType;
  String? _selectedRequiredSkill;
  TimeOfDay? _shiftStart;
  TimeOfDay? _shiftEnd;
  bool _isUrgent = false;
  bool _isLoading = false;

  final List<String> _salaryTypes = ['Hourly', 'Daily', 'Fixed'];
  final List<String> _requiredSkills = [
    'Waiter',
    'Babysitter',
    'Cleaner',
    'Dog Walker',
    'Delivery',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _shiftStart = picked;
        } else {
          _shiftEnd = picked;
        }
      });
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      _showError('Please select a date');
      return;
    }

    if (_shiftStart == null) {
      _showError('Please select shift start time');
      return;
    }

    if (_shiftEnd == null) {
      _showError('Please select shift end time');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _jobService.createJob(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        date: _selectedDate!,
        salary: double.parse(_salaryController.text.trim()),
        salaryType: _selectedSalaryType!,
        requiredSkill: _selectedRequiredSkill!,
        shiftStart: _shiftStart!,
        shiftEnd: _shiftEnd!,
        urgent: _isUrgent,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job posted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _formKey.currentState!.reset();
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _salaryController.clear();
      setState(() {
        _selectedDate = null;
        _selectedSalaryType = null;
        _selectedRequiredSkill = null;
        _shiftStart = null;
        _shiftEnd = null;
        _isUrgent = false;
      });
    } catch (e) {
      if (mounted) {
        _showError('Failed to post job: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Post a New Job',
          style: AppTextStyles.heading(fontSize: 24),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: AppInputDecorations.authField(
                    label: 'Job Title',
                    hint: 'e.g. Waiter for evening shift',
                  ),
                  style: AppTextStyles.input,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Job title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.field),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: AppInputDecorations.authField(
                    label: 'Description',
                    hint: 'Describe the job requirements and details',
                  ),
                  style: AppTextStyles.input,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.field),

                TextFormField(
                  controller: _locationController,
                  decoration: AppInputDecorations.authField(
                    label: 'Location',
                    hint: 'e.g. Jerusalem',
                    suffixIcon: const Icon(
                      Icons.location_on,
                      color: AppColors.coralAccent,
                    ),
                  ),
                  style: AppTextStyles.input,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.field),

                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: AppInputDecorations.authField(
                      label: 'Date',
                      suffixIcon: const Icon(
                        Icons.calendar_today,
                        color: AppColors.coralAccent,
                      ),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                          : 'Select date',
                      style: AppTextStyles.input,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.field),

                TextFormField(
                  controller: _salaryController,
                  keyboardType: TextInputType.number,
                  decoration: AppInputDecorations.authField(
                    label: 'Salary',
                    hint: 'e.g. 50',
                  ),
                  style: AppTextStyles.input,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Salary is required';
                    }
                    final salary = double.tryParse(value.trim());
                    if (salary == null || salary <= 0) {
                      return 'Please enter a valid salary';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.field),

                DropdownButtonFormField<String>(
                  value: _selectedSalaryType,
                  decoration: AppInputDecorations.authField(
                    label: 'Salary Type',
                  ),
                  dropdownColor: AppColors.surface,
                  style: AppTextStyles.input,
                  items: _salaryTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: AppTextStyles.input),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSalaryType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Salary type is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.field),

                DropdownButtonFormField<String>(
                  value: _selectedRequiredSkill,
                  decoration: AppInputDecorations.authField(
                    label: 'Required Skill',
                  ),
                  dropdownColor: AppColors.surface,
                  style: AppTextStyles.input,
                  items: _requiredSkills.map((skill) {
                    return DropdownMenuItem(
                      value: skill,
                      child: Text(skill, style: AppTextStyles.input),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRequiredSkill = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Required skill is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.field),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, true),
                        child: InputDecorator(
                          decoration: AppInputDecorations.authField(
                            label: 'Shift Start',
                            suffixIcon: const Icon(
                              Icons.access_time,
                              color: AppColors.coralAccent,
                            ),
                          ),
                          child: Text(
                            _shiftStart != null
                                ? _shiftStart!.format(context)
                                : 'Start time',
                            style: AppTextStyles.input,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, false),
                        child: InputDecorator(
                          decoration: AppInputDecorations.authField(
                            label: 'Shift End',
                            suffixIcon: const Icon(
                              Icons.access_time,
                              color: AppColors.coralAccent,
                            ),
                          ),
                          child: Text(
                            _shiftEnd != null
                                ? _shiftEnd!.format(context)
                                : 'End time',
                            style: AppTextStyles.input,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.field),

                SwitchListTile(
                  title: const Text(
                    'Urgent Hiring',
                    style: TextStyle(color: AppColors.white),
                  ),
                  subtitle: const Text(
                    'Mark as urgent to reach workers faster',
                    style: TextStyle(color: AppColors.lightText, fontSize: 12),
                  ),
                  value: _isUrgent,
                  onChanged: (value) {
                    setState(() {
                      _isUrgent = value;
                    });
                  },
                  activeColor: AppColors.coralAccent,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitJob,
                    style: AppButtonStyles.primary(),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.navyBg,
                            ),
                          )
                        : Text(
                            'Post Job',
                            style: AppTextStyles.buttonLabel(
                              color: AppColors.navyBg,
                            ),
                          ),
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

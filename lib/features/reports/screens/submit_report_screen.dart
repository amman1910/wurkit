import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../services/report_service.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reportedUserRole,
    required this.reportType,
    this.jobId,
    this.jobTitle,
  });

  final String reportedUserId;
  final String reportedUserName;
  final String reportedUserRole;
  final String reportType;
  final String? jobId;
  final String? jobTitle;

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen> {
  static const List<String> _reasonOptions = [
    'No show',
    'Inappropriate behavior',
    'Fake job',
    'Payment issue',
    'Safety concern',
    'Harassment',
    'Spam or scam',
    'Other',
  ];

  final ReportService _reportService = ReportService();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _reportService.submitReport(
        reportedUserId: widget.reportedUserId,
        reportedUserName: widget.reportedUserName,
        reportedUserRole: widget.reportedUserRole,
        reportType: widget.reportType,
        reason: _selectedReason!,
        description: _descriptionController.text.trim(),
        jobId: widget.jobId,
        jobTitle: widget.jobTitle,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.jobTitle == null || widget.jobTitle!.trim().isEmpty
        ? widget.reportedUserName
        : '${widget.reportedUserName} • ${widget.jobTitle!.trim()}';

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      appBar: AppBar(
        backgroundColor: AppColors.navyBg,
        foregroundColor: AppColors.white,
        title: const Text('Report a problem'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
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
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Report type: ${widget.reportType}',
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  items: _reasonOptions
                      .map(
                        (reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _selectedReason = value),
                  decoration: AppInputDecorations.authField(label: 'Reason'),
                  dropdownColor: AppColors.surface,
                  iconEnabledColor: AppColors.lightText,
                  style: AppTextStyles.input,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please select a reason.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSubmitting,
                  minLines: 5,
                  maxLines: 8,
                  style: AppTextStyles.input,
                  decoration: AppInputDecorations.authField(
                    label: 'Description',
                    hint: 'Tell us what happened',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 10) {
                      return 'Description must be at least 10 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: AppButtonStyles.primary(
                      foregroundColor: AppColors.navyBg,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Text('Submit', style: AppTextStyles.buttonLabel()),
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

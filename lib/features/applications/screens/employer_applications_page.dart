import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_ui.dart';
import '../services/application_service.dart';

class EmployerApplicationsPage extends StatefulWidget {
  const EmployerApplicationsPage({super.key});

  @override
  State<EmployerApplicationsPage> createState() => _EmployerApplicationsPageState();
}

class _EmployerApplicationsPageState extends State<EmployerApplicationsPage> {
  final ApplicationService _applicationService = ApplicationService();
  final Set<String> _processingIds = {};

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.coralAccent;
    }
  }

  Future<void> _changeStatus(String applicationId, String status) async {
    setState(() {
      _processingIds.add(applicationId);
    });

    try {
      await _applicationService.updateApplicationStatus(
        applicationId: applicationId,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application $status successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(applicationId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.navyBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.horizontal),
              child: Text(
                'Please sign in to view applications.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.horizontal,
            vertical: AppSpacing.vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Applications',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Review workers who applied to your jobs.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  _StatusChip(label: 'Pending'),
                  _StatusChip(label: 'Approved'),
                  _StatusChip(label: 'Rejected'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _applicationService.getApplicationsForEmployer(currentUser.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ApplicationsErrorView(error: snapshot.error.toString());
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final applications = snapshot.data?.docs ?? [];
                    if (applications.isEmpty) {
                      return const _ApplicationsEmptyView();
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: applications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final application = applications[index].data();
                        final applicationId = applications[index].id;
                        final status = application['status'] as String? ?? 'pending';
                        final createdAt = application['createdAt'] as Timestamp?;
                        final createdAtString = createdAt != null
                            ? DateFormat('yyyy-MM-dd – HH:mm').format(createdAt.toDate())
                            : 'Unknown date';
                        final isProcessing = _processingIds.contains(applicationId);

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      application['jobTitle'] as String? ?? 'Job title',
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Applicant: ${application['employeeName'] as String? ?? 'Unknown'}',
                                style: AppTextStyles.label,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                application['message'] as String? ?? 'No message provided.',
                                style: AppTextStyles.body,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Applied on $createdAtString',
                                style: AppTextStyles.label,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isProcessing || status == 'approved'
                                          ? null
                                          : () => _changeStatus(applicationId, 'approved'),
                                      style: AppButtonStyles.secondaryOutline(
                                        borderColor: Colors.green.shade300,
                                      ),
                                      child: isProcessing && status != 'rejected'
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                              ),
                                            )
                                          : const Text('Approve'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isProcessing || status == 'rejected'
                                          ? null
                                          : () => _changeStatus(applicationId, 'rejected'),
                                      style: AppButtonStyles.secondaryOutline(
                                        borderColor: Colors.red.shade300,
                                      ),
                                      child: isProcessing && status != 'approved'
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                              ),
                                            )
                                          : const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Chat feature will be implemented next'),
                                      ),
                                    );
                                  },
                                  style: AppButtonStyles.primary(
                                    foregroundColor: AppColors.navyBg,
                                  ),
                                  child: const Text('Message'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.lightText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ApplicationsEmptyView extends StatelessWidget {
  const _ApplicationsEmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Text(
              'No applications yet',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Applications will appear here once you start applying to jobs.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationsErrorView extends StatelessWidget {
  const _ApplicationsErrorView({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 18),
            const Text(
              'Failed to load applications',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(error, style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

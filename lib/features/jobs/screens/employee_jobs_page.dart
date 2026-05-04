import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../applications/services/application_service.dart';
import '../services/job_service.dart';
import '../widgets/job_card.dart';

class EmployeeJobsPage extends StatefulWidget {
  const EmployeeJobsPage({super.key});

  @override
  State<EmployeeJobsPage> createState() => _EmployeeJobsPageState();
}

class _EmployeeJobsPageState extends State<EmployeeJobsPage> {
  final JobService _jobService = JobService();
  final ApplicationService _applicationService = ApplicationService();
  final Set<String> _submittingJobs = {};

  Future<void> _applyToJob(Map<String, dynamic> job) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Please log in to apply for jobs');
      return;
    }

    final jobId = job['jobId'] as String? ?? job['id'] as String? ?? '';
    final employerId = job['employerId'] as String? ?? '';
    final jobTitle = job['title'] as String? ?? '';

    if (jobId.isEmpty || employerId.isEmpty || jobTitle.isEmpty) {
      _showSnackBar('Unable to apply for this job. Missing job information.');
      return;
    }

    final message = await _showApplicationMessageDialog();
    if (message == null) return;

    setState(() {
      _submittingJobs.add(jobId);
    });

    try {
      await _applicationService.applyToJob(
        jobId: jobId,
        employerId: employerId,
        jobTitle: jobTitle,
        employeeId: currentUser.uid,
        message: message,
      );

      if (!mounted) return;
      _showSnackBar('Application submitted successfully');
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().replaceFirst('Exception: ', '');
        _showSnackBar(errorText);
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingJobs.remove(jobId);
        });
      }
    }
  }

  Future<String?> _showApplicationMessageDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Send a message'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Hi, I’m available today',
            ),
            style: AppTextStyles.input,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: AppButtonStyles.primary(
                foregroundColor: AppColors.navyBg,
              ),
              child: const Text('Send application'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey.shade900,
      ),
    );
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
                'Please sign in to view and apply for jobs.',
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
                'Jobs',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse available short-term jobs near you.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _jobService.getOpenJobs(),
                  builder: (context, jobSnapshot) {
                    if (jobSnapshot.hasError) {
                      return _JobErrorView(error: jobSnapshot.error.toString());
                    }

                    if (jobSnapshot.connectionState == ConnectionState.waiting) {
                      return const _JobLoadingView();
                    }

                    final jobs = jobSnapshot.data?.docs ?? [];
                    if (jobs.isEmpty) {
                      return const _JobEmptyView();
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _applicationService.getEmployeeApplications(currentUser.uid),
                      builder: (context, applicationSnapshot) {
                        if (applicationSnapshot.hasError) {
                          return _JobErrorView(
                            error: applicationSnapshot.error.toString(),
                          );
                        }

                        if (applicationSnapshot.connectionState == ConnectionState.waiting) {
                          return const _JobLoadingView();
                        }

                        final appliedJobIds = applicationSnapshot.data?.docs
                                .map((doc) => doc.data()['jobId'] as String? ?? '')
                                .where((id) => id.isNotEmpty)
                                .toSet() ??
                            {};

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: jobs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final job = jobs[index].data();
                            final jobId = jobs[index].id;
                            final alreadyApplied = appliedJobIds.contains(jobId);
                            final isSubmitting = _submittingJobs.contains(jobId);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                JobCard(job: {...job, 'jobId': jobId}),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: AppSpacing.buttonHeight,
                                  child: ElevatedButton(
                                    onPressed: alreadyApplied || isSubmitting
                                        ? null
                                        : () => _applyToJob({...job, 'jobId': jobId}),
                                    style: AppButtonStyles.primary(
                                      foregroundColor: AppColors.navyBg,
                                      disabledBackgroundColor:
                                          Colors.grey.shade700,
                                    ),
                                    child: isSubmitting
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppColors.navyBg,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            alreadyApplied ? 'Applied' : 'Apply',
                                            style: AppTextStyles.buttonLabel(
                                              color: AppColors.navyBg,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
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

class _JobLoadingView extends StatelessWidget {
  const _JobLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.coralAccent),
          ),
        ),
      ),
    );
  }
}

class _JobEmptyView extends StatelessWidget {
  const _JobEmptyView();

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
              'No jobs available',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'There are no open jobs available at the moment.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobErrorView extends StatelessWidget {
  const _JobErrorView({required this.error});

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
              'Failed to load jobs',
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

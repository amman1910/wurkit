import 'package:flutter/material.dart';

import '../../../core/theme/app_ui.dart';
import '../../../shared/utils/distance_utils.dart';
import '../../jobs/screens/job_details_page.dart';
import '../services/employee_home_service.dart';

class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key});

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  final EmployeeHomeService _service = EmployeeHomeService();
  final Map<String, Future<EmployerPreview?>> _employerPreviewCache = {};
  late final Stream<EmployeeHomeProfile?> _profileStream;
  late final Stream<List<EmployeeHomeJob>> _openJobsStream;

  bool _isUpdatingAvailability = false;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _profileStream = _service.watchCurrentEmployeeProfile();
    _openJobsStream = _service.watchOpenJobs();
  }

  Future<void> _updateAvailability(bool value) async {
    setState(() => _isUpdatingAvailability = true);

    try {
      await _service.updateAvailabilityNow(value);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'You are available now' : 'Availability updated',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvailability = false);
      }
    }
  }

  Future<void> _enableLocation() async {
    setState(() => _isUpdatingLocation = true);

    try {
      await _service.enableAndSaveCurrentLocation();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Location enabled')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
    }
  }

  Future<EmployerPreview?> _employerPreviewFor(String employerId) {
    return _employerPreviewCache.putIfAbsent(
      employerId,
      () => _service.getEmployerPreview(employerId),
    );
  }

  void _openJobDetails(EmployeeHomeJob job) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => JobDetailsPage(jobId: job.id)),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: StreamBuilder<EmployeeHomeProfile?>(
          stream: _profileStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingHomeState();
            }

            if (snapshot.hasError) {
              return _HomeErrorState(message: _friendlyError(snapshot.error!));
            }

            final profile = snapshot.data;
            if (profile == null) {
              return const _HomeErrorState(
                message: 'Employee profile not found.',
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.horizontal,
                AppSpacing.vertical,
                AppSpacing.horizontal,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _HomeHeaderLogo(),
                  const SizedBox(height: 14),
                  _PersonalHeader(profile: profile),
                  const SizedBox(height: 18),
                  _AvailabilityCard(
                    isAvailableNow: profile.isAvailableNow,
                    isUpdating: _isUpdatingAvailability,
                    onChanged: _updateAvailability,
                  ),
                  if (!profile.locationPermissionGranted) ...[
                    const SizedBox(height: 14),
                    _LocationPermissionCard(
                      isLoading: _isUpdatingLocation,
                      onTap: _enableLocation,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section + 8),
                  _JobsHomeContent(
                    profile: profile,
                    jobsStream: _openJobsStream,
                    employerPreviewFor: _employerPreviewFor,
                    onJobTap: _openJobDetails,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeaderLogo extends StatelessWidget {
  const _HomeHeaderLogo();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoHeight = (screenWidth * 0.34).clamp(105.0, 130.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Image.asset(
          'assets/images/wurkit_retro_header.png',
          width: double.infinity,
          height: logoHeight,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PersonalHeader extends StatelessWidget {
  const _PersonalHeader({required this.profile});

  final EmployeeHomeProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.name;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? 'Hi' : 'Hi, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  profile.isAvailableNow
                      ? "You're available for work now"
                      : "Set yourself available when you're ready",
                  key: ValueKey(profile.isAvailableNow),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _ProfileAvatar(imageUrl: profile.profileImageUrl),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _AvatarFallback(),
            )
          : const _AvatarFallback(),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.coralAccent.withValues(alpha: 0.14),
      child: const Icon(
        Icons.person_outline_rounded,
        color: AppColors.coralAccent,
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.isAvailableNow,
    required this.isUpdating,
    required this.onChanged,
  });

  final bool isAvailableNow;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isAvailableNow
                  ? AppColors.coralAccent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isAvailableNow ? Icons.bolt_rounded : Icons.bolt_outlined,
              color: isAvailableNow ? AppColors.coralAccent : Colors.white60,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available now',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Let employers know you can start soon.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: isUpdating
                ? const SizedBox(
                    key: ValueKey('availability-loading'),
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.coralAccent,
                    ),
                  )
                : Switch(
                    key: const ValueKey('availability-switch'),
                    value: isAvailableNow,
                    activeThumbColor: AppColors.coralAccent,
                    activeTrackColor: AppColors.coralAccent.withValues(
                      alpha: 0.4,
                    ),
                    inactiveThumbColor: Colors.white70,
                    inactiveTrackColor: Colors.white24,
                    onChanged: onChanged,
                  ),
          ),
        ],
      ),
    );
  }
}

class _LocationPermissionCard extends StatelessWidget {
  const _LocationPermissionCard({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.near_me_outlined,
              color: AppColors.coralAccent,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Turn on location to see nearby jobs',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: AppButtonStyles.primary(
                foregroundColor: AppColors.navyBg,
                disabledBackgroundColor: AppColors.border,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.navyBg,
                      ),
                    )
                  : Text(
                      'Enable location',
                      style: AppTextStyles.buttonLabel(fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsHomeContent extends StatelessWidget {
  const _JobsHomeContent({
    required this.profile,
    required this.jobsStream,
    required this.employerPreviewFor,
    required this.onJobTap,
  });

  final EmployeeHomeProfile profile;
  final Stream<List<EmployeeHomeJob>> jobsStream;
  final Future<EmployerPreview?> Function(String employerId) employerPreviewFor;
  final ValueChanged<EmployeeHomeJob> onJobTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmployeeHomeJob>>(
      stream: jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _JobsContentScaffold(
            profile: profile,
            jobs: const [],
            isLoading: true,
            employerPreviewFor: employerPreviewFor,
            onJobTap: onJobTap,
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TodaySnapshotCard(
                isAvailableNow: profile.isAvailableNow,
                locationEnabled: profile.locationPermissionGranted,
                openJobsCount: 0,
              ),
              const SizedBox(height: AppSpacing.section + 8),
              const _HomeCard(
                child: Text(
                  'Could not load jobs right now.',
                  style: AppTextStyles.body,
                ),
              ),
            ],
          );
        }

        return _JobsContentScaffold(
          profile: profile,
          jobs: snapshot.data ?? const <EmployeeHomeJob>[],
          isLoading: false,
          employerPreviewFor: employerPreviewFor,
          onJobTap: onJobTap,
        );
      },
    );
  }
}

class _JobsContentScaffold extends StatelessWidget {
  const _JobsContentScaffold({
    required this.profile,
    required this.jobs,
    required this.isLoading,
    required this.employerPreviewFor,
    required this.onJobTap,
  });

  final EmployeeHomeProfile profile;
  final List<EmployeeHomeJob> jobs;
  final bool isLoading;
  final Future<EmployerPreview?> Function(String employerId) employerPreviewFor;
  final ValueChanged<EmployeeHomeJob> onJobTap;

  @override
  Widget build(BuildContext context) {
    final distances = <String, double?>{
      for (final job in jobs) job.id: _distanceTo(job),
    };
    final nearbyJobs = _nearbyJobs(distances);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TodaySnapshotCard(
          isAvailableNow: profile.isAvailableNow,
          locationEnabled: profile.locationPermissionGranted,
          openJobsCount: jobs.length,
        ),
        const SizedBox(height: AppSpacing.section + 8),
        _RecommendedJobsSection(
          jobs: jobs,
          isLoading: isLoading,
          distanceFor: (job) => distances[job.id],
          employerPreviewFor: employerPreviewFor,
          onJobTap: onJobTap,
        ),
        const SizedBox(height: AppSpacing.section + 8),
        _RecommendedJobsSection(
          title: 'Nearby jobs',
          jobs: nearbyJobs,
          isLoading: isLoading,
          distanceFor: (job) => distances[job.id],
          emptyMessage: profile.hasUsableLocation
              ? 'No nearby jobs available right now.'
              : 'Enable location to see nearby jobs.',
          employerPreviewFor: employerPreviewFor,
          onJobTap: onJobTap,
        ),
      ],
    );
  }

  double? _distanceTo(EmployeeHomeJob job) {
    if (!profile.hasUsableLocation || !job.hasCoordinates) return null;
    return calculateDistanceKm(
      lat1: profile.latitude!,
      lng1: profile.longitude!,
      lat2: job.latitude!,
      lng2: job.longitude!,
    );
  }

  List<EmployeeHomeJob> _nearbyJobs(Map<String, double?> distances) {
    if (!profile.hasUsableLocation) return const [];
    final withDistance =
        jobs
            .where((job) => distances[job.id] != null)
            .map((job) => (job: job, distance: distances[job.id]!))
            .toList()
          ..sort((left, right) => left.distance.compareTo(right.distance));
    return withDistance.take(5).map((item) => item.job).toList();
  }
}

class _TodaySnapshotCard extends StatelessWidget {
  const _TodaySnapshotCard({
    required this.isAvailableNow,
    required this.locationEnabled,
    required this.openJobsCount,
  });

  final bool isAvailableNow;
  final bool locationEnabled;
  final int openJobsCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Today'),
        const SizedBox(height: 12),
        _HomeCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _TodayMiniStat(
                  label: 'Available now',
                  value: isAvailableNow ? 'Yes' : 'No',
                  icon: Icons.bolt_rounded,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _TodayMiniStat(
                  label: 'Open jobs',
                  value: openJobsCount.toString(),
                  icon: Icons.work_outline_rounded,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _TodayMiniStat(
                  label: 'Location',
                  value: locationEnabled ? 'Enabled' : 'Not enabled',
                  icon: Icons.near_me_outlined,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodayMiniStat extends StatelessWidget {
  const _TodayMiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.coralAccent, size: 19),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.lightText, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }
}

class _RecommendedJobsSection extends StatelessWidget {
  const _RecommendedJobsSection({
    this.title = 'Recommended for you',
    required this.jobs,
    required this.isLoading,
    required this.distanceFor,
    this.emptyMessage,
    required this.employerPreviewFor,
    required this.onJobTap,
  });

  final List<EmployeeHomeJob> jobs;
  final String title;
  final bool isLoading;
  final double? Function(EmployeeHomeJob job) distanceFor;
  final String? emptyMessage;
  final Future<EmployerPreview?> Function(String employerId) employerPreviewFor;
  final ValueChanged<EmployeeHomeJob> onJobTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 14),
        if (isLoading)
          const SizedBox(
            height: 210,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.coralAccent),
            ),
          )
        else if (jobs.isEmpty)
          _EmptyJobsState(message: emptyMessage)
        else
          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: jobs.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.78,
                  child: _RecommendedJobCard(
                    job: jobs[index],
                    distanceKm: distanceFor(jobs[index]),
                    employerPreviewFuture: employerPreviewFor(
                      jobs[index].employerId,
                    ),
                    onTap: () => onJobTap(jobs[index]),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RecommendedJobCard extends StatelessWidget {
  const _RecommendedJobCard({
    required this.job,
    required this.employerPreviewFuture,
    this.distanceKm,
    required this.onTap,
  });

  final EmployeeHomeJob job;
  final Future<EmployerPreview?> employerPreviewFuture;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployerPreview?>(
      future: employerPreviewFuture,
      builder: (context, snapshot) {
        final employer = snapshot.data;
        final locationText = _locationText(job, employer);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _EmployerLogo(imageUrl: employer?.businessLogoUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employer?.businessName ?? 'Wurkit employer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.label,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      locationText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  if (distanceKm != null)
                                    Text(
                                      ' · ${distanceKm!.toStringAsFixed(1)} km away',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: AppColors.coralAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (job.urgent) const _UrgentBadge(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    if (job.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        job.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if (job.salary != null)
                          Expanded(
                            child: Text(
                              _salaryText(job),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.coralAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.coralAccent,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _locationText(EmployeeHomeJob job, EmployerPreview? employer) {
    return job.location ?? employer?.businessAddress ?? 'Location shared soon';
  }

  String _salaryText(EmployeeHomeJob job) {
    final amount = job.salary!;
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final type = job.salaryType == null ? '' : ' ${job.salaryType}';
    return '\$$formatted$type';
  }
}

class _EmployerLogo extends StatelessWidget {
  const _EmployerLogo({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? const Icon(Icons.storefront_outlined, color: AppColors.coralAccent)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.storefront_outlined,
                color: AppColors.coralAccent,
              ),
            ),
    );
  }
}

class _UrgentBadge extends StatelessWidget {
  const _UrgentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.coralAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Urgent',
        style: TextStyle(
          color: AppColors.coralAccent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyJobsState extends StatelessWidget {
  const _EmptyJobsState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: Row(
        children: [
          const Icon(Icons.work_outline_rounded, color: AppColors.coralAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message ?? 'No open jobs yet',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (message == null) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'New jobs will appear here when employers post them',
                    style: AppTextStyles.label,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LoadingHomeState extends StatelessWidget {
  const _LoadingHomeState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.coralAccent),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.horizontal),
        child: _HomeCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.coralAccent,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_ui.dart';
import '../../../shared/utils/distance_utils.dart';
import '../models/employee_job_discovery_item.dart';
import '../services/employee_job_discovery_service.dart';
import '../widgets/employee_job_card.dart';
import '../widgets/employee_job_result_card.dart';
import '../widgets/job_discovery_action_buttons.dart';
import 'job_details_page.dart';

enum _DateFilter { any, today, tomorrow, thisWeek, custom }

enum _ShiftFilter { any, morning, afternoon, evening, custom }

enum _SwipeDecision { apply, notInterested }

class _JobFilters {
  const _JobFilters({
    this.salaryRange = const RangeValues(20, 100),
    this.dateFilter = _DateFilter.any,
    this.customFrom,
    this.customTo,
    this.shiftFilter = _ShiftFilter.any,
    this.customShiftStart,
    this.customShiftEnd,
    this.radiusKm = 0,
  });

  final RangeValues salaryRange;
  final _DateFilter dateFilter;
  final DateTime? customFrom;
  final DateTime? customTo;
  final _ShiftFilter shiftFilter;
  final TimeOfDay? customShiftStart;
  final TimeOfDay? customShiftEnd;
  final int radiusKm;

  bool get hasSalaryFilter => salaryRange.start > 20 || salaryRange.end < 100;
  bool get hasDateFilter => dateFilter != _DateFilter.any;
  bool get hasShiftFilter => shiftFilter != _ShiftFilter.any;
  bool get hasRadiusFilter => radiusKm > 0;
  bool get hasActiveFilters =>
      hasSalaryFilter || hasDateFilter || hasShiftFilter || hasRadiusFilter;

  _JobFilters copyWith({
    RangeValues? salaryRange,
    _DateFilter? dateFilter,
    DateTime? customFrom,
    DateTime? customTo,
    bool clearCustomDates = false,
    _ShiftFilter? shiftFilter,
    TimeOfDay? customShiftStart,
    TimeOfDay? customShiftEnd,
    bool clearCustomShift = false,
    int? radiusKm,
  }) {
    return _JobFilters(
      salaryRange: salaryRange ?? this.salaryRange,
      dateFilter: dateFilter ?? this.dateFilter,
      customFrom: clearCustomDates ? null : customFrom ?? this.customFrom,
      customTo: clearCustomDates ? null : customTo ?? this.customTo,
      shiftFilter: shiftFilter ?? this.shiftFilter,
      customShiftStart: clearCustomShift
          ? null
          : customShiftStart ?? this.customShiftStart,
      customShiftEnd: clearCustomShift
          ? null
          : customShiftEnd ?? this.customShiftEnd,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }
}

class EmployeeJobsPage extends StatefulWidget {
  const EmployeeJobsPage({super.key});

  @override
  State<EmployeeJobsPage> createState() => _EmployeeJobsPageState();
}

class _EmployeeJobsPageState extends State<EmployeeJobsPage>
    with SingleTickerProviderStateMixin {
  final EmployeeJobDiscoveryService _service = EmployeeJobDiscoveryService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyJobIds = {};
  late final AnimationController _swipeAnimationController;

  List<EmployeeJobDiscoveryItem> _jobs = [];
  Set<String> _savedJobIds = {};
  ({double latitude, double longitude})? _employeeLocation;
  _JobFilters _filters = const _JobFilters();
  bool _isLoading = true;
  String? _error;
  String _searchText = '';
  int _cardVersion = 0;
  int _feedbackVersion = 0;
  _ActionFeedback? _actionFeedback;
  Timer? _feedbackTimer;
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0;
  bool _isAnimatingSwipe = false;

  bool get _isSearching => _searchText.isNotEmpty;

  EmployeeJobDiscoveryItem? get _currentJob =>
      _visibleJobs.isEmpty ? null : _visibleJobs.first;

  List<EmployeeJobDiscoveryItem> get _visibleJobs => _filteredJobs(_jobs);

  @override
  void initState() {
    super.initState();
    _swipeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim().toLowerCase());
    });
    _loadJobs();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _swipeAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.loadJobs(),
        _service.loadSavedJobIds(),
        _service.loadEmployeeLocation(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _jobs = results[0] as List<EmployeeJobDiscoveryItem>;
        _savedJobIds = results[1] as Set<String>;
        _employeeLocation =
            results[2] as ({double latitude, double longitude})?;
        _cardVersion++;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _apply(
    EmployeeJobDiscoveryItem job, {
    bool fromDetails = false,
  }) async {
    if (_busyJobIds.contains(job.id)) {
      return false;
    }

    HapticFeedback.lightImpact();
    setState(() => _busyJobIds.add(job.id));

    try {
      await _service.applyToJob(job);
      if (!mounted) {
        return false;
      }
      await _removeSavedIfNeeded(job.id, reason: 'applied');
      _resetSwipeState();
      _removeJob(job.id);
      _showActionFeedback(
        icon: Icons.check_circle_rounded,
        text: 'Application sent',
        color: const Color(0xFF6FD37A),
      );
      if (fromDetails) {
        debugPrint('EmployeeJobsPage: Apply from details succeeded ${job.id}');
      }
      return true;
    } catch (error) {
      if (mounted) {
        _showSnackBar(_friendlyError(error));
      }
      if (fromDetails) {
        debugPrint(
          'EmployeeJobsPage: Apply from details failed ${job.id}: $error',
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busyJobIds.remove(job.id));
      }
    }
  }

  Future<bool> _markNotInterested(
    EmployeeJobDiscoveryItem job, {
    bool fromDetails = false,
  }) async {
    if (_busyJobIds.contains(job.id)) {
      return false;
    }

    debugPrint('EmployeeJobsPage: Not Interested pressed ${job.id}');
    HapticFeedback.mediumImpact();
    setState(() => _busyJobIds.add(job.id));

    try {
      await _service.markNotInterested(job);
      if (!mounted) {
        return false;
      }
      await _removeSavedIfNeeded(job.id, reason: 'not_interested');
      _resetSwipeState();
      _removeJob(job.id);
      _showActionFeedback(
        icon: Icons.block_rounded,
        text: 'Removed from your feed',
        color: const Color(0xFFFF7A68),
      );
      return true;
    } catch (error) {
      if (mounted) {
        _showSnackBar(_friendlyError(error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busyJobIds.remove(job.id));
      }
    }
  }

  void _skipCurrentJob() {
    final currentJob = _currentJob;
    if (currentJob == null) {
      return;
    }

    _skipJob(currentJob);
  }

  bool _skipJob(EmployeeJobDiscoveryItem job, {bool fromDetails = false}) {
    debugPrint('EmployeeJobsPage: Skip pressed ${job.id}');
    final skippedIndex = _jobs.indexWhere((item) => item.id == job.id);
    if (skippedIndex < 0) {
      debugPrint(
        'EmployeeJobsPage: Skip ignored because job is not in queue ${job.id}',
      );
      return false;
    }

    final visibleJobs = _visibleJobs;
    if (visibleJobs.length <= 1) {
      HapticFeedback.selectionClick();
      setState(() => _cardVersion++);
      _showActionFeedback(
        icon: Icons.keyboard_double_arrow_right_rounded,
        text: 'Skipped for now',
        color: AppColors.coralAccent,
      );
      debugPrint(
        'EmployeeJobsPage: Skip kept ${job.id} in place because queue has ${visibleJobs.length} visible job(s)',
      );
      return true;
    }

    HapticFeedback.selectionClick();
    setState(() {
      final skipped = _jobs.removeAt(skippedIndex);
      _jobs.add(skipped);
      _cardVersion++;
    });
    _showActionFeedback(
      icon: Icons.keyboard_double_arrow_right_rounded,
      text: 'Skipped for now',
      color: AppColors.coralAccent,
    );
    debugPrint('EmployeeJobsPage: Job moved to end of queue ${job.id}');
    return true;
  }

  void _removeJob(String jobId) {
    setState(() {
      _jobs.removeWhere((job) => job.id == jobId);
      _cardVersion++;
    });
  }

  Future<void> _toggleSaved(EmployeeJobDiscoveryItem job) async {
    final wasSaved = _savedJobIds.contains(job.id);
    setState(() {
      if (wasSaved) {
        _savedJobIds.remove(job.id);
      } else {
        _savedJobIds.add(job.id);
      }
    });

    try {
      if (wasSaved) {
        await _service.unsaveJob(job.id);
      } else {
        await _service.saveJob(job);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (wasSaved) {
          _savedJobIds.add(job.id);
        } else {
          _savedJobIds.remove(job.id);
        }
      });
      _showSnackBar(_friendlyError(error));
    }
  }

  Future<void> _removeSavedIfNeeded(
    String jobId, {
    required String reason,
  }) async {
    if (!_savedJobIds.contains(jobId)) {
      return;
    }

    setState(() => _savedJobIds.remove(jobId));
    try {
      await _service.unsaveJob(jobId);
      if (reason == 'not_interested') {
        debugPrint(
          'EmployeeJobsPage: Saved job removed because not interested $jobId',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint(
        'EmployeeJobsPage: Saved job cleanup failed for $jobId: $error',
      );
      _showSnackBar(_friendlyError(error));
    }
  }

  Future<void> _openFilters() async {
    final nextFilters = await showModalBottomSheet<_JobFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobFilterSheet(filters: _filters),
    );
    if (nextFilters == null || !mounted) {
      return;
    }
    setState(() {
      _filters = nextFilters;
      _cardVersion++;
    });
  }

  Future<void> _openSavedJobs() async {
    final jobs = await _service.loadSavedJobs();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedJobsSheet(
        jobs: jobs,
        savedJobIds: _savedJobIds,
        onToggleSaved: (job) => _toggleSaved(job),
        onViewJob: (job) {
          Navigator.of(context).pop();
          _openDetails(job);
        },
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _completeSwipe(
    EmployeeJobDiscoveryItem job,
    _SwipeDecision decision,
  ) async {
    if (_isAnimatingSwipe || _busyJobIds.contains(job.id)) {
      return;
    }

    final direction = decision == _SwipeDecision.apply ? 1.0 : -1.0;
    setState(() => _isAnimatingSwipe = true);
    await _animateSwipeTo(Offset(direction * 520, _dragOffset.dy));

    if (decision == _SwipeDecision.apply) {
      await _apply(job);
    } else {
      await _markNotInterested(job);
    }

    if (mounted) {
      if (_jobs.any((item) => item.id == job.id)) {
        await _animateSwipeHome();
      }
      setState(() => _isAnimatingSwipe = false);
    }
  }

  Future<void> _animateSwipeTo(Offset target) async {
    final start = _dragOffset;
    final animation = CurvedAnimation(
      parent: _swipeAnimationController,
      curve: Curves.easeOutCubic,
    );
    _swipeAnimationController
      ..stop()
      ..reset();

    final progress = Tween<double>(begin: 0, end: 1).animate(animation);
    void updateSwipePosition() {
      if (!mounted) {
        return;
      }
      setState(() {
        _dragOffset = Offset.lerp(start, target, progress.value)!;
        _dragRotation = (_dragOffset.dx / 330).clamp(-0.18, 0.18);
      });
    }

    progress.addListener(updateSwipePosition);

    await _swipeAnimationController.forward();
    progress.removeListener(updateSwipePosition);
  }

  Future<void> _animateSwipeHome() async {
    await _animateSwipeTo(Offset.zero);
    _resetSwipeState();
  }

  void _resetSwipeState() {
    if (!mounted) {
      return;
    }
    setState(() {
      _dragOffset = Offset.zero;
      _dragRotation = 0;
    });
  }

  void _openDetails(EmployeeJobDiscoveryItem job) {
    debugPrint(
      'EmployeeJobsPage: JobDetailsPage opened in discovery mode ${job.id}',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailsPage(
          jobId: job.id,
          showDiscoveryActions: true,
          onDiscoveryNotInterested: () =>
              _markNotInterested(job, fromDetails: true),
          onDiscoverySkip: () async => _skipJob(job, fromDetails: true),
          onDiscoveryApply: () => _apply(job, fromDetails: true),
        ),
      ),
    );
  }

  List<EmployeeJobDiscoveryItem> get _searchResults {
    return _visibleJobs;
  }

  List<EmployeeJobDiscoveryItem> _filteredJobs(
    List<EmployeeJobDiscoveryItem> source,
  ) {
    final text = _searchText;
    return source.where((job) {
      final matchesText = job.searchText.contains(text);
      if (!matchesText) {
        return false;
      }
      return _matchesSalary(job) &&
          _matchesDate(job) &&
          _matchesShift(job) &&
          _matchesRadius(job);
    }).toList();
  }

  bool _matchesSalary(EmployeeJobDiscoveryItem job) {
    if (!_filters.hasSalaryFilter) {
      return true;
    }
    final amount = job.salaryAmount;
    if (amount == null) {
      return false;
    }
    return amount >= _filters.salaryRange.start &&
        (_filters.salaryRange.end >= 100 || amount <= _filters.salaryRange.end);
  }

  double? _distanceTo(EmployeeJobDiscoveryItem job) {
    final employee = _employeeLocation;
    final lat = job.latitude;
    final lng = job.longitude;
    if (employee == null || lat == null || lng == null) return null;
    return calculateDistanceKm(
      lat1: employee.latitude,
      lng1: employee.longitude,
      lat2: lat,
      lng2: lng,
    );
  }

  bool _matchesRadius(EmployeeJobDiscoveryItem job) {
    if (!_filters.hasRadiusFilter) return true;
    final distance = _distanceTo(job);
    return distance != null && distance <= _filters.radiusKm;
  }

  bool _matchesDate(EmployeeJobDiscoveryItem job) {
    final date = job.startDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return switch (_filters.dateFilter) {
      _DateFilter.any => true,
      _DateFilter.today =>
        job.startAsSoonAsPossible || (date != null && _sameDay(date, today)),
      _DateFilter.tomorrow => date != null && _sameDay(date, tomorrow),
      _DateFilter.thisWeek =>
        date != null &&
            !date.isBefore(today) &&
            date.isBefore(today.add(const Duration(days: 7))),
      _DateFilter.custom => _matchesCustomDate(date),
    };
  }

  bool _matchesCustomDate(DateTime? date) {
    if (date == null) {
      return false;
    }
    final from = _filters.customFrom;
    final to = _filters.customTo;
    if (from != null && date.isBefore(_dateOnly(from))) {
      return false;
    }
    if (to != null &&
        date.isAfter(_dateOnly(to).add(const Duration(days: 1)))) {
      return false;
    }
    return true;
  }

  bool _matchesShift(EmployeeJobDiscoveryItem job) {
    final start = job.shiftStartMinutes;
    final end = job.shiftEndMinutes ?? start;
    return switch (_filters.shiftFilter) {
      _ShiftFilter.any => true,
      _ShiftFilter.morning => start != null && start < 12 * 60,
      _ShiftFilter.afternoon =>
        start != null && start >= 12 * 60 && start < 17 * 60,
      _ShiftFilter.evening => start != null && start >= 17 * 60,
      _ShiftFilter.custom => _matchesCustomShift(start, end),
    };
  }

  bool _matchesCustomShift(int? start, int? end) {
    if (start == null) {
      return false;
    }
    final filterStart = _minutesFromTime(_filters.customShiftStart);
    final filterEnd = _minutesFromTime(_filters.customShiftEnd);
    if (filterStart != null && start < filterStart) {
      return false;
    }
    if (filterEnd != null && (end ?? start) > filterEnd) {
      return false;
    }
    return true;
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showActionFeedback({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    _feedbackTimer?.cancel();
    final version = ++_feedbackVersion;
    setState(() {
      _actionFeedback = _ActionFeedback(icon: icon, text: text, color: color);
    });

    _feedbackTimer = Timer(const Duration(milliseconds: 950), () {
      if (!mounted || version != _feedbackVersion) {
        return;
      }
      setState(() => _actionFeedback = null);
    });
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const _AuthRequiredView();
    }

    return Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _body(),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 100,
              child: IgnorePointer(
                child: _ActionFeedbackOverlay(feedback: _actionFeedback),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const _LoadingView();
    }

    final error = _error;
    if (error != null) {
      return _ErrorView(error: error, onRetry: _loadJobs);
    }

    return _isSearching ? _searchResultsMode() : _discoveryMode();
  }

  Widget _discoveryMode() {
    final currentJob = _currentJob;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiscoveryHeader(
            hasActiveFilters: _filters.hasActiveFilters,
            savedCount: _savedJobIds.length,
            onOpenSaved: _openSavedJobs,
            onOpenFilters: _openFilters,
          ),
          const SizedBox(height: 12),
          _SearchField(
            controller: _searchController,
            hint: 'Search by job title, business or location',
          ),
          if (_filters.hasActiveFilters) ...[
            const SizedBox(height: 10),
            _ActiveFilterSummary(
              onClear: () {
                setState(() {
                  _filters = const _JobFilters();
                  _cardVersion++;
                });
              },
            ),
          ],
          const SizedBox(height: 10),
          if (currentJob == null)
            Expanded(
              child: _jobs.isEmpty
                  ? _NoJobsView(onRefresh: _loadJobs)
                  : _NoFilterMatchesView(
                      onClear: () {
                        setState(() {
                          _filters = const _JobFilters();
                          _searchController.clear();
                          _cardVersion++;
                        });
                      },
                    ),
            )
          else ...[
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) {
                  final offset =
                      Tween<Offset>(
                        begin: const Offset(0.08, 0.02),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: EmployeeJobCard(
                  key: ValueKey('${currentJob.id}-$_cardVersion'),
                  job: currentJob,
                  distanceKm: _distanceTo(currentJob),
                  isSaved: _savedJobIds.contains(currentJob.id),
                  onViewDetails: () => _openDetails(currentJob),
                  onToggleSaved: () => _toggleSaved(currentJob),
                  actionButtons: JobDiscoveryActionButtons(
                    isBusy: _busyJobIds.contains(currentJob.id),
                    onNotInterested: () => _completeSwipe(
                      currentJob,
                      _SwipeDecision.notInterested,
                    ),
                    onSkip: _skipCurrentJob,
                    onApply: () =>
                        _completeSwipe(currentJob, _SwipeDecision.apply),
                  ),
                ),
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null)
                        _SwipeableJobCard(
                          dragOffset: _dragOffset,
                          rotation: _dragRotation,
                          isBusy:
                              _isAnimatingSwipe ||
                              _busyJobIds.contains(currentJob.id),
                          onDragUpdate: (details) {
                            setState(() {
                              _dragOffset += details.delta;
                              _dragRotation = (_dragOffset.dx / 330).clamp(
                                -0.18,
                                0.18,
                              );
                            });
                          },
                          onDragEnd: () {
                            final threshold =
                                MediaQuery.sizeOf(context).width * 0.28;
                            if (_dragOffset.dx > threshold) {
                              _completeSwipe(currentJob, _SwipeDecision.apply);
                            } else if (_dragOffset.dx < -threshold) {
                              _completeSwipe(
                                currentJob,
                                _SwipeDecision.notInterested,
                              );
                            } else {
                              _animateSwipeHome();
                            }
                          },
                          child: currentChild,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchResultsMode() {
    final results = _searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => _searchController.clear(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SearchField(
                  controller: _searchController,
                  hint: 'Search jobs',
                  autofocus: true,
                ),
              ),
              TextButton(
                onPressed: () => _searchController.clear(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.coralAccent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _ActiveFilterSummary(
                  onClear: _filters.hasActiveFilters
                      ? () {
                          setState(() {
                            _filters = const _JobFilters();
                            _cardVersion++;
                          });
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              _CircleIconButton(
                icon: Icons.tune_rounded,
                onTap: _openFilters,
                isActive: _filters.hasActiveFilters,
                size: 42,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${results.length} jobs found',
                  style: AppTextStyles.label,
                ),
              ),
              RichText(
                text: const TextSpan(
                  style: TextStyle(color: AppColors.lightText, fontSize: 14),
                  children: [
                    TextSpan(text: 'Sort: '),
                    TextSpan(
                      text: 'Newest',
                      style: TextStyle(
                        color: AppColors.coralAccent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.coralAccent,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: results.isEmpty
              ? const _NoSearchResultsView()
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final job = results[index];
                    return EmployeeJobResultCard(
                      job: job,
                      isApplying: _busyJobIds.contains(job.id),
                      isSaved: _savedJobIds.contains(job.id),
                      onTap: () => _openDetails(job),
                      onApply: () => _apply(job),
                      onToggleSaved: () => _toggleSaved(job),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ActionFeedback {
  const _ActionFeedback({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;
}

class _ActionFeedbackOverlay extends StatelessWidget {
  const _ActionFeedbackOverlay({required this.feedback});

  final _ActionFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: feedback == null
          ? const SizedBox.shrink(key: ValueKey('empty-feedback'))
          : Center(
              key: ValueKey(feedback!.text),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: feedback!.color.withValues(alpha: 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: feedback!.color.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feedback!.icon, color: feedback!.color, size: 21),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        feedback!.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({
    required this.hasActiveFilters,
    required this.savedCount,
    required this.onOpenSaved,
    required this.onOpenFilters,
  });

  final bool hasActiveFilters;
  final int savedCount;
  final VoidCallback onOpenSaved;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Find Jobs',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Swipe through jobs and find your next shift',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CircleIconButton(
          icon: savedCount > 0 ? Icons.favorite_rounded : Icons.favorite_border,
          onTap: onOpenSaved,
          isActive: savedCount > 0,
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          icon: Icons.tune_rounded,
          onTap: onOpenFilters,
          isActive: hasActiveFilters,
        ),
      ],
    );
  }
}

class _ActiveFilterSummary extends StatelessWidget {
  const _ActiveFilterSummary({required this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final active = onClear != null;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active
            ? AppColors.coralAccent.withValues(alpha: 0.14)
            : AppColors.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? AppColors.coralAccent.withValues(alpha: 0.55)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.filter_alt_rounded : Icons.filter_alt_off_outlined,
            color: active ? AppColors.coralAccent : AppColors.lightText,
            size: 17,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              active ? 'Filters active' : 'Any salary, date and time',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? AppColors.white : AppColors.lightText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (active) ...[
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.coralAccent,
                size: 17,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwipeableJobCard extends StatelessWidget {
  const _SwipeableJobCard({
    required this.dragOffset,
    required this.rotation,
    required this.isBusy,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.child,
  });

  final Offset dragOffset;
  final double rotation;
  final bool isBusy;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final progress = (dragOffset.dx.abs() / (width * 0.34)).clamp(0.0, 1.0);
    final isApply = dragOffset.dx >= 0;
    final color = isApply ? const Color(0xFF6FD37A) : const Color(0xFFFF7A68);

    return GestureDetector(
      onPanUpdate: isBusy ? null : onDragUpdate,
      onPanEnd: isBusy ? null : (_) => onDragEnd(),
      onPanCancel: isBusy ? null : onDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 80),
                opacity: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.26),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: isApply ? -0.08 : 0.08,
                      child: _SwipeLabel(
                        icon: isApply
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        label: isApply
                            ? (progress > 0.82 ? 'APPLIED!' : 'APPLY')
                            : 'NOT INTERESTED',
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: dragOffset,
            child: Transform.rotate(angle: rotation, child: child),
          ),
        ],
      ),
    );
  }
}

class _SwipeLabel extends StatelessWidget {
  const _SwipeLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        style: AppTextStyles.input,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.hint,
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
          filled: true,
          fillColor: AppColors.surface.withValues(alpha: 0.58),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: AppColors.coralAccent),
          ),
        ),
      ),
    );
  }
}

class _JobFilterSheet extends StatefulWidget {
  const _JobFilterSheet({required this.filters});

  final _JobFilters filters;

  @override
  State<_JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends State<_JobFilterSheet> {
  late _JobFilters _draft = widget.filters;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF111B30),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.lightText,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _SheetSectionTitle('Distance'),
              _ChipWrap<int>(
                items: const [
                  (0, 'Any distance'),
                  (5, '5 km'),
                  (10, '10 km'),
                  (25, '25 km'),
                  (50, '50 km'),
                ],
                selected: _draft.radiusKm,
                onSelected: (value) =>
                    setState(() => _draft = _draft.copyWith(radiusKm: value)),
              ),
              const SizedBox(height: 18),
              _SheetLabel(
                title: 'Salary range',
                value: _draft.hasSalaryFilter
                    ? '${_money(_draft.salaryRange.start)} - ${_draft.salaryRange.end >= 100 ? '₪100+' : _money(_draft.salaryRange.end)}'
                    : 'Any salary',
              ),
              RangeSlider(
                min: 20,
                max: 100,
                divisions: 16,
                values: _draft.salaryRange,
                activeColor: const Color(0xFF6FD37A),
                inactiveColor: AppColors.border,
                labels: RangeLabels(
                  _money(_draft.salaryRange.start),
                  _draft.salaryRange.end >= 100
                      ? '₪100+'
                      : _money(_draft.salaryRange.end),
                ),
                onChanged: (value) => setState(
                  () => _draft = _draft.copyWith(salaryRange: value),
                ),
              ),
              const SizedBox(height: 10),
              const _SheetSectionTitle('Date'),
              _ChipWrap(
                items: const [
                  (_DateFilter.any, 'Any date'),
                  (_DateFilter.today, 'Today'),
                  (_DateFilter.tomorrow, 'Tomorrow'),
                  (_DateFilter.thisWeek, 'This week'),
                  (_DateFilter.custom, 'Custom'),
                ],
                selected: _draft.dateFilter,
                onSelected: (value) => setState(() {
                  _draft = _draft.copyWith(
                    dateFilter: value,
                    clearCustomDates: value != _DateFilter.custom,
                  );
                }),
              ),
              if (_draft.dateFilter == _DateFilter.custom) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: 'From',
                        value: _formatDate(_draft.customFrom) ?? 'Any',
                        onTap: () async {
                          final date = await _pickDate(_draft.customFrom);
                          if (date != null) {
                            setState(
                              () => _draft = _draft.copyWith(customFrom: date),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerField(
                        label: 'To',
                        value: _formatDate(_draft.customTo) ?? 'Any',
                        onTap: () async {
                          final date = await _pickDate(_draft.customTo);
                          if (date != null) {
                            setState(
                              () => _draft = _draft.copyWith(customTo: date),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const _SheetSectionTitle('Shift time'),
              _ChipWrap(
                items: const [
                  (_ShiftFilter.any, 'Any time'),
                  (_ShiftFilter.morning, 'Morning'),
                  (_ShiftFilter.afternoon, 'Afternoon'),
                  (_ShiftFilter.evening, 'Evening'),
                  (_ShiftFilter.custom, 'Custom'),
                ],
                selected: _draft.shiftFilter,
                onSelected: (value) => setState(() {
                  _draft = _draft.copyWith(
                    shiftFilter: value,
                    clearCustomShift: value != _ShiftFilter.custom,
                  );
                }),
              ),
              if (_draft.shiftFilter == _ShiftFilter.custom) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PickerField(
                        label: 'Start time',
                        value: _formatTime(_draft.customShiftStart) ?? 'Any',
                        onTap: () async {
                          final time = await _pickTime(_draft.customShiftStart);
                          if (time != null) {
                            setState(
                              () => _draft = _draft.copyWith(
                                customShiftStart: time,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerField(
                        label: 'End time',
                        value: _formatTime(_draft.customShiftEnd) ?? 'Any',
                        onTap: () async {
                          final time = await _pickTime(_draft.customShiftEnd);
                          if (time != null) {
                            setState(
                              () => _draft = _draft.copyWith(
                                customShiftEnd: time,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _draft = const _JobFilters()),
                      style: AppButtonStyles.secondaryOutline(
                        borderColor: AppColors.border,
                      ),
                      child: const Text('Clear all'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _draft),
                      style: AppButtonStyles.primary(
                        backgroundColor: const Color(0xFF8D73D9),
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Show jobs'),
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

  Future<DateTime?> _pickDate(DateTime? initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 180)),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initialTime) {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
  }
}

class _SavedJobsSheet extends StatefulWidget {
  const _SavedJobsSheet({
    required this.jobs,
    required this.savedJobIds,
    required this.onToggleSaved,
    required this.onViewJob,
  });

  final List<EmployeeJobDiscoveryItem> jobs;
  final Set<String> savedJobIds;
  final ValueChanged<EmployeeJobDiscoveryItem> onToggleSaved;
  final ValueChanged<EmployeeJobDiscoveryItem> onViewJob;

  @override
  State<_SavedJobsSheet> createState() => _SavedJobsSheetState();
}

class _SavedJobsSheetState extends State<_SavedJobsSheet> {
  late final List<EmployeeJobDiscoveryItem> _jobs = [...widget.jobs];
  late final Set<String> _savedJobIds = {...widget.savedJobIds};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF111B30),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Saved Jobs',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.lightText,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _jobs.isEmpty
                  ? const _NoSavedJobsView()
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final job = _jobs[index];
                        return EmployeeJobResultCard(
                          job: job,
                          isApplying: false,
                          isSaved: _savedJobIds.contains(job.id),
                          onTap: () => widget.onViewJob(job),
                          onApply: () => widget.onViewJob(job),
                          onToggleSaved: () {
                            setState(() {
                              if (_savedJobIds.contains(job.id)) {
                                _savedJobIds.remove(job.id);
                                _jobs.removeWhere((item) => item.id == job.id);
                              } else {
                                _savedJobIds.add(job.id);
                              }
                            });
                            widget.onToggleSaved(job);
                          },
                          actionLabel: 'View',
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipWrap<T> extends StatelessWidget {
  const _ChipWrap({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = item.$1 == selected;
        return ChoiceChip(
          selected: isSelected,
          showCheckmark: false,
          label: Text(item.$2),
          onSelected: (_) => onSelected(item.$1),
          selectedColor: const Color(0xFF8D73D9),
          backgroundColor: AppColors.surface.withValues(alpha: 0.48),
          side: BorderSide(
            color: isSelected ? const Color(0xFF8D73D9) : AppColors.border,
          ),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.white : AppColors.lightText,
            fontWeight: FontWeight.w800,
          ),
        );
      }).toList(),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SheetSectionTitle(title)),
        Text(value, style: AppTextStyles.label),
      ],
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.label.copyWith(fontSize: 12)),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.lightText,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: isActive ? AppColors.coralAccent : AppColors.lightText,
      style: IconButton.styleFrom(
        fixedSize: Size(size, size),
        side: BorderSide(
          color: isActive
              ? AppColors.coralAccent.withValues(alpha: 0.72)
              : AppColors.border,
        ),
        backgroundColor: isActive
            ? AppColors.coralAccent.withValues(alpha: 0.14)
            : AppColors.surface.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        shadowColor: isActive ? AppColors.coralAccent : null,
        elevation: isActive ? 6 : 0,
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.coralAccent),
          SizedBox(height: 16),
          Text('Finding jobs near you...', style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _NoJobsView extends StatelessWidget {
  const _NoJobsView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _StateCard(
        icon: Icons.work_off_outlined,
        title: 'No more jobs for now',
        message: 'Check back soon for new shifts.',
        action: OutlinedButton(
          onPressed: onRefresh,
          style: AppButtonStyles.secondaryOutline(),
          child: const Text('Refresh'),
        ),
      ),
    );
  }
}

class _NoSearchResultsView extends StatelessWidget {
  const _NoSearchResultsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: _StateCard(
          icon: Icons.search_off_rounded,
          title: 'No jobs found',
          message: 'Try a different title, business or location.',
        ),
      ),
    );
  }
}

class _NoFilterMatchesView extends StatelessWidget {
  const _NoFilterMatchesView({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _StateCard(
        icon: Icons.filter_alt_off_rounded,
        title: 'No jobs match your filters',
        message: 'Try clearing filters or adjusting your search.',
        action: OutlinedButton(
          onPressed: onClear,
          style: AppButtonStyles.secondaryOutline(),
          child: const Text('Clear filters'),
        ),
      ),
    );
  }
}

class _NoSavedJobsView extends StatelessWidget {
  const _NoSavedJobsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _StateCard(
        icon: Icons.bookmark_border_rounded,
        title: 'No saved jobs yet',
        message: 'Tap the bookmark icon on a job to save it for later.',
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _StateCard(
          icon: Icons.error_outline_rounded,
          title: 'Could not load jobs',
          message: error,
          action: OutlinedButton(
            onPressed: onRetry,
            style: AppButtonStyles.secondaryOutline(),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

class _AuthRequiredView extends StatelessWidget {
  const _AuthRequiredView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navyBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Please sign in to view and apply for jobs.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ),
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.coralAccent, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

String _money(double value) {
  return '₪${value.round()}';
}

String? _formatDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  return '${value.month}/${value.day}/${value.year}';
}

String? _formatTime(TimeOfDay? value) {
  if (value == null) {
    return null;
  }
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int? _minutesFromTime(TimeOfDay? value) {
  if (value == null) {
    return null;
  }
  return value.hour * 60 + value.minute;
}

import '../../../shared/utils/distance_utils.dart';
import '../../jobs/models/employee_job_discovery_item.dart';

class JobMatchResult {
  const JobMatchResult({
    required this.jobId,
    required this.totalScore,
    required this.categoryRoleScore,
    required this.availabilityScore,
    required this.locationScore,
    required this.skillsScore,
    required this.experienceScore,
    required this.distanceKm,
    required this.matchedCategories,
    required this.matchedRoles,
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchLevel,
    required this.reasonSummary,
  });

  final String jobId;
  final double totalScore;
  final double categoryRoleScore;
  final double availabilityScore;
  final double locationScore;
  final double skillsScore;
  final double experienceScore;
  final double? distanceKm;
  final List<String> matchedCategories;
  final List<String> matchedRoles;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final String matchLevel;
  final String reasonSummary;

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'totalScore': totalScore,
      'categoryRoleScore': categoryRoleScore,
      'availabilityScore': availabilityScore,
      'locationScore': locationScore,
      'skillsScore': skillsScore,
      'experienceScore': experienceScore,
      'distanceKm': distanceKm,
      'matchedCategories': matchedCategories,
      'matchedRoles': matchedRoles,
      'matchedSkills': matchedSkills,
      'missingSkills': missingSkills,
      'matchLevel': matchLevel,
      'reasonSummary': reasonSummary,
    };
  }
}

class JobMatchingService {
  const JobMatchingService();

  JobMatchResult calculateMatchForJob({
    required Map<String, dynamic> employeeProfile,
    required EmployeeJobDiscoveryItem job,
  }) {
    final categoryRole = _calculateCategoryRoleScore(employeeProfile, job);
    final availability = _calculateAvailabilityScore(employeeProfile, job);
    final location = _calculateLocationScore(employeeProfile, job);
    final skills = _calculateSkillsScore(employeeProfile, job);
    final experience = _calculateExperienceScore(employeeProfile, job);

    final totalScore = _roundScore(
      categoryRole.score +
          availability.score +
          location.score +
          skills.score +
          experience.score,
    );
    final matchLevel = _matchLevel(totalScore);

    return JobMatchResult(
      jobId: job.id,
      totalScore: totalScore,
      categoryRoleScore: _roundScore(categoryRole.score),
      availabilityScore: _roundScore(availability.score),
      locationScore: _roundScore(location.score),
      skillsScore: _roundScore(skills.score),
      experienceScore: _roundScore(experience.score),
      distanceKm: location.distanceKm == null
          ? null
          : _roundScore(location.distanceKm!),
      matchedCategories: categoryRole.matchedCategories,
      matchedRoles: categoryRole.matchedRoles,
      matchedSkills: skills.matchedSkills,
      missingSkills: skills.missingSkills,
      matchLevel: matchLevel,
      reasonSummary: _buildReasonSummary(
        matchLevel: matchLevel,
        categoryRole: categoryRole,
        availability: availability,
        location: location,
        skills: skills,
      ),
    );
  }

  List<JobMatchResult> rankJobsForEmployee({
    required Map<String, dynamic> employeeProfile,
    required Iterable<EmployeeJobDiscoveryItem> jobs,
  }) {
    final results = jobs
        .where(_isRankableJob)
        .map(
          (job) =>
              calculateMatchForJob(employeeProfile: employeeProfile, job: job),
        )
        .toList();

    results.sort((a, b) {
      final scoreComparison = b.totalScore.compareTo(a.totalScore);
      if (scoreComparison != 0) return scoreComparison;
      final aDistance = a.distanceKm ?? double.infinity;
      final bDistance = b.distanceKm ?? double.infinity;
      return aDistance.compareTo(bDistance);
    });
    return results;
  }

  _CategoryRoleScore _calculateCategoryRoleScore(
    Map<String, dynamic> employeeProfile,
    EmployeeJobDiscoveryItem job,
  ) {
    final employeeCategories = _readStringList(
      employeeProfile['jobCategories'],
    );
    final preferredRoles = _readStringList(employeeProfile['preferredRoles']);
    final preferredJobTypes = _readStringList(
      employeeProfile['preferredJobTypes'],
    );

    final jobCategories = [
      job.jobCategory,
      job.employer.businessType,
    ].whereType<String>().toList();
    final jobTitleText = [
      job.title,
      job.description,
    ].whereType<String>().join(' ');
    final jobTypeText = [
      ...job.shifts,
      job.dateText,
    ].where((value) => value.trim().isNotEmpty).join(' ');

    final matchedCategories = _overlaps(employeeCategories, jobCategories);
    final matchedRoles = preferredRoles
        .where((role) => _textContainsTerm(jobTitleText, role))
        .toList();
    final matchedJobTypes = preferredJobTypes
        .where((type) => _textContainsTerm(jobTypeText, type))
        .toList();

    final categoryScore = employeeCategories.isEmpty || jobCategories.isEmpty
        ? 8.0
        : matchedCategories.isNotEmpty
        ? 15.0
        : 0.0;
    final roleScore = preferredRoles.isEmpty
        ? 5.0
        : _proportionalScore(
            matchedRoles.length,
            preferredRoles.length,
            maxScore: 10,
          );
    final jobTypeScore = preferredJobTypes.isEmpty || jobTypeText.isEmpty
        ? 3.0
        : matchedJobTypes.isNotEmpty
        ? 5.0
        : 0.0;

    return _CategoryRoleScore(
      score: (categoryScore + roleScore + jobTypeScore).clamp(0, 30),
      matchedCategories: matchedCategories,
      matchedRoles: matchedRoles,
    );
  }

  _AvailabilityScore _calculateAvailabilityScore(
    Map<String, dynamic> employeeProfile,
    EmployeeJobDiscoveryItem job,
  ) {
    final availableDays = _readStringList(employeeProfile['availableDays']);
    final preferredShiftTypes = _readStringList(
      employeeProfile['preferredShiftTypes'],
    );
    final canWorkShortNotice =
        _readBool(employeeProfile['canWorkShortNotice']) ||
        _readBool(employeeProfile['canWorkOnShortNotice']);
    final canWorkToday = _readBool(employeeProfile['canWorkToday']);
    final availableNow =
        _readBool(employeeProfile['availableNow']) ||
        _readBool(employeeProfile['isAvailableNow']);

    final jobShiftTypes = _extractShiftTypes(job.shifts);
    final shiftOverlap = _overlaps(preferredShiftTypes, jobShiftTypes);
    final shiftScore = preferredShiftTypes.isEmpty || jobShiftTypes.isEmpty
        ? 5.0
        : shiftOverlap.isNotEmpty
        ? 10.0
        : 0.0;

    final jobDays = _jobAvailableDays(job);
    final dayOverlap = _overlaps(availableDays, jobDays);
    final dayScore = availableDays.isEmpty || jobDays.isEmpty
        ? 4.0
        : dayOverlap.isNotEmpty
        ? 8.0
        : 0.0;

    final urgentScore = job.urgent
        ? canWorkShortNotice
              ? 4.0
              : 0.0
        : 2.0;
    final asapScore = job.startAsSoonAsPossible || job.isToday
        ? canWorkToday || availableNow
              ? 3.0
              : 0.0
        : 2.0;

    return _AvailabilityScore(
      score: (shiftScore + dayScore + urgentScore + asapScore).clamp(0, 25),
      hasShiftOverlap: shiftOverlap.isNotEmpty,
      hasDayOverlap: dayOverlap.isNotEmpty,
      supportsUrgency: job.urgent && canWorkShortNotice,
      supportsToday:
          (job.startAsSoonAsPossible || job.isToday) &&
          (canWorkToday || availableNow),
    );
  }

  _LocationScore _calculateLocationScore(
    Map<String, dynamic> employeeProfile,
    EmployeeJobDiscoveryItem job,
  ) {
    final employeeLocation = _readMap(employeeProfile['location']);
    final employeeLat = _readDouble(employeeLocation['lat']);
    final employeeLng = _readDouble(employeeLocation['lng']);
    final jobLat = job.latitude;
    final jobLng = job.longitude;

    if (employeeLat == null ||
        employeeLng == null ||
        jobLat == null ||
        jobLng == null) {
      return const _LocationScore(score: 10);
    }

    final distanceKm = calculateDistanceKm(
      lat1: employeeLat,
      lng1: employeeLng,
      lat2: jobLat,
      lng2: jobLng,
    );
    final radiusKm =
        _readDouble(employeeProfile['preferredWorkRadiusKm']) ?? 20;

    final score = distanceKm <= radiusKm
        ? 20.0
        : distanceKm <= radiusKm * 1.5
        ? 14.0
        : distanceKm <= radiusKm * 2
        ? 8.0
        : 4.0;

    return _LocationScore(score: score, distanceKm: distanceKm);
  }

  _SkillsScore _calculateSkillsScore(
    Map<String, dynamic> employeeProfile,
    EmployeeJobDiscoveryItem job,
  ) {
    final employeeSkills = _readStringList(employeeProfile['skills']);
    final requiredSkills = job.requiredSkills;

    if (employeeSkills.isEmpty || requiredSkills.isEmpty) {
      return const _SkillsScore(score: 7);
    }

    final matchedSkills = _overlaps(employeeSkills, requiredSkills);
    final missingSkills = requiredSkills
        .where((skill) => !_containsNormalized(matchedSkills, skill))
        .toList();

    final coverage = matchedSkills.length / requiredSkills.length;
    final score = (6 + coverage * 9).clamp(0, 15).toDouble();

    return _SkillsScore(
      score: score,
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
    );
  }

  _ExperienceScore _calculateExperienceScore(
    Map<String, dynamic> employeeProfile,
    EmployeeJobDiscoveryItem job,
  ) {
    final employeeLevel = _normalize(
      _readString(employeeProfile['experienceLevel']),
    );
    final experiences =
        _readList(employeeProfile['pastWorkExperience']).isNotEmpty
        ? _readList(employeeProfile['pastWorkExperience'])
        : _readList(employeeProfile['pastExperiences']);
    final jobText = _normalize(
      [job.title, job.description].whereType<String>().join(' '),
    );

    if (_containsAny(jobText, const [
      'no experience',
      'entry level',
      'training provided',
      'no prior experience',
    ])) {
      return const _ExperienceScore(score: 10);
    }

    if (employeeLevel.isEmpty && experiences.isEmpty) {
      return const _ExperienceScore(score: 5);
    }

    final hasExperience =
        employeeLevel.contains('experienced') ||
        employeeLevel.contains('senior') ||
        employeeLevel.contains('expert') ||
        experiences.isNotEmpty;

    if (hasExperience) {
      return const _ExperienceScore(score: 9);
    }

    if (employeeLevel.contains('beginner') || employeeLevel.contains('entry')) {
      return const _ExperienceScore(score: 6);
    }

    return const _ExperienceScore(score: 7);
  }

  bool _isRankableJob(EmployeeJobDiscoveryItem job) {
    final status = _normalize(job.status);
    final visibility = _normalize(job.visibility);
    return status == 'open' &&
        visibility != 'draft' &&
        visibility != 'hidden' &&
        visibility != 'deleted';
  }

  String _buildReasonSummary({
    required String matchLevel,
    required _CategoryRoleScore categoryRole,
    required _AvailabilityScore availability,
    required _LocationScore location,
    required _SkillsScore skills,
  }) {
    final reasons = <String>[];

    if (categoryRole.score >= 22) {
      reasons.add('preferred job category or role');
    } else if (categoryRole.score < 12) {
      reasons.add('weaker category alignment');
    }

    if (availability.score >= 18) {
      reasons.add('matching availability');
    } else if (availability.score < 10) {
      reasons.add('limited availability overlap');
    }

    if (location.score >= 18) {
      reasons.add('nearby location');
    } else if (location.score <= 8) {
      reasons.add('longer travel distance');
    }

    if (skills.matchedSkills.isNotEmpty && skills.missingSkills.isEmpty) {
      reasons.add('covered required skills');
    } else if (skills.missingSkills.isNotEmpty) {
      reasons.add('some missing skills');
    }

    final summaryParts = reasons.take(3).toList();
    if (summaryParts.isEmpty) {
      return '$matchLevel based on the available profile and job details.';
    }

    if (summaryParts.length == 1) {
      return '$matchLevel based on ${summaryParts.first}.';
    }

    final last = summaryParts.removeLast();
    return '$matchLevel based on ${summaryParts.join(', ')} and $last.';
  }

  static String _matchLevel(double totalScore) {
    if (totalScore >= 85) return 'Excellent Match';
    if (totalScore >= 70) return 'Strong Match';
    if (totalScore >= 55) return 'Good Match';
    if (totalScore >= 40) return 'Partial Match';
    return 'Low Match';
  }
}

class _CategoryRoleScore {
  const _CategoryRoleScore({
    required this.score,
    required this.matchedCategories,
    required this.matchedRoles,
  });

  final double score;
  final List<String> matchedCategories;
  final List<String> matchedRoles;
}

class _AvailabilityScore {
  const _AvailabilityScore({
    required this.score,
    this.hasShiftOverlap = false,
    this.hasDayOverlap = false,
    this.supportsUrgency = false,
    this.supportsToday = false,
  });

  final double score;
  final bool hasShiftOverlap;
  final bool hasDayOverlap;
  final bool supportsUrgency;
  final bool supportsToday;
}

class _LocationScore {
  const _LocationScore({required this.score, this.distanceKm});

  final double score;
  final double? distanceKm;
}

class _SkillsScore {
  const _SkillsScore({
    required this.score,
    this.matchedSkills = const [],
    this.missingSkills = const [],
  });

  final double score;
  final List<String> matchedSkills;
  final List<String> missingSkills;
}

class _ExperienceScore {
  const _ExperienceScore({required this.score});

  final double score;
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _readBool(Object? value) {
  return value == true;
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }
  return null;
}

Map _readMap(Object? value) {
  return value is Map ? value : const {};
}

List _readList(Object? value) {
  return value is List ? value : const [];
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _normalize(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool _textContainsTerm(String text, String term) {
  final normalizedText = _normalize(text);
  final normalizedTerm = _normalize(term);
  if (normalizedText.isEmpty || normalizedTerm.isEmpty) return false;
  if (normalizedText == normalizedTerm) return true;
  if (normalizedTerm.length < 3) return false;
  return normalizedText.contains(normalizedTerm);
}

bool _containsNormalized(Iterable<String> values, String candidate) {
  final normalized = _normalize(candidate);
  return values.any((value) => _normalize(value) == normalized);
}

List<String> _overlaps(List<String> left, List<String> right) {
  if (left.isEmpty || right.isEmpty) return const [];

  final matches = <String>[];
  for (final leftItem in left) {
    for (final rightItem in right) {
      final normalizedLeft = _normalize(leftItem);
      final normalizedRight = _normalize(rightItem);
      if (normalizedLeft.isEmpty || normalizedRight.isEmpty) continue;
      if (normalizedLeft == normalizedRight ||
          normalizedLeft.contains(normalizedRight) ||
          normalizedRight.contains(normalizedLeft)) {
        if (!_containsNormalized(matches, rightItem)) {
          matches.add(rightItem);
        }
      }
    }
  }
  return matches;
}

double _proportionalScore(int matched, int total, {required double maxScore}) {
  if (total <= 0) return maxScore / 2;
  return (matched / total * maxScore).clamp(0, maxScore).toDouble();
}

List<String> _extractShiftTypes(List<String> shifts) {
  final types = <String>[];
  for (final shift in shifts) {
    final normalized = _normalize(shift);
    if (normalized.contains('morning')) types.add('morning');
    if (normalized.contains('afternoon')) types.add('afternoon');
    if (normalized.contains('evening')) types.add('evening');
    if (normalized.contains('night')) types.add('night');

    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(normalized);
    final hour = match == null ? null : int.tryParse(match.group(1)!);
    if (hour != null) {
      if (hour < 12) {
        types.add('morning');
      } else if (hour < 16) {
        types.add('afternoon');
      } else if (hour < 22) {
        types.add('evening');
      } else {
        types.add('night');
      }
    }
  }
  return types.toSet().toList();
}

List<String> _jobAvailableDays(EmployeeJobDiscoveryItem job) {
  final start = job.startDate;
  final end = job.endDate;
  if (start == null) return const [];
  if (end == null || _isSameDay(start, end)) {
    return [_weekdayName(start)];
  }

  final days = <String>{};
  var cursor = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!cursor.isAfter(last) && days.length < 7) {
    days.add(_weekdayName(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return days.toList();
}

String _weekdayName(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => 'monday',
    DateTime.tuesday => 'tuesday',
    DateTime.wednesday => 'wednesday',
    DateTime.thursday => 'thursday',
    DateTime.friday => 'friday',
    DateTime.saturday => 'saturday',
    DateTime.sunday => 'sunday',
    _ => '',
  };
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _containsAny(String text, List<String> terms) {
  return terms.any((term) => text.contains(term));
}

double _roundScore(double value) {
  return double.parse(value.toStringAsFixed(1));
}

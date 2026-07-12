import '../../jobs/models/employee_job_discovery_item.dart';
import 'job_matching_service.dart';

class AiMatchingPayloadBuilder {
  const AiMatchingPayloadBuilder();

  Map<String, dynamic> buildEmployeeJobsPayload({
    required Map<String, dynamic> employeeProfile,
    required List<EmployeeJobDiscoveryItem> jobs,
    Map<String, JobMatchResult>? matchResultsByJobId,
  }) {
    final preferredWorkRadiusKm = _readDouble(
      employeeProfile['preferredWorkRadiusKm'],
    );

    return {
      'task': 'rank_jobs_for_employee',
      'instructions': {
        'rankingGoal':
            'Rank the jobs from best to worst fit for this employee.',
        'important': [
          'Base the ranking only on the provided data.',
          'Do not invent missing information.',
          "Consider the employee's preferred categories, roles, availability, "
              'skills, experience, distance, preferred work radius, salary '
              'expectation, and the job/employer descriptions.',
          'Distance should influence the score reasonably, especially when the '
              "distance is above the employee's preferredWorkRadiusKm.",
          'Return valid JSON only when used by the AI model.',
        ],
      },
      'employee': _safeEmployeePayload(employeeProfile),
      'jobs': jobs
          .map(
            (job) => _safeJobPayload(
              job: job,
              distanceKm: matchResultsByJobId?[job.id]?.distanceKm,
              preferredWorkRadiusKm: preferredWorkRadiusKm,
            ),
          )
          .toList(),
      'expectedOutputFormat': {
        'rankedJobs': [
          {
            'jobId': 'string',
            'aiScore': 'number from 0 to 100',
            'rank': 'number',
            'reason': 'short explanation',
            'strengths': ['string'],
            'weaknesses': ['string'],
          },
        ],
      },
    };
  }

  String _readString(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return '';
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .where((item) => item is String || item is num)
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<String> _readFirstStringList(List<Object?> values) {
    for (final value in values) {
      final parsed = _readStringList(value);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return const [];
  }

  double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    return null;
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }
    return false;
  }

  Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  String _truncate(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }

    final shortened = trimmed.substring(0, maxLength).trimRight();
    return '$shortened...';
  }

  String _safeText(Object? value, int maxLength) {
    return _truncate(_stripContactInfo(_readString(value)), maxLength);
  }

  String _stripContactInfo(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'https?:\/\/\S*(?:firebasestorage|storage\.googleapis)\S*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\b(?:\+?\d[\d\s().-]{6,}\d)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _buildPastExperienceSummary(Map<String, dynamic> employeeProfile) {
    final experience = employeeProfile['pastWorkExperience'] is List
        ? employeeProfile['pastWorkExperience']
        : employeeProfile['pastExperiences'];
    if (experience is! List) {
      return _safeText(employeeProfile['pastExperienceSummary'], 500);
    }

    final summaries = <String>[];
    for (final item in experience.take(4)) {
      if (item is String) {
        final text = _safeText(item, 180);
        if (text.isNotEmpty) {
          summaries.add(text);
        }
        continue;
      }

      final map = _readMap(item);
      if (map.isEmpty) {
        continue;
      }

      final role = _readString(
        map['role'] ?? map['title'] ?? map['jobTitle'] ?? map['position'],
      );
      final workplace = _readString(
        map['workplace'] ?? map['company'] ?? map['businessName'],
      );
      final duration = _readString(map['duration']);
      final description = _safeText(
        map['description'] ?? map['notes'] ?? map['summary'],
        180,
      );

      final headline = [
        role,
        workplace,
        duration,
      ].where((part) => part.isNotEmpty).join(' | ');
      final summary = [
        headline,
        description,
      ].where((part) => part.isNotEmpty).join(': ');

      if (summary.isNotEmpty) {
        summaries.add(summary);
      }
    }

    return _truncate(summaries.join(' | '), 500);
  }

  String _buildLocationSummary(Map<String, dynamic> employeeProfile) {
    for (final key in const [
      'locationName',
      'city',
      'locality',
      'town',
      'village',
      'municipality',
      'preferredLocation',
    ]) {
      final value = _readString(employeeProfile[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }

    final location = _readMap(employeeProfile['location']);
    for (final key in const [
      'city',
      'locality',
      'town',
      'village',
      'name',
      'address',
      'formattedAddress',
    ]) {
      final value = _readString(location[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }

    return _readBool(employeeProfile['locationPermissionGranted']) ||
            location.isNotEmpty
        ? 'Location set'
        : '';
  }

  Map<String, dynamic> _safeEmployeePayload(
    Map<String, dynamic> employeeProfile,
  ) {
    return {
      'employeeId': _readString(
        employeeProfile['employeeId'] ??
            employeeProfile['id'] ??
            employeeProfile['uid'],
      ),
      'ageRange': _readString(employeeProfile['ageRange']),
      'preferredCategories': _readFirstStringList([
        employeeProfile['preferredCategories'],
        employeeProfile['jobCategories'],
      ]),
      'preferredRoles': _readStringList(employeeProfile['preferredRoles']),
      'preferredJobTypes': _readStringList(
        employeeProfile['preferredJobTypes'],
      ),
      'skills': _readStringList(employeeProfile['skills']),
      'availableDays': _readFirstStringList([
        employeeProfile['availableDays'],
        employeeProfile['availabilityDays'],
      ]),
      'preferredShiftTypes': _readFirstStringList([
        employeeProfile['preferredShiftTypes'],
        employeeProfile['availabilityShifts'],
        employeeProfile['shiftTypes'],
      ]),
      'experienceLevel': _readString(employeeProfile['experienceLevel']),
      'pastExperienceSummary': _buildPastExperienceSummary(employeeProfile),
      'shortBio': _safeText(employeeProfile['shortBio'], 300),
      'salaryExpectation': _readDouble(employeeProfile['salaryExpectation']),
      'preferredWorkRadiusKm': _readDouble(
        employeeProfile['preferredWorkRadiusKm'],
      ),
      'locationSummary': _buildLocationSummary(employeeProfile),
      'availabilityFlags': {
        'availableNow':
            _readBool(employeeProfile['availableNow']) ||
            _readBool(employeeProfile['isAvailableNow']),
        'canWorkToday': _readBool(employeeProfile['canWorkToday']),
        'canWorkOnShortNotice':
            _readBool(employeeProfile['canWorkOnShortNotice']) ||
            _readBool(employeeProfile['canWorkShortNotice']),
      },
    };
  }

  String _safeBusinessAddress(String? value) {
    final address = _readString(value);
    if (address.isEmpty) {
      return '';
    }

    if (RegExp(
      r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
      caseSensitive: false,
    ).hasMatch(address)) {
      return '';
    }

    if (RegExp(r'https?:\/\/', caseSensitive: false).hasMatch(address)) {
      return '';
    }

    return address;
  }

  Map<String, dynamic> _safeEmployerPayload(
    EmployeeDiscoveryEmployer employer,
  ) {
    return {
      'businessName': _readString(employer.businessName),
      'businessType': _readString(employer.businessType),
      'businessDescription': '',
      'businessAddress': _safeBusinessAddress(employer.businessAddress),
      'hiringCategories': const <String>[],
    };
  }

  List<String> _safeStringList(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  double? _distanceFromJob(EmployeeJobDiscoveryItem job) {
    try {
      final dynamic dynamicJob = job;
      final Object? value = dynamicJob.distanceKm ?? dynamicJob.distance;
      return _readDouble(value);
    } catch (_) {
      return null;
    }
  }

  double? _normalizeDistance(double? value) {
    return value == null ? null : double.parse(value.toStringAsFixed(1));
  }

  Map<String, dynamic> _safeJobPayload({
    required EmployeeJobDiscoveryItem job,
    required double? distanceKm,
    required double? preferredWorkRadiusKm,
  }) {
    final normalizedDistanceKm = _normalizeDistance(
      distanceKm ?? _distanceFromJob(job),
    );
    final isWithinPreferredRadius =
        normalizedDistanceKm == null || preferredWorkRadiusKm == null
        ? null
        : normalizedDistanceKm <= preferredWorkRadiusKm;

    return {
      'jobId': job.id,
      'title': _readString(job.title),
      'description': _safeText(job.description, 600),
      'jobCategory': _readString(job.jobCategory),
      'requiredSkills': _safeStringList(job.requiredSkills),
      'shifts': _safeStringList(job.shifts),
      'dateText': job.dateText,
      'salaryAmount': job.salaryAmount,
      'salaryType': _readString(job.salaryType),
      'urgent': job.urgent,
      'startAsSoonAsPossible': job.startAsSoonAsPossible,
      'distanceKm': normalizedDistanceKm,
      'isWithinPreferredRadius': isWithinPreferredRadius,
      'employer': _safeEmployerPayload(job.employer),
    };
  }
}

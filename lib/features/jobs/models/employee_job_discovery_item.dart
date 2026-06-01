import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeJobDiscoveryItem {
  const EmployeeJobDiscoveryItem({
    required this.id,
    required this.employerId,
    required this.title,
    required this.description,
    required this.jobCategory,
    required this.requiredSkills,
    required this.salaryAmount,
    required this.salaryType,
    required this.startAsSoonAsPossible,
    required this.startDate,
    required this.endDate,
    required this.urgent,
    required this.shifts,
    required this.location,
    required this.imageUrl,
    required this.visibility,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.employer,
  });

  final String id;
  final String employerId;
  final String title;
  final String? description;
  final String? jobCategory;
  final List<String> requiredSkills;
  final double? salaryAmount;
  final String? salaryType;
  final bool startAsSoonAsPossible;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool urgent;
  final List<String> shifts;
  final String? location;
  final String? imageUrl;
  final String? visibility;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final EmployeeDiscoveryEmployer employer;

  String? get displayImageUrl => imageUrl ?? employer.businessLogoUrl;

  String get businessName => employer.businessName ?? 'WURKIT employer';

  String? get businessSubtitle {
    final parts = [
      employer.businessType,
      employer.city,
    ].whereType<String>().where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  String get salaryText {
    final amount = salaryAmount;
    if (amount == null) {
      return 'Pay not listed';
    }
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final suffix = switch (salaryType?.toLowerCase()) {
      'hourly' => ' / hour',
      'daily' => ' / day',
      'fixed' => ' fixed',
      String value when value.isNotEmpty => ' $value',
      _ => '',
    };
    return '\u20AA$formatted$suffix';
  }

  String get dateText {
    if (startAsSoonAsPossible) {
      return 'Today, ASAP';
    }
    final start = startDate;
    final end = endDate;
    if (start == null) {
      return 'Flexible';
    }
    final startText = _formatShortDate(start);
    if (end == null || _isSameDay(start, end)) {
      return startText;
    }
    return '$startText - ${_formatShortDate(end)}';
  }

  String get shiftText {
    if (shifts.isNotEmpty) {
      return shifts.join(', ');
    }
    return 'Time TBD';
  }

  String get locationText {
    return location ??
        employer.city ??
        employer.businessAddress ??
        'Location TBD';
  }

  String get searchText {
    return [
      title,
      description,
      jobCategory,
      requiredSkills.join(' '),
      businessName,
      employer.city,
      employer.businessAddress,
      location,
    ].whereType<String>().join(' ').toLowerCase();
  }

  bool get isToday {
    if (startAsSoonAsPossible) {
      return true;
    }
    final start = startDate;
    return start != null && _isSameDay(start, DateTime.now());
  }

  bool get isAsap => startAsSoonAsPossible;

  bool get isEvening {
    final text = shifts.join(' ').toLowerCase();
    if (text.contains('evening') || text.contains('night')) {
      return true;
    }
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    final hour = match == null ? null : int.tryParse(match.group(1)!);
    return hour != null && hour >= 16;
  }

  factory EmployeeJobDiscoveryItem.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
    required EmployeeDiscoveryEmployer employer,
  }) {
    final salaryAmount =
        _readDouble(data['salaryAmount']) ?? _readSalaryText(data['salary']);
    final skills = _readStringList(data['requiredSkills']);
    final legacySkill = _readString(data['requiredSkill']);
    final allSkills = [
      ...skills,
      if (legacySkill != null && !skills.contains(legacySkill)) legacySkill,
    ];

    return EmployeeJobDiscoveryItem(
      id: id,
      employerId: _readString(data['employerId']) ?? '',
      title: _readString(data['title']) ?? 'Open shift',
      description: _readString(data['description']),
      jobCategory: _readString(data['jobCategory']),
      requiredSkills: allSkills,
      salaryAmount: salaryAmount,
      salaryType: _readString(data['salaryType']),
      startAsSoonAsPossible: _readBool(data['startAsSoonAsPossible']) ?? false,
      startDate:
          _readDateTime(data['startDate']) ?? _readDateTime(data['date']),
      endDate: _readDateTime(data['endDate']),
      urgent: _readBool(data['urgent']) ?? false,
      shifts: _readShifts(data),
      location: _readLocation(data['location']),
      imageUrl: _readFirstString(data['imageUrls']),
      visibility: _readString(data['visibility']),
      status: _readString(data['status']) ?? 'open',
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      publishedAt: _readDateTime(data['publishedAt']),
      employer: employer,
    );
  }

  static String _formatShortDate(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (_isSameDay(date, now)) {
      return 'Today';
    }
    if (_isSameDay(date, tomorrow)) {
      return 'Tomorrow';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class EmployeeDiscoveryEmployer {
  const EmployeeDiscoveryEmployer({
    this.businessName,
    this.businessLogoUrl,
    this.city,
    this.businessType,
    this.businessAddress,
  });

  final String? businessName;
  final String? businessLogoUrl;
  final String? city;
  final String? businessType;
  final String? businessAddress;

  factory EmployeeDiscoveryEmployer.fromMap(Map<String, dynamic>? data) {
    return EmployeeDiscoveryEmployer(
      businessName: _readString(data?['businessName']),
      businessLogoUrl: _readString(data?['businessLogoUrl']),
      city: _readString(data?['city']),
      businessType: _readString(data?['businessType']),
      businessAddress: _readString(data?['businessAddress']),
    );
  }
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _readBool(Object? value) {
  return value is bool ? value : null;
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

double? _readSalaryText(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
  }
  return null;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _readFirstString(Object? value) {
  if (value is List) {
    for (final item in value) {
      final text = _readString(item);
      if (text != null) {
        return text;
      }
    }
  }
  return null;
}

String? _readLocation(Object? value) {
  if (value is String) {
    return _readString(value);
  }
  if (value is Map) {
    if (_readString(value['type']) == 'remote') {
      return 'Remote';
    }
    final parts = [
      _readString(value['address']),
      _readString(value['city']),
    ].whereType<String>().toList();
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }
  }
  return null;
}

List<String> _readShifts(Map<String, dynamic> data) {
  final shifts = data['shifts'];
  if (shifts is List) {
    final parsed = shifts
        .whereType<Map>()
        .map((shift) {
          final label = _readString(shift['label']);
          if (label != null) {
            return label;
          }
          final start = _readString(shift['startTime']);
          final end = _readString(shift['endTime']);
          if (start == null && end == null) {
            return null;
          }
          if (start == null) {
            return end;
          }
          if (end == null) {
            return start;
          }
          return '$start - $end';
        })
        .whereType<String>()
        .toList();
    if (parsed.isNotEmpty) {
      return parsed;
    }
  }

  final start = _readString(data['shiftStart']);
  final end = _readString(data['shiftEnd']);
  if (start == null && end == null) {
    return const [];
  }
  if (start == null) {
    return [end!];
  }
  if (end == null) {
    return [start];
  }
  return ['$start - $end'];
}

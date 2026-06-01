import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeApplicationItem {
  const EmployeeApplicationItem({
    required this.applicationId,
    required this.jobId,
    required this.employerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.cancelledAt,
    required this.cancelledBy,
    required this.jobExists,
    required this.jobTitle,
    required this.jobCategory,
    required this.jobImageUrl,
    required this.businessName,
    required this.businessLogoUrl,
    required this.businessType,
    required this.salaryText,
    required this.dateText,
    required this.shiftText,
    required this.locationText,
    required this.description,
    required this.urgent,
  });

  final String applicationId;
  final String jobId;
  final String employerId;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final bool jobExists;
  final String jobTitle;
  final String? jobCategory;
  final String? jobImageUrl;
  final String businessName;
  final String? businessLogoUrl;
  final String? businessType;
  final String salaryText;
  final String dateText;
  final String shiftText;
  final String locationText;
  final String description;
  final bool urgent;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isMatch => isApproved;
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';

  String get statusLabel {
    return switch (status) {
      'approved' => 'Match',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => 'Pending',
    };
  }

  String get searchText {
    return [
      jobTitle,
      jobCategory,
      businessName,
      businessType,
      locationText,
      status,
      statusLabel,
    ].whereType<String>().join(' ').toLowerCase();
  }

  static int compareDefault(
    EmployeeApplicationItem left,
    EmployeeApplicationItem right,
  ) {
    final statusCompare = _statusRank(
      left.status,
    ).compareTo(_statusRank(right.status));
    if (statusCompare != 0) {
      return statusCompare;
    }
    return (right.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
      left.createdAt?.millisecondsSinceEpoch ?? 0,
    );
  }

  static int _statusRank(String status) {
    return switch (status) {
      'approved' => 0,
      'pending' => 1,
      'rejected' => 2,
      'cancelled' => 3,
      _ => 1,
    };
  }

  factory EmployeeApplicationItem.fromData({
    required String applicationId,
    required Map<String, dynamic> applicationData,
    required Map<String, dynamic>? jobData,
    required Map<String, dynamic>? employerData,
  }) {
    final jobExists = jobData != null;
    final employerId =
        _readString(applicationData['employerId']) ??
        _readString(jobData?['employerId']) ??
        '';
    final jobTitle =
        _readString(jobData?['title']) ??
        _readString(applicationData['jobTitle']) ??
        (jobExists ? 'Open shift' : 'Job no longer available');
    final salaryAmount =
        _readDouble(jobData?['salaryAmount']) ??
        _readDouble(jobData?['salary']);
    final salaryType = _readString(jobData?['salaryType']);
    final businessCity = _readString(employerData?['city']);
    final jobLocation = _readLocation(jobData?['location']);

    return EmployeeApplicationItem(
      applicationId: applicationId,
      jobId: _readString(applicationData['jobId']) ?? '',
      employerId: employerId,
      status: _normalizeStatus(_readString(applicationData['status'])),
      createdAt: _readDateTime(applicationData['createdAt']),
      updatedAt: _readDateTime(applicationData['updatedAt']),
      cancelledAt: _readDateTime(applicationData['cancelledAt']),
      cancelledBy: _readString(applicationData['cancelledBy']),
      jobExists: jobExists,
      jobTitle: jobTitle,
      jobCategory: _readString(jobData?['jobCategory']),
      jobImageUrl: _readFirstString(jobData?['imageUrls']),
      businessName:
          _readString(employerData?['businessName']) ?? 'WURKIT employer',
      businessLogoUrl: _readString(employerData?['businessLogoUrl']),
      businessType: _readString(employerData?['businessType']),
      salaryText: _formatSalary(salaryAmount, salaryType),
      dateText: _formatJobDate(jobData),
      shiftText: _formatShift(jobData),
      locationText:
          jobLocation ??
          businessCity ??
          _readString(employerData?['businessAddress']) ??
          'Location TBD',
      description:
          _readString(jobData?['description']) ??
          (jobExists
              ? 'Job details will appear here when available.'
              : 'This job may have been removed by the employer.'),
      urgent: _readBool(jobData?['urgent']) ?? false,
    );
  }
}

String _normalizeStatus(String? status) {
  return switch (status) {
    'approved' => 'approved',
    'rejected' => 'rejected',
    'cancelled' => 'cancelled',
    _ => 'pending',
  };
}

String _formatSalary(double? amount, String? salaryType) {
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

String _formatJobDate(Map<String, dynamic>? data) {
  if (data == null) {
    return 'Date TBD';
  }
  if (data['startAsSoonAsPossible'] == true) {
    return 'Today, ASAP';
  }
  final start = _readDateTime(data['startDate']) ?? _readDateTime(data['date']);
  final end = _readDateTime(data['endDate']);
  if (start == null) {
    final legacy = _readString(data['date']);
    return legacy ?? 'Flexible';
  }
  final startText = _shortDate(start);
  if (end == null || _sameDay(start, end)) {
    return startText;
  }
  return '$startText - ${_shortDate(end)}';
}

String _formatShift(Map<String, dynamic>? data) {
  if (data == null) {
    return 'Shift TBD';
  }
  final shifts = data['shifts'];
  if (shifts is List) {
    final parsed = shifts
        .whereType<Map>()
        .map((shift) {
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
      return parsed.join(', ');
    }
  }
  final start = _readString(data['shiftStart']);
  final end = _readString(data['shiftEnd']);
  if (start == null && end == null) {
    return 'Shift TBD';
  }
  if (start == null) {
    return end!;
  }
  if (end == null) {
    return start;
  }
  return '$start - $end';
}

String _shortDate(DateTime date) {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (_sameDay(date, now)) {
    return 'Today';
  }
  if (_sameDay(date, tomorrow)) {
    return 'Tomorrow';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool? _readBool(Object? value) => value is bool ? value : null;

double? _readDouble(Object? value) {
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

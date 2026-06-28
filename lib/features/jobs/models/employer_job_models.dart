import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/utils/address_format_utils.dart';

class EmployerJob {
  const EmployerJob({
    required this.id,
    required this.employerId,
    required this.title,
    required this.status,
    required this.visibility,
    required this.urgent,
    required this.createdAtMillis,
    this.description,
    this.jobCategory,
    this.requiredSkills = const [],
    this.salaryAmount,
    this.salaryType,
    this.dateText,
    this.locationText,
    this.shiftText,
    this.imageUrl,
  });

  final String id;
  final String employerId;
  final String title;
  final String status;
  final String visibility;
  final bool urgent;
  final int createdAtMillis;
  final String? description;
  final String? jobCategory;
  final List<String> requiredSkills;
  final double? salaryAmount;
  final String? salaryType;
  final String? dateText;
  final String? locationText;
  final String? shiftText;
  final String? imageUrl;

  bool get isDraft => visibility == 'draft' || status == 'draft';
  bool get isOpen => !isDraft && status == 'open';
  bool get isFilled => status == 'filled';
  bool get isClosed => status == 'closed' || status == 'cancelled';

  String get statusLabel {
    if (isDraft) return 'Draft';
    switch (status) {
      case 'filled':
        return 'Filled';
      case 'closed':
        return 'Closed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Open';
    }
  }

  String get salaryText {
    final amount = salaryAmount;
    if (amount == null) return 'Pay not listed';
    final formatted = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(1);
    final suffix = salaryType == 'Hourly'
        ? ' / hour'
        : salaryType == 'Daily'
        ? ' / day'
        : salaryType == null
        ? ''
        : ' $salaryType';
    return '₪$formatted$suffix';
  }

  String get skillsText {
    if (requiredSkills.isEmpty) return jobCategory ?? 'General help';
    return requiredSkills.join(', ');
  }

  factory EmployerJob.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return EmployerJob.fromMap(id: snapshot.id, data: snapshot.data());
  }

  factory EmployerJob.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return EmployerJob.fromMap(id: snapshot.id, data: snapshot.data() ?? {});
  }

  factory EmployerJob.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final visibility = _readString(data['visibility']);
    final status = _readString(data['status']);
    final inferredDraft = visibility == 'draft' || status == 'draft';

    return EmployerJob(
      id: id,
      employerId: _readString(data['employerId']) ?? '',
      title: _readString(data['title']) ?? 'Open shift',
      status: inferredDraft ? 'draft' : (status ?? 'open'),
      visibility: inferredDraft ? 'draft' : (visibility ?? 'published'),
      urgent: data['urgent'] == true,
      createdAtMillis: _readTimestampMillis(data['createdAt']),
      description: _readString(data['description']),
      jobCategory: _readString(data['jobCategory']),
      requiredSkills: _readSkills(data),
      salaryAmount:
          _readDouble(data['salaryAmount']) ?? _readDouble(data['salary']),
      salaryType: _readString(data['salaryType']),
      dateText: _readJobDate(data),
      locationText:
          _formatNullableAddress(data['jobAddress']) ??
          _readLocation(data['location']),
      shiftText: _readShiftText(data),
      imageUrl: _readFirstString(data['imageUrls']),
    );
  }
}

List<String> _readSkills(Map<String, dynamic> data) {
  final skills = _readStringList(data['requiredSkills']);
  if (skills.isNotEmpty) return skills;

  final legacySkill = _readString(data['requiredSkill']);
  return legacySkill == null ? const [] : [legacySkill];
}

String? _readShiftText(Map<String, dynamic> data) {
  final shifts = data['shifts'];
  if (shifts is List && shifts.isNotEmpty) {
    final labels = shifts
        .whereType<Map>()
        .map((shift) {
          final start = _readString(shift['startTime']);
          final end = _readString(shift['endTime']);
          if (start == null && end == null) return null;
          if (start == null) return end;
          if (end == null) return start;
          return '$start - $end';
        })
        .whereType<String>()
        .toList();
    if (labels.isNotEmpty) return labels.join(', ');
  }

  final shiftStart = _readString(data['shiftStart']);
  final shiftEnd = _readString(data['shiftEnd']);
  if (shiftStart == null && shiftEnd == null) return null;
  if (shiftStart == null) return shiftEnd;
  if (shiftEnd == null) return shiftStart;
  return '$shiftStart - $shiftEnd';
}

String? _readJobDate(Map<String, dynamic> data) {
  if (data['startAsSoonAsPossible'] == true) return 'ASAP';

  final start = data['startDate'];
  final end = data['endDate'];
  if (start is Timestamp && end is Timestamp) {
    return '${_readDate(start)} - ${_readDate(end)}';
  }
  if (start is Timestamp) return _readDate(start);
  return _readDate(data['date']);
}

String? _readDate(Object? value) {
  if (value is Timestamp) {
    final date = value.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }
  return _readString(value);
}

String? _readLocation(Object? value) {
  if (value is String) return _readString(value);

  if (value is Map) {
    if (value['type'] == 'remote') return 'Remote';
    final address = _readString(value['address']);
    if (address != null) return formatAddressForDisplay(address);
  }

  return null;
}

String? _formatNullableAddress(Object? value) {
  final address = _readString(value);
  return address == null ? null : formatAddressForDisplay(address);
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
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
      if (text != null) return text;
    }
  }
  return null;
}

String? _readString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _readTimestampMillis(Object? value) {
  if (value is Timestamp) return value.millisecondsSinceEpoch;
  return 0;
}

import 'package:cloud_firestore/cloud_firestore.dart';

class ReportItem {
  const ReportItem({
    required this.reportId,
    required this.reportedByUserId,
    required this.reportedByName,
    required this.reportedByRole,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.reportedUserRole,
    required this.jobId,
    required this.jobTitle,
    required this.reportType,
    required this.reason,
    required this.description,
    required this.status,
    required this.adminNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reportId;
  final String reportedByUserId;
  final String reportedByName;
  final String reportedByRole;
  final String reportedUserId;
  final String reportedUserName;
  final String reportedUserRole;
  final String? jobId;
  final String? jobTitle;
  final String reportType;
  final String reason;
  final String description;
  final String status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ReportItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final reportId = _stringFrom(data['reportId'], fallback: doc.id);

    return ReportItem(
      reportId: reportId,
      reportedByUserId: _stringFrom(data['reportedByUserId']),
      reportedByName: _stringFrom(data['reportedByName'], fallback: 'Unknown'),
      reportedByRole: _normalizeRole(_stringFrom(data['reportedByRole'])),
      reportedUserId: _stringFrom(data['reportedUserId']),
      reportedUserName: _stringFrom(
        data['reportedUserName'],
        fallback: 'Unknown',
      ),
      reportedUserRole: _normalizeRole(_stringFrom(data['reportedUserRole'])),
      jobId: _optionalString(data['jobId']),
      jobTitle: _optionalString(data['jobTitle']),
      reportType: _normalizeType(
        _stringFrom(data['reportType'], fallback: 'other'),
      ),
      reason: _stringFrom(data['reason'], fallback: 'Other'),
      description: _stringFrom(data['description']),
      status: _normalizeStatus(
        _stringFrom(data['status'], fallback: 'pending'),
      ),
      adminNote: _optionalString(data['adminNote']),
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }

  static String _stringFrom(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    if (value is num || value is bool) return value.toString();
    if (value is Map) {
      final map = value.cast<dynamic, dynamic>();
      final nested =
          _optionalString(map['name']) ?? _optionalString(map['label']);
      if (nested != null) return nested;
    }
    return fallback;
  }

  static String? _optionalString(dynamic value) {
    if (value == null) return null;
    final text = _stringFrom(value, fallback: '');
    return text.isEmpty ? null : text;
  }

  static DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String _normalizeRole(String role) {
    final lower = role.trim().toLowerCase();
    if (lower == 'employee' || lower == 'employer') return lower;
    return 'employee';
  }

  static String _normalizeType(String type) {
    final lower = type.trim().toLowerCase();
    const allowed = {'user', 'job', 'review', 'chat', 'other'};
    return allowed.contains(lower) ? lower : 'other';
  }

  static String _normalizeStatus(String status) {
    final lower = status.trim().toLowerCase();
    const allowed = {'pending', 'reviewed', 'resolved', 'dismissed'};
    return allowed.contains(lower) ? lower : 'pending';
  }
}

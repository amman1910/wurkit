import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/report_item.dart';

class ReportService {
  ReportService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> submitReport({
    required String reportedUserId,
    required String reportedUserName,
    required String reportedUserRole,
    required String reportType,
    required String reason,
    required String description,
    String? jobId,
    String? jobTitle,
  }) async {
    final reporterId = _auth.currentUser?.uid;
    if (reporterId == null || reporterId.trim().isEmpty) {
      throw Exception('You must be logged in to submit a report.');
    }

    final targetUserId = reportedUserId.trim();
    if (targetUserId.isEmpty) {
      throw Exception('Reported user is required.');
    }
    if (targetUserId == reporterId) {
      throw Exception('You cannot report yourself.');
    }

    final cleanReason = reason.trim();
    final cleanDescription = description.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Reason is required.');
    }
    if (cleanDescription.length < 10) {
      throw Exception('Description must be at least 10 characters.');
    }

    final cleanType = _normalizeType(reportType);
    final cleanReportedRole = _normalizeRole(reportedUserRole);

    final reporterRole = await _resolveUserRole(reporterId);
    final reporterName = await _resolveUserName(
      userId: reporterId,
      role: reporterRole,
      fallback: _auth.currentUser?.displayName,
    );

    final targetName = _cleanText(reportedUserName, fallback: 'Unknown');
    final cleanJobId = _cleanOptional(jobId);
    final cleanJobTitle = _cleanOptional(jobTitle);
    final reportRef = _firestore
        .collection('reports')
        .doc(
          _dailyDedupId(
            reporterId: reporterId,
            reportedUserId: targetUserId,
            jobId: cleanJobId,
          ),
        );

    final existing = await reportRef.get();
    if (existing.exists) {
      throw Exception('You already submitted a report for this user today.');
    }

    await reportRef.set({
      'reportId': reportRef.id,
      'reportedByUserId': reporterId,
      'reportedByName': reporterName,
      'reportedByRole': reporterRole,
      'reportedUserId': targetUserId,
      'reportedUserName': targetName,
      'reportedUserRole': cleanReportedRole,
      'jobId': cleanJobId,
      'jobTitle': cleanJobTitle,
      'reportType': cleanType,
      'reason': cleanReason,
      'description': cleanDescription,
      'status': 'pending',
      'adminNote': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ReportItem>> watchReportsForAdmin() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ReportItem.fromDoc).toList());
  }

  Future<void> updateReportStatus(String reportId, String status) {
    final cleanId = reportId.trim();
    if (cleanId.isEmpty) {
      throw Exception('Invalid report id.');
    }

    final cleanStatus = _normalizeStatus(status);
    return _firestore.collection('reports').doc(cleanId).set({
      'status': cleanStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addAdminNote(String reportId, String note) {
    final cleanId = reportId.trim();
    if (cleanId.isEmpty) {
      throw Exception('Invalid report id.');
    }

    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      throw Exception('Note cannot be empty.');
    }

    return _firestore.collection('reports').doc(cleanId).set({
      'adminNote': cleanNote,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> _resolveUserRole(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final role = _cleanOptional(doc.data()?['role'])?.toLowerCase();
    if (role == 'employee' || role == 'employer') {
      return role!;
    }
    return 'employee';
  }

  Future<String> _resolveUserName({
    required String userId,
    required String role,
    String? fallback,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();
    final userName =
        _cleanOptional(userData?['name']) ??
        _cleanOptional(userData?['displayName']) ??
        _cleanOptional(fallback);
    if (userName != null) {
      return userName;
    }

    if (role == 'employer') {
      final profile = await _firestore
          .collection('employerProfiles')
          .doc(userId)
          .get();
      return _cleanOptional(profile.data()?['businessName']) ?? 'Employer';
    }

    final profile = await _firestore
        .collection('employeeProfiles')
        .doc(userId)
        .get();
    return _cleanOptional(profile.data()?['name']) ?? 'Employee';
  }

  String _dailyDedupId({
    required String reporterId,
    required String reportedUserId,
    required String? jobId,
  }) {
    final now = DateTime.now();
    final dayKey =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final cleanJob = jobId == null || jobId.trim().isEmpty
        ? 'none'
        : jobId.trim();
    final raw = '${reporterId}_${reportedUserId}_${cleanJob}_$dayKey';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  String _normalizeRole(String role) {
    final lower = role.trim().toLowerCase();
    return lower == 'employer' ? 'employer' : 'employee';
  }

  String _normalizeType(String type) {
    final lower = type.trim().toLowerCase();
    const allowed = {'user', 'job', 'review', 'chat', 'other'};
    return allowed.contains(lower) ? lower : 'other';
  }

  String _normalizeStatus(String status) {
    final lower = status.trim().toLowerCase();
    const allowed = {'pending', 'reviewed', 'resolved', 'dismissed'};
    if (!allowed.contains(lower)) {
      throw Exception('Invalid report status.');
    }
    return lower;
  }

  String _cleanText(Object? value, {required String fallback}) {
    final text = _cleanOptional(value);
    return text ?? fallback;
  }

  String? _cleanOptional(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }
}

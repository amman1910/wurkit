import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../notifications/services/notification_service.dart';
import '../models/employee_application_item.dart';

class EmployeeApplicationService {
  EmployeeApplicationService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  Stream<List<EmployeeApplicationItem>> watchEmployeeApplications() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap(_hydrateApplications);
  }

  Stream<int> watchApprovedApplicationsCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .where((doc) => doc.data()['seenByEmployee'] != true)
              .length;
        });
  }

  Future<void> markApprovedApplicationsSeen() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final snapshot = await _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'approved')
        .get();

    final unseenDocs = snapshot.docs
        .where((doc) => doc.data()['seenByEmployee'] != true)
        .toList();
    if (unseenDocs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    for (final doc in unseenDocs) {
      batch.update(doc.reference, {
        'seenByEmployee': true,
        'employeeSeenAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> cancelApplication(String applicationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to cancel this application.');
    }

    final ref = _firestore.collection('applications').doc(applicationId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw Exception('Application not found.');
    }
    if (data['employeeId'] != user.uid) {
      throw Exception('You can only cancel your own applications.');
    }
    if ((data['status'] as String? ?? 'pending') != 'pending') {
      throw Exception('Only pending applications can be cancelled.');
    }

    await ref.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': 'employee',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resendCancelledApplication(String applicationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to resend this application.');
    }

    final applicationRef = _firestore
        .collection('applications')
        .doc(applicationId);
    final applicationSnapshot = await applicationRef.get();
    final application = applicationSnapshot.data();
    if (!applicationSnapshot.exists || application == null) {
      throw Exception('Application not found.');
    }
    if (application['employeeId'] != user.uid) {
      throw Exception('You can only resend your own applications.');
    }
    if ((_readString(application['status']) ?? 'pending') != 'cancelled') {
      throw Exception('Only cancelled applications can be resent.');
    }

    final jobId = _readString(application['jobId']);
    if (jobId == null) {
      throw Exception('This job is no longer available.');
    }

    final jobSnapshot = await _firestore.collection('jobs').doc(jobId).get();
    final job = jobSnapshot.data();
    if (!jobSnapshot.exists || job == null) {
      throw Exception('This job is no longer available.');
    }

    final status = _readString(job['status']);
    final visibility = _readString(job['visibility']);
    final isVisible = visibility == null || visibility == 'published';
    if (status != 'open' || !isVisible) {
      throw Exception('This job is no longer open for applications.');
    }

    await applicationRef.update({
      'status': 'pending',
      'resentAt': FieldValue.serverTimestamp(),
      'lastResentAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'cancelledAt': FieldValue.delete(),
      'cancelledBy': FieldValue.delete(),
      'resendCount': FieldValue.increment(1),
    });

    final employerId =
        _readString(application['employerId']) ??
        _readString(job['employerId']) ??
        '';
    if (employerId.isEmpty) {
      throw Exception(
        'Could not notify employer because employerId is missing.',
      );
    }

    final employeeName = await _loadEmployeeName(user.uid);
    final jobTitle = _readString(job['title']);
    final body = _resendNotificationBody(employeeName, jobTitle);
    const title = '📩 New Application';

    debugPrint(
      'EmployeeApplicationService.resendCancelledApplication: creating '
      'notification employerId=$employerId jobId=$jobId '
      'applicationId=$applicationId title="$title" body="$body"',
    );

    try {
      await _notificationService.createNotification(
        userId: employerId,
        type: 'application_created',
        title: title,
        body: body,
        relatedJobId: jobId,
        relatedApplicationId: applicationId,
        senderId: user.uid,
      );
      debugPrint(
        'EmployeeApplicationService.resendCancelledApplication: notification '
        'created for applicationId=$applicationId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'EmployeeApplicationService.resendCancelledApplication: failed to '
        'create notification for applicationId=$applicationId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<EmployeeApplicationItem>> _hydrateApplications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final items = <EmployeeApplicationItem>[];

    for (final doc in snapshot.docs) {
      final application = doc.data();
      final jobId = _readString(application['jobId']);
      final employerId = _readString(application['employerId']);

      Map<String, dynamic>? jobData;
      Map<String, dynamic>? employerData;

      if (jobId != null) {
        final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
        jobData = jobDoc.data();
      }

      final resolvedEmployerId =
          employerId ?? _readString(jobData?['employerId']);
      if (resolvedEmployerId != null) {
        final employerDoc = await _firestore
            .collection('employerProfiles')
            .doc(resolvedEmployerId)
            .get();
        employerData = employerDoc.data();
      }

      items.add(
        EmployeeApplicationItem.fromData(
          applicationId: doc.id,
          applicationData: application,
          jobData: jobData,
          employerData: employerData,
        ),
      );
    }

    items.sort(EmployeeApplicationItem.compareDefault);
    return items;
  }

  Future<String?> _loadEmployeeName(String employeeId) async {
    final snapshot = await _firestore
        .collection('employeeProfiles')
        .doc(employeeId)
        .get();
    final data = snapshot.data();
    return _readString(data?['name']) ??
        _readString(data?['fullName']) ??
        _readString(_auth.currentUser?.displayName);
  }
}

String _resendNotificationBody(String? employeeName, String? jobTitle) {
  if (employeeName != null && jobTitle != null) {
    return '$employeeName applied again for $jobTitle';
  }
  if (jobTitle != null) {
    return 'A worker applied again for $jobTitle';
  }
  return 'A worker applied again for this job';
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

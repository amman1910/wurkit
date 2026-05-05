import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicationService {
  ApplicationService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _readString(Map<String, dynamic>? data, String key, String fallback) {
    final value = data?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  void _addOptionalField(
    Map<String, dynamic> target,
    String targetKey,
    Map<String, dynamic>? source,
    String sourceKey,
  ) {
    final value = source?[sourceKey];
    if (value != null) {
      target[targetKey] = value;
    }
  }

  Future<String> _resolveEmployeeName(String employeeId) async {
    final profileDoc = await _firestore
        .collection('employeeProfiles')
        .doc(employeeId)
        .get();
    final profileData = profileDoc.data();
    final profileName = profileData?['name'] as String?;

    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }

    final currentUser = _auth.currentUser;
    return currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : 'Worker';
  }

  Future<bool> hasApplied({
    required String jobId,
    required String employeeId,
  }) async {
    final query = await _firestore
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<void> applyToJob({
    required String jobId,
    required String employerId,
    required String jobTitle,
    String? employeeId,
    String? employeeName,
    String message = '',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null && employeeId == null) {
      throw Exception('User not authenticated');
    }

    final applicantId = employeeId ?? currentUser!.uid;
    final applicantName =
        employeeName ?? await _resolveEmployeeName(applicantId);

    if (await hasApplied(jobId: jobId, employeeId: applicantId)) {
      throw Exception('You already applied to this job');
    }

    final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
    final jobData = jobDoc.data();

    if (jobData == null) {
      throw Exception('Job not found');
    }

    if (jobData['status'] != 'open') {
      throw Exception('Cannot apply to a closed job');
    }

    final applicationRef = _firestore.collection('applications').doc();
    final applicationData = {
      'applicationId': applicationRef.id,
      'jobId': jobId,
      'employerId': employerId,
      'employeeId': applicantId,
      'jobTitle': jobTitle,
      'employeeName': applicantName,
      'status': 'pending',
      'message': message.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await applicationRef.set(applicationData);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getEmployeeApplications(
    String employeeId,
  ) {
    return _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getApplicationsForEmployer(
    String employerId,
  ) {
    return _firestore
        .collection('applications')
        .where('employerId', isEqualTo: employerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final allowedStatuses = {'pending', 'approved', 'rejected'};
    if (!allowedStatuses.contains(status)) {
      throw Exception('Invalid application status');
    }

    final applicationRef = _firestore
        .collection('applications')
        .doc(applicationId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);

      if (!applicationDoc.exists) {
        throw Exception('Application not found');
      }

      final applicationData = applicationDoc.data();
      if (applicationData == null) {
        throw Exception('Application data is unavailable');
      }

      final employerId = applicationData['employerId'] as String?;
      if (employerId != currentUser.uid) {
        throw Exception('You can only update applications for your own jobs');
      }

      if (status == 'rejected') {
        transaction.update(applicationRef, {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      if (status == 'pending') {
        transaction.update(applicationRef, {
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final existingMatchId = applicationData['matchId'] as String?;
      final existingChatId = applicationData['chatId'] as String?;
      if (existingMatchId?.trim().isNotEmpty == true &&
          existingChatId?.trim().isNotEmpty == true) {
        transaction.update(applicationRef, {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final jobId = applicationData['jobId'] as String?;
      final employeeId = applicationData['employeeId'] as String?;
      if (jobId == null || jobId.trim().isEmpty) {
        throw Exception('Application job is missing');
      }
      if (employeeId == null || employeeId.trim().isEmpty) {
        throw Exception('Application employee is missing');
      }

      final jobRef = _firestore.collection('jobs').doc(jobId);
      final employeeProfileRef = _firestore
          .collection('employeeProfiles')
          .doc(employeeId);
      final employerProfileRef = _firestore
          .collection('employerProfiles')
          .doc(employerId);

      final jobDoc = await transaction.get(jobRef);
      final employeeProfileDoc = await transaction.get(employeeProfileRef);
      final employerProfileDoc = await transaction.get(employerProfileRef);

      final jobData = jobDoc.data();
      final employeeProfileData = employeeProfileDoc.data();
      final employerProfileData = employerProfileDoc.data();

      final employeeName = _readString(
        applicationData,
        'employeeName',
        _readString(employeeProfileData, 'name', 'Worker'),
      );
      final employeeImageUrl = _readString(
        employeeProfileData,
        'profileImageUrl',
        '',
      );
      final employerName = _readString(
        employerProfileData,
        'businessName',
        'Business',
      );
      final employerImageUrl = _readString(
        employerProfileData,
        'businessLogoUrl',
        '',
      );
      final jobTitle = _readString(
        applicationData,
        'jobTitle',
        _readString(jobData, 'title', _readString(jobData, 'jobTitle', 'Job')),
      );

      final matchRef = _firestore.collection('matches').doc();
      final chatRef = _firestore.collection('chats').doc();

      final matchData = <String, dynamic>{
        'matchId': matchRef.id,
        'applicationId': applicationId,
        'jobId': jobId,
        'employeeId': employeeId,
        'employerId': employerId,
        'employeeName': employeeName,
        'employeeImageUrl': employeeImageUrl,
        'employerName': employerName,
        'employerImageUrl': employerImageUrl,
        'jobTitle': jobTitle,
        'chatId': chatRef.id,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      _addOptionalField(matchData, 'jobLocation', jobData, 'location');
      _addOptionalField(matchData, 'workDate', jobData, 'workDate');
      _addOptionalField(matchData, 'salaryAmount', jobData, 'salaryAmount');
      _addOptionalField(matchData, 'paymentType', jobData, 'paymentType');

      final chatData = <String, dynamic>{
        'chatId': chatRef.id,
        'matchId': matchRef.id,
        'applicationId': applicationId,
        'jobId': jobId,
        'employeeId': employeeId,
        'employerId': employerId,
        'participants': [employeeId, employerId],
        'participantNames': {
          employeeId: employeeName,
          employerId: employerName,
        },
        'participantImages': {
          employeeId: employeeImageUrl,
          employerId: employerImageUrl,
        },
        'jobTitle': jobTitle,
        'lastMessage': '',
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'unreadCounts': {employeeId: 0, employerId: 0},
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.update(applicationRef, {
        'status': 'approved',
        'matchId': matchRef.id,
        'chatId': chatRef.id,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(matchRef, matchData);
      transaction.set(chatRef, chatData);
    });
  }
}

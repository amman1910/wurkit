import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicationService {
  ApplicationService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> _resolveEmployeeName(String employeeId) async {
    final profileDoc = await _firestore.collection('employeeProfiles').doc(employeeId).get();
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
    print('DEBUG: Running hasApplied query: applications.where(jobId=$jobId, employeeId=$employeeId).limit(1).get()');
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
    final applicantName = employeeName ?? await _resolveEmployeeName(applicantId);

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
      String employeeId) {
    print('DEBUG: Running getEmployeeApplications query: applications.where(employeeId=$employeeId).orderBy(createdAt DESC).snapshots()');
    return _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getApplicationsForEmployer(
      String employerId) {
    print('DEBUG: Running getApplicationsForEmployer query: applications.where(employerId=$employerId).orderBy(createdAt DESC).snapshots()');
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

    final applicationRef = _firestore.collection('applications').doc(applicationId);
    final applicationDoc = await applicationRef.get();

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

    await applicationRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

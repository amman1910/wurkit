import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class JobService {
  JobService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<Map<String, dynamic>?> getCurrentEmployerProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _firestore
        .collection('employerProfiles')
        .doc(currentUser.uid)
        .get();
    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  Future<String> uploadJobImage({required File imageFile}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final millis = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child(
      'job_images/${currentUser.uid}/job_$millis.jpg',
    );
    final uploadTask = await ref.putFile(imageFile);
    return uploadTask.ref.getDownloadURL();
  }

  Future<Map<String, dynamic>> getOwnedJobData(String jobId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final snapshot = await _firestore.collection('jobs').doc(jobId).get();
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Job not found');
    }
    if (data['employerId'] != currentUser.uid) {
      throw Exception('You can only manage your own jobs');
    }

    return data;
  }

  /// Creates a draft or published job document in Firestore.
  Future<void> createJob({
    required Map<String, dynamic> jobData,
    required bool publish,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      ...jobData,
      'employerId': currentUser.uid,
      'visibility': publish ? 'published' : 'draft',
      'status': publish ? 'open' : 'draft',
      'createdAt': now,
      'updatedAt': now,
      'publishedAt': publish ? now : null,
    };

    data.removeWhere((_, value) => value == null);
    await _firestore.collection('jobs').add(data);
  }

  Future<void> updateJob({
    required String jobId,
    required Map<String, dynamic> jobData,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    await _assertOwnsJob(jobId, currentUser.uid);

    const editableFields = {
      'title',
      'description',
      'jobCategory',
      'jobCategorySource',
      'requiredSkills',
      'salaryAmount',
      'salaryType',
      'startAsSoonAsPossible',
      'startDate',
      'endDate',
      'urgent',
      'shifts',
      'location',
      'jobAddress',
      'jobPlaceId',
      'jobLocation',
      'jobCountry',
      'imageUrls',
    };

    final update = <String, dynamic>{};
    for (final field in editableFields) {
      if (jobData.containsKey(field)) {
        update[field] = jobData[field];
      }
    }
    update['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('jobs').doc(jobId).update(update);
  }

  /// Stream of open jobs sorted by createdAt descending
  Stream<QuerySnapshot<Map<String, dynamic>>> getOpenJobs() {
    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getEmployerJobs() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('jobs')
        .where('employerId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<JobApplicationStats> getApplicationStatsForJob(String jobId) async {
    final snapshot = await _firestore
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .get();

    return JobApplicationStats.fromApplications(snapshot.docs);
  }

  Future<Map<String, JobApplicationStats>> loadApplicationStatsForJobs(
    List<String> jobIds,
  ) async {
    final stats = <String, JobApplicationStats>{};
    await Future.wait(
      jobIds.map((jobId) async {
        stats[jobId] = await getApplicationStatsForJob(jobId);
      }),
    );
    return stats;
  }

  Future<void> updateJobStatus({
    required String jobId,
    required String status,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final allowedStatuses = {'draft', 'open', 'filled', 'closed', 'cancelled'};
    if (!allowedStatuses.contains(status)) {
      throw Exception('Invalid job status');
    }

    await _assertOwnsJob(jobId, currentUser.uid);

    final update = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'open') {
      update['visibility'] = 'published';
      update['publishedAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('jobs').doc(jobId).update(update);
  }

  Future<void> closeJob(String jobId) {
    return updateJobStatus(jobId: jobId, status: 'closed');
  }

  Future<void> markJobAsFilled(String jobId) {
    return updateJobStatus(jobId: jobId, status: 'filled');
  }

  Future<void> reopenJob(String jobId) {
    return updateJobStatus(jobId: jobId, status: 'open');
  }

  Future<void> publishDraft(String jobId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    await _assertOwnsJob(jobId, currentUser.uid);

    await _firestore.collection('jobs').doc(jobId).update({
      'visibility': 'published',
      'status': 'open',
      'publishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDraft(String jobId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final ref = _firestore.collection('jobs').doc(jobId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Job not found');
    }

    final isOwner = data['employerId'] == currentUser.uid;
    final isDraft = data['visibility'] == 'draft' || data['status'] == 'draft';
    if (!isOwner || !isDraft) {
      throw Exception('Only drafts can be deleted');
    }

    await ref.delete();
  }

  Future<void> _assertOwnsJob(String jobId, String uid) async {
    final snapshot = await _firestore.collection('jobs').doc(jobId).get();
    final data = snapshot.data();
    if (data == null) {
      throw Exception('Job not found');
    }
    if (data['employerId'] != uid) {
      throw Exception('You can only manage your own jobs');
    }
  }
}

class JobApplicationStats {
  const JobApplicationStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  const JobApplicationStats.empty()
    : total = 0,
      pending = 0,
      approved = 0,
      rejected = 0;

  final int total;
  final int pending;
  final int approved;
  final int rejected;

  factory JobApplicationStats.fromApplications(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> applications,
  ) {
    var pending = 0;
    var approved = 0;
    var rejected = 0;

    for (final application in applications) {
      switch (application.data()['status'] as String? ?? 'pending') {
        case 'approved':
          approved++;
          break;
        case 'rejected':
          rejected++;
          break;
        default:
          pending++;
      }
    }

    return JobApplicationStats(
      total: applications.length,
      pending: pending,
      approved: approved,
      rejected: rejected,
    );
  }
}

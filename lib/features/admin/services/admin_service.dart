import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/admin_category_item.dart';
import '../models/admin_job_item.dart';
import '../models/admin_review_item.dart';
import '../models/admin_stats.dart';
import '../models/admin_user_item.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<AdminStats> watchStats() async* {
    yield await _fetchStats();
    yield* Stream.periodic(
      const Duration(seconds: 15),
    ).asyncMap((_) => _fetchStats());
  }

  Stream<List<AdminUserItem>> watchUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminUserItem.fromDoc).toList())
        .map((items) {
          items.sort((a, b) {
            final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
          return items;
        });
  }

  Stream<List<AdminJobItem>> watchJobs() {
    return _firestore
        .collection('jobs')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminJobItem.fromDoc).toList())
        .map((items) {
          items.sort((a, b) {
            final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
          return items;
        });
  }

  Stream<List<AdminReviewItem>> watchReviews() {
    return _firestore
        .collection('reviews')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(AdminReviewItem.fromDoc).toList())
        .map((items) {
          items.sort((a, b) {
            final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bMillis.compareTo(aMillis);
          });
          return items;
        });
  }

  Stream<List<AdminCategoryItem>> watchCategories() {
    return _firestore
        .collection('jobCategories')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(AdminCategoryItem.fromDoc).toList(),
        )
        .map((items) {
          items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return items;
        });
  }

  Future<void> blockUser(String userId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null && currentUserId == userId) {
      throw Exception('You cannot block your own admin account.');
    }

    await _firestore.collection('users').doc(userId).set({
      'isBlocked': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser(String userId) {
    return _firestore.collection('users').doc(userId).set({
      'isBlocked': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> verifyUser(String userId) {
    return _firestore.collection('users').doc(userId).set({
      'isVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unverifyUser(String userId) {
    return _firestore.collection('users').doc(userId).set({
      'isVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteReview(String reviewId) {
    return _firestore.collection('reviews').doc(reviewId).delete();
  }

  Future<void> closeJob(String jobId) {
    return _firestore.collection('jobs').doc(jobId).set({
      'status': 'closed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw Exception('Category name is required.');
    }

    final ref = _firestore.collection('jobCategories').doc();
    await ref.set({
      'categoryId': ref.id,
      'name': trimmed,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) {
    return _firestore.collection('jobCategories').doc(categoryId).set({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isAdminUser(String userId) async {
    if (userId.trim().isEmpty) {
      return false;
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    final role = (doc.data()?['role'] as String?)?.trim().toLowerCase();
    return role == 'admin';
  }

  Future<bool> isUserBlocked(String userId) async {
    if (userId.trim().isEmpty) {
      return false;
    }

    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['isBlocked'] == true;
  }

  Future<AdminStats> _fetchStats() async {
    final users = _firestore.collection('users');
    final jobs = _firestore.collection('jobs');
    final reports = _firestore.collection('reports');

    final totalEmployeesFuture = users
        .where('role', isEqualTo: 'employee')
        .count()
        .get();
    final totalEmployersFuture = users
        .where('role', isEqualTo: 'employer')
        .count()
        .get();
    final totalUsersFuture = users.count().get();
    final openJobsFuture = jobs
        .where('status', isEqualTo: 'open')
        .count()
        .get();
    final closedJobsFuture = jobs
        .where('status', whereIn: ['closed', 'filled'])
        .count()
        .get();
    final applicationsFuture = _firestore
        .collection('applications')
        .count()
        .get();
    final reviewsFuture = _firestore.collection('reviews').count().get();
    final reportsFuture = reports.count().get();
    final pendingReportsFuture = reports
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    final blockedUsersFuture = users
        .where('isBlocked', isEqualTo: true)
        .count()
        .get();

    final results = await Future.wait([
      totalEmployeesFuture,
      totalEmployersFuture,
      totalUsersFuture,
      openJobsFuture,
      closedJobsFuture,
      applicationsFuture,
      reviewsFuture,
      reportsFuture,
      pendingReportsFuture,
      blockedUsersFuture,
    ]);

    return AdminStats(
      totalEmployees: results[0].count ?? 0,
      totalEmployers: results[1].count ?? 0,
      totalUsers: results[2].count ?? 0,
      openJobs: results[3].count ?? 0,
      closedOrFilledJobs: results[4].count ?? 0,
      totalApplications: results[5].count ?? 0,
      totalReviews: results[6].count ?? 0,
      totalReports: results[7].count ?? 0,
      pendingReports: results[8].count ?? 0,
      blockedUsers: results[9].count ?? 0,
    );
  }
}

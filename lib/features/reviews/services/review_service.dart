import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';

class ReviewService {
  ReviewService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> addReview({
    required String jobId,
    required String reviewerId,
    required String reviewerRole,
    required String targetUserId,
    required String targetUserName,
    required String targetRole,
    required int rating,
    required String comment,
    String? reviewerName,
  }) async {
    final trimmedJobId = jobId.trim();
    final trimmedReviewerId = reviewerId.trim();
    final trimmedReviewerRole = reviewerRole.trim();
    final trimmedTargetUserId = targetUserId.trim();
    final trimmedTargetUserName = targetUserName.trim();
    final trimmedTargetRole = targetRole.trim();
    final trimmedComment = comment.trim();

    if (trimmedJobId.isEmpty ||
        trimmedReviewerId.isEmpty ||
        trimmedReviewerRole.isEmpty ||
        trimmedTargetUserId.isEmpty ||
        trimmedTargetUserName.isEmpty ||
        trimmedTargetRole.isEmpty) {
      throw Exception('Missing review data.');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('Please choose a rating from 1 to 5.');
    }

    final reviewId = _reviewDocId(
      jobId: trimmedJobId,
      reviewerId: trimmedReviewerId,
      targetUserId: trimmedTargetUserId,
    );
    final reviewRef = _firestore.collection('reviews').doc(reviewId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reviewRef);
      if (existing.exists) {
        throw Exception('You already reviewed this person for this job.');
      }

      final resolvedReviewerName = reviewerName?.trim().isNotEmpty == true
          ? reviewerName!.trim()
          : await _resolveReviewerName(
              reviewerId: trimmedReviewerId,
              reviewerRole: trimmedReviewerRole,
            );

      transaction.set(reviewRef, {
        'reviewId': reviewId,
        'jobId': trimmedJobId,
        'reviewerId': trimmedReviewerId,
        'reviewerName': resolvedReviewerName,
        'reviewerRole': trimmedReviewerRole,
        'targetUserId': trimmedTargetUserId,
        'targetUserName': trimmedTargetUserName,
        'targetRole': trimmedTargetRole,
        'rating': rating,
        'comment': trimmedComment,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<Review>> getReviewsForUser(String userId) {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('reviews')
        .where('targetUserId', isEqualTo: trimmedUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Review.fromFirestore).toList(growable: false),
        );
  }

  Future<double?> getAverageRating(String userId) async {
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('reviews')
        .where('targetUserId', isEqualTo: trimmedUserId)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final total = snapshot.docs.fold<int>(0, (sum, doc) {
      final rating = doc.data()['rating'];
      if (rating is int) {
        return sum + rating;
      }
      if (rating is num) {
        return sum + rating.round();
      }
      return sum;
    });

    return total / snapshot.docs.length;
  }

  Future<bool> hasUserReviewedJob({
    required String jobId,
    required String reviewerId,
    required String targetUserId,
  }) async {
    final reviewRef = _firestore
        .collection('reviews')
        .doc(
          _reviewDocId(
            jobId: jobId,
            reviewerId: reviewerId,
            targetUserId: targetUserId,
          ),
        );

    final snapshot = await reviewRef.get();
    return snapshot.exists;
  }

  String _reviewDocId({
    required String jobId,
    required String reviewerId,
    required String targetUserId,
  }) {
    return '${jobId.trim()}_${reviewerId.trim()}_${targetUserId.trim()}';
  }

  Future<String> _resolveReviewerName({
    required String reviewerId,
    required String reviewerRole,
  }) async {
    final role = reviewerRole.trim();
    if (role == 'employee') {
      final profileDoc = await _firestore
          .collection('employeeProfiles')
          .doc(reviewerId)
          .get();
      final profileName = profileDoc.data()?['name'] as String?;
      if (profileName != null && profileName.trim().isNotEmpty) {
        return profileName.trim();
      }
      final displayName = _auth.currentUser?.displayName?.trim();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
      return 'Worker';
    }

    if (role == 'employer') {
      final profileDoc = await _firestore
          .collection('employerProfiles')
          .doc(reviewerId)
          .get();
      final profileName = profileDoc.data()?['businessName'] as String?;
      if (profileName != null && profileName.trim().isNotEmpty) {
        return profileName.trim();
      }
      final displayName = _auth.currentUser?.displayName?.trim();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
      return 'Business';
    }

    final displayName = _auth.currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return 'User';
  }
}

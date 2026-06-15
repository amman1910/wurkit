import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  const Review({
    required this.reviewId,
    required this.jobId,
    required this.reviewerId,
    required this.reviewerName,
    required this.reviewerRole,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetRole,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reviewId;
  final String jobId;
  final String reviewerId;
  final String reviewerName;
  final String reviewerRole;
  final String targetUserId;
  final String targetUserName;
  final String targetRole;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Review(
      reviewId: _readString(data['reviewId']) ?? doc.id,
      jobId: _readString(data['jobId']) ?? '',
      reviewerId: _readString(data['reviewerId']) ?? '',
      reviewerName: _readString(data['reviewerName']) ?? 'User',
      reviewerRole: _readString(data['reviewerRole']) ?? 'employee',
      targetUserId: _readString(data['targetUserId']) ?? '',
      targetUserName: _readString(data['targetUserName']) ?? 'User',
      targetRole: _readString(data['targetRole']) ?? 'employee',
      rating: _readRating(data['rating']),
      comment: _readString(data['comment']) ?? '',
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _readRating(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  return 0;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

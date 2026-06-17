import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReviewItem {
  const AdminReviewItem({
    required this.reviewId,
    required this.rating,
    required this.comment,
    required this.reviewerName,
    required this.reviewerRole,
    required this.targetUserName,
    required this.targetRole,
    required this.createdAt,
  });

  final String reviewId;
  final int rating;
  final String comment;
  final String reviewerName;
  final String reviewerRole;
  final String targetUserName;
  final String targetRole;
  final DateTime? createdAt;

  factory AdminReviewItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdRaw = data['createdAt'];

    int rating = 0;
    final rawRating = data['rating'];
    if (rawRating is int) {
      rating = rawRating;
    } else if (rawRating is num) {
      rating = rawRating.round();
    }

    return AdminReviewItem(
      reviewId: doc.id,
      rating: rating,
      comment: (data['comment'] as String?)?.trim() ?? '',
      reviewerName: (data['reviewerName'] as String?)?.trim() ?? 'Unknown',
      reviewerRole: (data['reviewerRole'] as String?)?.trim() ?? '-',
      targetUserName: (data['targetUserName'] as String?)?.trim() ?? 'Unknown',
      targetRole: (data['targetRole'] as String?)?.trim() ?? '-',
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
    );
  }
}

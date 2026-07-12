import 'package:cloud_firestore/cloud_firestore.dart';

class AiMatchInsight {
  const AiMatchInsight({
    required this.employeeId,
    required this.jobId,
    required this.aiScore,
    required this.finalScore,
    required this.reason,
    required this.strengths,
    required this.weaknesses,
    required this.inputHash,
    required this.model,
    this.createdAt,
    this.expiresAt,
  });

  final String employeeId;
  final String jobId;
  final double aiScore;
  final double finalScore;
  final String reason;
  final List<String> strengths;
  final List<String> weaknesses;
  final String inputHash;
  final String model;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory AiMatchInsight.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AiMatchInsight(
      employeeId: _readString(data['employeeId']),
      jobId: _readString(data['jobId']),
      aiScore: _readDouble(data['aiScore']) ?? 0,
      finalScore: _readDouble(data['finalScore']) ?? 0,
      reason: _readString(data['reason']),
      strengths: _readStringList(data['strengths']),
      weaknesses: _readStringList(data['weaknesses']),
      inputHash: _readString(data['inputHash']),
      model: _readString(data['model']),
      createdAt: _readDateTime(data['createdAt']),
      expiresAt: _readDateTime(data['expiresAt']),
    );
  }

  Map<String, dynamic> toFirestore({
    DateTime? fallbackCreatedAt,
    DateTime? fallbackExpiresAt,
  }) {
    final resolvedCreatedAt = createdAt ?? fallbackCreatedAt ?? DateTime.now();
    final resolvedExpiresAt =
        expiresAt ??
        fallbackExpiresAt ??
        resolvedCreatedAt.add(const Duration(days: 7));

    return {
      'employeeId': employeeId.trim(),
      'jobId': jobId.trim(),
      'aiScore': aiScore,
      'finalScore': finalScore,
      'reason': reason.trim(),
      'strengths': strengths
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'weaknesses': weaknesses
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'inputHash': inputHash.trim(),
      'model': model.trim(),
      'createdAt': Timestamp.fromDate(resolvedCreatedAt),
      'expiresAt': Timestamp.fromDate(resolvedExpiresAt),
    };
  }
}

class AiMatchInsightCacheService {
  AiMatchInsightCacheService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionPath = 'aiMatchInsights';
  static const Duration _defaultExpiration = Duration(days: 7);

  final FirebaseFirestore _firestore;

  Future<AiMatchInsight?> getValidInsight({
    required String employeeId,
    required String jobId,
    required String inputHash,
  }) async {
    final trimmedEmployeeId = employeeId.trim();
    final trimmedJobId = jobId.trim();
    final trimmedInputHash = inputHash.trim();

    if (trimmedEmployeeId.isEmpty ||
        trimmedJobId.isEmpty ||
        trimmedInputHash.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection(_collectionPath)
        .doc(buildInsightDocId(trimmedEmployeeId, trimmedJobId))
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final insight = AiMatchInsight.fromFirestore(snapshot);
    if (insight.inputHash != trimmedInputHash) {
      return null;
    }

    final expiresAt = insight.expiresAt;
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      return null;
    }

    return insight;
  }

  Future<void> saveInsight(AiMatchInsight insight) async {
    final trimmedEmployeeId = insight.employeeId.trim();
    final trimmedJobId = insight.jobId.trim();

    if (trimmedEmployeeId.isEmpty || trimmedJobId.isEmpty) {
      throw Exception('Missing AI match insight identifiers.');
    }

    final now = DateTime.now();
    await _firestore
        .collection(_collectionPath)
        .doc(buildInsightDocId(trimmedEmployeeId, trimmedJobId))
        .set(
          insight.toFirestore(
            fallbackCreatedAt: now,
            fallbackExpiresAt: now.add(_defaultExpiration),
          ),
        );
  }

  String buildInsightDocId(String employeeId, String jobId) {
    return '${employeeId.trim()}_${jobId.trim()}';
  }
}

String _readString(Object? value) {
  if (value is! String) {
    return '';
  }

  return value.trim();
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

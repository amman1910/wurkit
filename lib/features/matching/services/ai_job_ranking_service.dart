import 'package:cloud_functions/cloud_functions.dart';

import '../../jobs/models/employee_job_discovery_item.dart';
import 'ai_matching_payload_builder.dart';
import 'job_matching_service.dart';

class AiJobRankingResult {
  const AiJobRankingResult({required this.source, required this.ranking});

  final String source;
  final List<AiRankedJob> ranking;

  factory AiJobRankingResult.empty() {
    return const AiJobRankingResult(source: 'empty', ranking: []);
  }

  factory AiJobRankingResult.fromMap(Map<String, dynamic> data) {
    return AiJobRankingResult(
      source: _readString(data['source'], fallback: 'unknown'),
      ranking: _readRankedJobs(data['ranking']),
    );
  }
}

class AiRankedJob {
  const AiRankedJob({
    required this.jobId,
    required this.rank,
    required this.aiScore,
    required this.reason,
    required this.strengths,
    required this.weaknesses,
  });

  final String jobId;
  final int rank;
  final int aiScore;
  final String reason;
  final List<String> strengths;
  final List<String> weaknesses;

  factory AiRankedJob.fromMap(Map<String, dynamic> data) {
    return AiRankedJob(
      jobId: _readString(data['jobId']),
      rank: _readInt(data['rank'], fallback: 1).clamp(1, 1 << 31),
      aiScore: _readInt(data['aiScore']).clamp(0, 100),
      reason: _readString(data['reason']),
      strengths: _readStringList(data['strengths']),
      weaknesses: _readStringList(data['weaknesses']),
    );
  }
}

class AiJobRankingService {
  AiJobRankingService({
    FirebaseFunctions? functions,
    AiMatchingPayloadBuilder? payloadBuilder,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _payloadBuilder = payloadBuilder ?? const AiMatchingPayloadBuilder();

  final FirebaseFunctions _functions;
  final AiMatchingPayloadBuilder _payloadBuilder;

  Future<AiJobRankingResult> rankEmployeeJobs({
    required Map<String, dynamic> employeeProfile,
    required List<EmployeeJobDiscoveryItem> jobs,
    Map<String, JobMatchResult>? matchResultsByJobId,
  }) async {
    if (jobs.isEmpty) {
      return AiJobRankingResult.empty();
    }

    final topJobs = jobs.take(10).toList();
    final payload = _payloadBuilder.buildEmployeeJobsPayload(
      employeeProfile: employeeProfile,
      jobs: topJobs,
      matchResultsByJobId: matchResultsByJobId,
    );

    try {
      final callable = _functions.httpsCallable('rankEmployeeJobsWithAI');
      final response = await callable.call<Map<String, dynamic>>(payload);
      return AiJobRankingResult.fromMap(_readMap(response.data));
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseFunctionsMessage(error));
    } catch (error) {
      throw Exception('Could not rank jobs with AI. Please try again.');
    }
  }
}

String _firebaseFunctionsMessage(FirebaseFunctionsException error) {
  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return 'Could not rank jobs with AI. Please try again.';
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const {};
}

String _readString(Object? value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  if (value is num) {
    return value.toString();
  }
  return fallback;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
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

List<AiRankedJob> _readRankedJobs(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => AiRankedJob.fromMap(Map<String, dynamic>.from(item)))
      .where((item) => item.jobId.isNotEmpty)
      .toList();
}

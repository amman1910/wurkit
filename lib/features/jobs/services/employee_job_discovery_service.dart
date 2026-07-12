import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../matching/services/ai_job_ranking_service.dart';
import '../../matching/services/job_matching_service.dart';
import '../../notifications/services/notification_service.dart';
import '../models/employee_job_discovery_item.dart';

class EmployeeJobDiscoveryService {
  EmployeeJobDiscoveryService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
    JobMatchingService? matchingService,
    AiJobRankingService? aiRankingService,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService(),
       _matchingService = matchingService ?? const JobMatchingService(),
       _aiRankingService = aiRankingService ?? AiJobRankingService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final JobMatchingService _matchingService;
  final AiJobRankingService _aiRankingService;

  Future<({double latitude, double longitude})?> loadEmployeeLocation() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final snapshot = await _firestore
        .collection('employeeProfiles')
        .doc(user.uid)
        .get();
    final location = snapshot.data()?['location'];
    if (location is! Map) return null;
    final lat = _readDouble(location['lat']);
    final lng = _readDouble(location['lng']);
    if (lat == null || lng == null) return null;
    return (latitude: lat, longitude: lng);
  }

  Future<List<EmployeeJobDiscoveryItem>> loadJobs() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to find jobs.');
    }

    final jobsSnapshot = await _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .get();

    final employeeProfileFuture = _loadEmployeeProfile(user.uid);
    final appliedIdsFuture = _loadAppliedJobIds(user.uid);
    final dismissedIdsFuture = _loadNotInterestedJobIds(user.uid);
    final employerIds = jobsSnapshot.docs
        .map((doc) => _readString(doc.data()['employerId']))
        .whereType<String>()
        .toSet()
        .toList();
    final employersFuture = _loadEmployers(employerIds);

    final employeeProfile = await employeeProfileFuture;
    final appliedIds = await appliedIdsFuture;
    final dismissedIds = await dismissedIdsFuture;
    final employers = await employersFuture;

    final items = jobsSnapshot.docs
        .where((doc) {
          final data = doc.data();
          final visibility = _readString(data['visibility']);
          final status = _readString(data['status']);
          final visible = visibility == null || visibility == 'published';
          return status == 'open' &&
              visible &&
              !appliedIds.contains(doc.id) &&
              !dismissedIds.contains(doc.id);
        })
        .map((doc) {
          final data = doc.data();
          final employerId = _readString(data['employerId']) ?? '';
          return EmployeeJobDiscoveryItem.fromFirestore(
            id: doc.id,
            data: data,
            employer:
                employers[employerId] ?? const EmployeeDiscoveryEmployer(),
          );
        })
        .toList();

    _sortByFreshness(items);

    return _rankJobsSafely(employeeProfile: employeeProfile, jobs: items);
  }

  Future<Set<String>> loadSavedJobIds() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const {};
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedJobs')
        .get();

    return snapshot.docs
        .map((doc) => _readString(doc.data()['jobId']) ?? doc.id)
        .toSet();
  }

  Future<List<EmployeeJobDiscoveryItem>> loadSavedJobs() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const [];
    }

    final savedIds = await loadSavedJobIds();
    if (savedIds.isEmpty) {
      return const [];
    }

    final dismissedIdsFuture = _loadNotInterestedJobIds(user.uid);
    final appliedIdsFuture = _loadAppliedJobIds(user.uid);
    final jobDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final ids = savedIds.toList();
    for (var start = 0; start < ids.length; start += 10) {
      final end = start + 10 > ids.length ? ids.length : start + 10;
      final chunk = ids.sublist(start, end);
      final snapshot = await _firestore
          .collection('jobs')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      jobDocs.addAll(snapshot.docs);
    }

    final employerIds = jobDocs
        .map((doc) => _readString(doc.data()['employerId']))
        .whereType<String>()
        .toSet()
        .toList();
    final employers = await _loadEmployers(employerIds);
    final dismissedIds = await dismissedIdsFuture;
    final appliedIds = await appliedIdsFuture;

    final items = jobDocs
        .where(
          (doc) =>
              !dismissedIds.contains(doc.id) && !appliedIds.contains(doc.id),
        )
        .map((doc) {
          final data = doc.data();
          final employerId = _readString(data['employerId']) ?? '';
          return EmployeeJobDiscoveryItem.fromFirestore(
            id: doc.id,
            data: data,
            employer:
                employers[employerId] ?? const EmployeeDiscoveryEmployer(),
          );
        })
        .toList();

    items.sort((a, b) {
      final aTime = a.publishedAt ?? a.createdAt ?? a.updatedAt;
      final bTime = b.publishedAt ?? b.createdAt ?? b.updatedAt;
      return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
        aTime?.millisecondsSinceEpoch ?? 0,
      );
    });
    return items;
  }

  Future<void> saveJob(EmployeeJobDiscoveryItem job) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to save jobs.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedJobs')
        .doc(job.id)
        .set({
          'jobId': job.id,
          'title': job.title,
          'businessName': job.businessName,
          'imageUrl': job.displayImageUrl,
          'savedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> unsaveJob(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to update saved jobs.');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('savedJobs')
        .doc(jobId)
        .delete();
  }

  Future<void> applyToJob(EmployeeJobDiscoveryItem job) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to apply.');
    }

    final existing = await _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: user.uid)
        .where('jobId', isEqualTo: job.id)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return;
    }

    final now = FieldValue.serverTimestamp();
    final applicationRef = await _firestore.collection('applications').add({
      'jobId': job.id,
      'employeeId': user.uid,
      'employerId': job.employerId,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    });

    if (job.employerId.trim().isEmpty) {
      return;
    }

    final employeeProfile = await _loadEmployeeNotificationProfile(user);
    final employeeName = employeeProfile.name ?? 'A worker';
    final jobTitle = _readString(job.title) ?? 'your job';
    final body = '$employeeName applied for $jobTitle';

    await _notificationService.createNotification(
      userId: job.employerId,
      type: 'application_created',
      title: '📩 New Application',
      body: body,
      relatedJobId: job.id,
      relatedApplicationId: applicationRef.id,
      senderId: user.uid,
      senderName: employeeProfile.name,
      senderImageUrl: employeeProfile.imageUrl,
    );
  }

  Future<void> markNotInterested(EmployeeJobDiscoveryItem job) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to update your feed.');
    }

    await _firestore
        .collection('employeeJobInteractions')
        .doc('${user.uid}_${job.id}')
        .set({
          'employeeId': user.uid,
          'jobId': job.id,
          'type': 'not_interested',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<Set<String>> _loadAppliedJobIds(String employeeId) async {
    final snapshot = await _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: employeeId)
        .get();

    return snapshot.docs
        .map((doc) => _readString(doc.data()['jobId']))
        .whereType<String>()
        .toSet();
  }

  Future<Set<String>> _loadNotInterestedJobIds(String employeeId) async {
    final snapshot = await _firestore
        .collection('employeeJobInteractions')
        .where('employeeId', isEqualTo: employeeId)
        .where('type', isEqualTo: 'not_interested')
        .get();

    return snapshot.docs
        .map((doc) => _readString(doc.data()['jobId']))
        .whereType<String>()
        .toSet();
  }

  Future<Map<String, dynamic>> _loadEmployeeProfile(String employeeId) async {
    try {
      final snapshot = await _firestore
          .collection('employeeProfiles')
          .doc(employeeId)
          .get();
      return {
        ...(snapshot.data() ?? <String, dynamic>{}),
        'employeeId': employeeId,
      };
    } catch (_) {
      return <String, dynamic>{'employeeId': employeeId};
    }
  }

  Future<List<EmployeeJobDiscoveryItem>> _rankJobsSafely({
    required Map<String, dynamic> employeeProfile,
    required List<EmployeeJobDiscoveryItem> jobs,
  }) async {
    if (jobs.length < 2) {
      return jobs;
    }

    try {
      final rankedMatches = _matchingService.rankJobsForEmployee(
        employeeProfile: employeeProfile,
        jobs: jobs,
      );
      final matchResults = {
        for (final result in rankedMatches) result.jobId: result,
      };
      if (matchResults.isEmpty) {
        return jobs;
      }

      final classicRankedJobs = [...jobs];
      classicRankedJobs.sort((a, b) {
        final aMatch = matchResults[a.id];
        final bMatch = matchResults[b.id];
        if (aMatch == null || bMatch == null) {
          return _compareByFreshness(a, b);
        }

        final scoreComparison = bMatch.totalScore.compareTo(aMatch.totalScore);
        if (scoreComparison != 0) {
          return scoreComparison;
        }

        final aDistance = aMatch.distanceKm ?? double.infinity;
        final bDistance = bMatch.distanceKm ?? double.infinity;
        final distanceComparison = aDistance.compareTo(bDistance);
        if (distanceComparison != 0) {
          return distanceComparison;
        }

        return _compareByFreshness(a, b);
      });

      var aiRanking = const <AiRankedJob>[];
      try {
        final aiResult = await _aiRankingService.rankEmployeeJobs(
          employeeProfile: employeeProfile,
          jobs: classicRankedJobs.take(10).toList(),
          matchResultsByJobId: matchResults,
        );
        aiRanking = aiResult.ranking;
      } catch (_) {
        // AI ranking is a feed signal only; classic matching remains the fallback.
      }

      return _balancedDiscoveryOrder(
        employeeId: _readString(employeeProfile['employeeId']) ?? '',
        jobs: jobs,
        matchResultsByJobId: matchResults,
        aiRanking: aiRanking,
      );
    } catch (_) {
      return jobs;
    }
  }

  List<EmployeeJobDiscoveryItem> _balancedDiscoveryOrder({
    required String employeeId,
    required List<EmployeeJobDiscoveryItem> jobs,
    required Map<String, JobMatchResult> matchResultsByJobId,
    required List<AiRankedJob> aiRanking,
  }) {
    final aiScoresByJobId = {
      for (final rankedJob in aiRanking) rankedJob.jobId: rankedJob.aiScore,
    };
    final hasAiRanking = aiScoresByJobId.isNotEmpty;
    final todayKey = _todayKey(DateTime.now());

    final scoredJobs = jobs.map((job) {
      final classicScore = matchResultsByJobId[job.id]?.totalScore ?? 0;
      final aiScore = aiScoresByJobId[job.id];
      final feedScore = _combineFeedScore(
        classicScore: classicScore,
        aiScore: aiScore,
        hasAiRanking: hasAiRanking,
        urgencyBoost: _urgencyBoost(job),
        jitter: _deterministicJitter(
          employeeId: employeeId,
          dateKey: todayKey,
          jobId: job.id,
        ),
      );
      return (job: job, score: feedScore);
    }).toList();

    scoredJobs.sort((left, right) {
      final scoreComparison = right.score.compareTo(left.score);
      if (scoreComparison != 0) return scoreComparison;

      final leftDistance =
          matchResultsByJobId[left.job.id]?.distanceKm ?? double.infinity;
      final rightDistance =
          matchResultsByJobId[right.job.id]?.distanceKm ?? double.infinity;
      final distanceComparison = leftDistance.compareTo(rightDistance);
      if (distanceComparison != 0) return distanceComparison;

      return _compareByFreshness(left.job, right.job);
    });

    return scoredJobs.map((item) => item.job).toList();
  }

  // Discovery is intentionally not a strict AI sort: classic match remains the
  // base, AI nudges strong Top 10 jobs, urgency helps timely work surface, and
  // deterministic jitter gives the feed daily variety without reshuffling builds.
  double _combineFeedScore({
    required double classicScore,
    required int? aiScore,
    required bool hasAiRanking,
    required double urgencyBoost,
    required double jitter,
  }) {
    if (!hasAiRanking || aiScore == null) {
      return classicScore * 0.85 + urgencyBoost * 0.10 + jitter * 0.05;
    }

    return classicScore * 0.60 +
        aiScore * 0.25 +
        urgencyBoost * 0.10 +
        jitter * 0.05;
  }

  double _urgencyBoost(EmployeeJobDiscoveryItem job) {
    var boost = 0.0;
    if (job.urgent || job.startAsSoonAsPossible) {
      boost = 85.0;
    }
    if (job.isToday) {
      boost = boost < 75.0 ? 75.0 : boost;
    } else if (_isTomorrow(job.startDate)) {
      boost = boost < 55.0 ? 55.0 : boost;
    }
    return boost;
  }

  double _deterministicJitter({
    required String employeeId,
    required String dateKey,
    required String jobId,
  }) {
    final seed = '$employeeId|$dateKey|$jobId';
    var hash = 0;
    for (final codeUnit in seed.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return (hash % 1000) / 10.0;
  }

  String _todayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  bool _isTomorrow(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  void _sortByFreshness(List<EmployeeJobDiscoveryItem> items) {
    items.sort(_compareByFreshness);
  }

  int _compareByFreshness(
    EmployeeJobDiscoveryItem a,
    EmployeeJobDiscoveryItem b,
  ) {
    final aTime = a.publishedAt ?? a.createdAt ?? a.updatedAt;
    final bTime = b.publishedAt ?? b.createdAt ?? b.updatedAt;
    return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
      aTime?.millisecondsSinceEpoch ?? 0,
    );
  }

  Future<Map<String, EmployeeDiscoveryEmployer>> _loadEmployers(
    List<String> employerIds,
  ) async {
    if (employerIds.isEmpty) {
      return const {};
    }

    final employers = <String, EmployeeDiscoveryEmployer>{};
    for (var start = 0; start < employerIds.length; start += 10) {
      final end = start + 10 > employerIds.length
          ? employerIds.length
          : start + 10;
      final chunk = employerIds.sublist(start, end);
      final snapshot = await _firestore
          .collection('employerProfiles')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        employers[doc.id] = EmployeeDiscoveryEmployer.fromMap(doc.data());
      }
    }
    return employers;
  }

  Future<_EmployeeNotificationProfile> _loadEmployeeNotificationProfile(
    User user,
  ) async {
    final snapshot = await _firestore
        .collection('employeeProfiles')
        .doc(user.uid)
        .get();
    final data = snapshot.data();
    final firstName = _readString(data?['firstName']);
    final lastName = _readString(data?['lastName']);
    final combinedName = [firstName, lastName].whereType<String>().join(' ');

    final name =
        _readString(data?['fullName']) ??
        _readString(data?['name']) ??
        _readString(data?['displayName']) ??
        _readString(combinedName) ??
        _readString(user.displayName);

    final imageUrl =
        _readString(data?['profileImageUrl']) ??
        _readString(data?['imageUrl']) ??
        _readString(data?['photoUrl']) ??
        _readString(data?['avatarUrl']) ??
        _readString(user.photoURL);

    return _EmployeeNotificationProfile(name: name, imageUrl: imageUrl);
  }
}

class _EmployeeNotificationProfile {
  const _EmployeeNotificationProfile({this.name, this.imageUrl});

  final String? name;
  final String? imageUrl;
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _readDouble(Object? value) {
  return value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}

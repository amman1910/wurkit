import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/utils/address_format_utils.dart';
import '../../../shared/services/google_places_service.dart';
import '../../jobs/models/employee_job_discovery_item.dart';
import '../../matching/services/ai_job_ranking_service.dart';
import '../../matching/services/job_matching_service.dart';

class EmployeeHomeService {
  EmployeeHomeService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    JobMatchingService? matchingService,
    AiJobRankingService? aiRankingService,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _matchingService = matchingService ?? const JobMatchingService(),
       _aiRankingService = aiRankingService ?? AiJobRankingService(),
       _googlePlacesService = GooglePlacesService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final JobMatchingService _matchingService;
  final AiJobRankingService _aiRankingService;
  final GooglePlacesService _googlePlacesService;

  Stream<EmployeeHomeProfile?> watchCurrentEmployeeProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(Exception('No authenticated user found'));
    }

    final uid = user.uid;
    return _firestore.collection('employeeProfiles').doc(uid).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        return null;
      }

      return EmployeeHomeProfile.fromMap(
        uid: uid,
        data: snapshot.data() ?? <String, dynamic>{},
      );
    });
  }

  Future<void> updateAvailabilityNow(bool isAvailableNow) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    await _firestore.collection('employeeProfiles').doc(user.uid).set({
      'isAvailableNow': isAvailableNow,
      'availableNow': isAvailableNow,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> enableAndSaveCurrentLocation() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are off. Turn them on and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is blocked. Enable it in app settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    String? locationName;
    try {
      locationName = await _googlePlacesService.reverseGeocodeLocality(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Coordinates remain useful even when a readable locality is unavailable.
    }

    await _firestore.collection('employeeProfiles').doc(user.uid).set({
      'locationPermissionGranted': true,
      'location': {'lat': position.latitude, 'lng': position.longitude},
      'locationName': locationName ?? FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<EmployeeHomeJob>> watchOpenJobs() {
    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => EmployeeHomeJob.fromMap(id: doc.id, data: doc.data()),
              )
              .toList(),
        );
  }

  Future<List<EmployeeHomeJob>> loadRecommendedJobs() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
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

    final jobs = jobsSnapshot.docs
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

    if (jobs.isEmpty) {
      return const [];
    }

    final matchResults = {
      for (final result in _matchingService.rankJobsForEmployee(
        employeeProfile: employeeProfile,
        jobs: jobs,
      ))
        result.jobId: result,
    };

    final classicRankedJobs = [...jobs]
      ..sort((a, b) {
        final aMatch = matchResults[a.id];
        final bMatch = matchResults[b.id];
        if (aMatch == null || bMatch == null) {
          return _compareByFreshness(a, b);
        }

        final scoreComparison = bMatch.totalScore.compareTo(aMatch.totalScore);
        if (scoreComparison != 0) return scoreComparison;

        final aDistance = aMatch.distanceKm ?? double.infinity;
        final bDistance = bMatch.distanceKm ?? double.infinity;
        final distanceComparison = aDistance.compareTo(bDistance);
        if (distanceComparison != 0) return distanceComparison;

        return _compareByFreshness(a, b);
      });

    var orderedJobs = classicRankedJobs;
    try {
      final aiResult = await _aiRankingService.rankEmployeeJobs(
        employeeProfile: employeeProfile,
        jobs: classicRankedJobs.take(10).toList(),
        matchResultsByJobId: matchResults,
      );
      orderedJobs = _mergeAiRankingWithClassicJobs(
        aiRanking: aiResult.ranking,
        classicRankedJobs: classicRankedJobs,
      );
    } catch (_) {
      // Home recommendations quietly fall back to classic ranking.
    }

    return orderedJobs.take(7).map(EmployeeHomeJob.fromDiscoveryItem).toList();
  }

  Future<EmployerPreview?> getEmployerPreview(String employerId) async {
    if (employerId.trim().isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('employerProfiles')
        .doc(employerId)
        .get();
    if (!snapshot.exists) {
      return null;
    }

    return EmployerPreview.fromMap(
      uid: employerId,
      data: snapshot.data() ?? <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> _loadEmployeeProfile(String employeeId) async {
    final snapshot = await _firestore
        .collection('employeeProfiles')
        .doc(employeeId)
        .get();
    return {
      ...(snapshot.data() ?? <String, dynamic>{}),
      'employeeId': employeeId,
    };
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

  List<EmployeeJobDiscoveryItem> _mergeAiRankingWithClassicJobs({
    required List<AiRankedJob> aiRanking,
    required List<EmployeeJobDiscoveryItem> classicRankedJobs,
  }) {
    if (aiRanking.isEmpty) {
      return classicRankedJobs;
    }

    final jobsById = {for (final job in classicRankedJobs) job.id: job};
    final includedIds = <String>{};
    final merged = <EmployeeJobDiscoveryItem>[];

    final rankedAiJobs = [...aiRanking]
      ..sort((a, b) => a.rank.compareTo(b.rank));
    for (final rankedJob in rankedAiJobs) {
      final job = jobsById[rankedJob.jobId];
      if (job == null || includedIds.contains(job.id)) {
        continue;
      }
      includedIds.add(job.id);
      merged.add(job);
    }

    for (final job in classicRankedJobs) {
      if (includedIds.add(job.id)) {
        merged.add(job);
      }
    }

    return merged;
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
}

class EmployeeHomeProfile {
  const EmployeeHomeProfile({
    required this.uid,
    this.name,
    this.profileImageUrl,
    required this.isAvailableNow,
    required this.locationPermissionGranted,
    this.latitude,
    this.longitude,
  });

  final String uid;
  final String? name;
  final String? profileImageUrl;
  final bool isAvailableNow;
  final bool locationPermissionGranted;
  final double? latitude;
  final double? longitude;

  bool get hasUsableLocation =>
      locationPermissionGranted && latitude != null && longitude != null;

  factory EmployeeHomeProfile.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    final location = data['location'];
    return EmployeeHomeProfile(
      uid: uid,
      name: _readString(data['name']),
      profileImageUrl: _readString(data['profileImageUrl']),
      isAvailableNow:
          _readBool(data['isAvailableNow']) ??
          _readBool(data['availableNow']) ??
          false,
      locationPermissionGranted:
          _readBool(data['locationPermissionGranted']) ?? false,
      latitude: location is Map ? _readDouble(location['lat']) : null,
      longitude: location is Map ? _readDouble(location['lng']) : null,
    );
  }
}

class EmployeeHomeJob {
  const EmployeeHomeJob({
    required this.id,
    required this.employerId,
    required this.title,
    this.description,
    this.location,
    this.salary,
    this.salaryType,
    required this.urgent,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String employerId;
  final String title;
  final String? description;
  final String? location;
  final double? salary;
  final String? salaryType;
  final bool urgent;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory EmployeeHomeJob.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final coordinates = data['jobLocation'] is Map
        ? data['jobLocation'] as Map
        : data['location'] is Map
        ? data['location'] as Map
        : const {};
    return EmployeeHomeJob(
      id: id,
      employerId: _readString(data['employerId']) ?? '',
      title: _readString(data['title']) ?? 'Open shift',
      description: _readString(data['description']),
      location:
          _readAddress(data['jobAddress']) ?? _readLocation(data['location']),
      salary: _readDouble(data['salaryAmount']) ?? _readDouble(data['salary']),
      salaryType: _readString(data['salaryType']),
      urgent: _readBool(data['urgent']) ?? false,
      latitude: _readDouble(coordinates['lat']),
      longitude: _readDouble(coordinates['lng']),
    );
  }

  factory EmployeeHomeJob.fromDiscoveryItem(EmployeeJobDiscoveryItem item) {
    return EmployeeHomeJob(
      id: item.id,
      employerId: item.employerId,
      title: item.title,
      description: item.description,
      location: item.location,
      salary: item.salaryAmount,
      salaryType: item.salaryType,
      urgent: item.urgent,
      latitude: item.latitude,
      longitude: item.longitude,
    );
  }
}

class EmployerPreview {
  const EmployerPreview({
    required this.uid,
    this.businessName,
    this.businessLogoUrl,
    this.city,
    this.businessAddress,
  });

  final String uid;
  final String? businessName;
  final String? businessLogoUrl;
  final String? city;
  final String? businessAddress;

  factory EmployerPreview.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return EmployerPreview(
      uid: uid,
      businessName: _readString(data['businessName']),
      businessLogoUrl: _readString(data['businessLogoUrl']),
      city: _readString(data['city']),
      businessAddress: _readString(data['businessAddress']),
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

bool? _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  return null;
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

String? _readLocation(Object? value) {
  if (value is String) {
    return _readString(value);
  }

  if (value is Map) {
    if (value['type'] == 'remote') {
      return 'Remote';
    }
    return _readAddress(value['address']);
  }

  return null;
}

String? _readAddress(Object? value) {
  final address = _readString(value);
  return address == null ? null : formatAddressForDisplay(address);
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../notifications/services/notification_service.dart';
import '../models/employee_job_discovery_item.dart';

class EmployeeJobDiscoveryService {
  EmployeeJobDiscoveryService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

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

    final appliedIdsFuture = _loadAppliedJobIds(user.uid);
    final dismissedIdsFuture = _loadNotInterestedJobIds(user.uid);
    final employerIds = jobsSnapshot.docs
        .map((doc) => _readString(doc.data()['employerId']))
        .whereType<String>()
        .toSet()
        .toList();
    final employersFuture = _loadEmployers(employerIds);

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

    items.sort((a, b) {
      final aTime = a.publishedAt ?? a.createdAt ?? a.updatedAt;
      final bTime = b.publishedAt ?? b.createdAt ?? b.updatedAt;
      return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
        aTime?.millisecondsSinceEpoch ?? 0,
      );
    });

    return items;
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

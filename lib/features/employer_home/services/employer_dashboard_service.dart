import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployerDashboardService {
  EmployerDashboardService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<EmployerDashboardData> watchDashboard() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(Exception('User not authenticated'));
    }

    final uid = user.uid;
    late final StreamController<EmployerDashboardData> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    DocumentSnapshot<Map<String, dynamic>>? profileSnapshot;
    QuerySnapshot<Map<String, dynamic>>? jobsSnapshot;
    QuerySnapshot<Map<String, dynamic>>? applicationsSnapshot;
    QuerySnapshot<Map<String, dynamic>>? matchesSnapshot;
    QuerySnapshot<Map<String, dynamic>>? chatsSnapshot;
    Map<String, Map<String, dynamic>>? candidateProfiles;

    void emitIfReady() {
      if (profileSnapshot == null ||
          jobsSnapshot == null ||
          applicationsSnapshot == null ||
          matchesSnapshot == null ||
          chatsSnapshot == null ||
          candidateProfiles == null ||
          controller.isClosed) {
        return;
      }

      controller.add(
        EmployerDashboardData.fromSnapshots(
          employerId: uid,
          profileSnapshot: profileSnapshot!,
          jobsSnapshot: jobsSnapshot!,
          applicationsSnapshot: applicationsSnapshot!,
          matchesSnapshot: matchesSnapshot!,
          chatsSnapshot: chatsSnapshot!,
          candidateProfiles: candidateProfiles!,
        ),
      );
    }

    controller = StreamController<EmployerDashboardData>.broadcast(
      onListen: () {
        subscriptions.add(
          _firestore.collection('employerProfiles').doc(uid).snapshots().listen(
            (snapshot) {
              profileSnapshot = snapshot;
              emitIfReady();
            },
            onError: controller.addError,
          ),
        );
        subscriptions.add(
          _firestore
              .collection('jobs')
              .where('employerId', isEqualTo: uid)
              .snapshots()
              .listen((snapshot) {
                jobsSnapshot = snapshot;
                emitIfReady();
              }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore
              .collection('applications')
              .where('employerId', isEqualTo: uid)
              .snapshots()
              .listen((snapshot) async {
                applicationsSnapshot = snapshot;
                try {
                  candidateProfiles = await _loadRecentCandidateProfiles(
                    snapshot,
                  );
                } catch (_) {
                  candidateProfiles = const {};
                }
                emitIfReady();
              }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore
              .collection('matches')
              .where('employerId', isEqualTo: uid)
              .snapshots()
              .listen((snapshot) {
                matchesSnapshot = snapshot;
                emitIfReady();
              }, onError: controller.addError),
        );
        subscriptions.add(
          _firestore
              .collection('chats')
              .where('participants', arrayContains: uid)
              .snapshots()
              .listen((snapshot) {
                chatsSnapshot = snapshot;
                emitIfReady();
              }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  Future<Map<String, Map<String, dynamic>>> _loadRecentCandidateProfiles(
    QuerySnapshot<Map<String, dynamic>> applications,
  ) async {
    final docs = [...applications.docs]
      ..sort(
        (a, b) => _readTimestampMillis(
          b.data()['createdAt'],
        ).compareTo(_readTimestampMillis(a.data()['createdAt'])),
      );
    final employeeIds = docs
        .map((doc) => _readString(doc.data()['employeeId']))
        .whereType<String>()
        .toSet()
        .take(3)
        .toList();
    final snapshots = await Future.wait(
      employeeIds.map(
        (id) => _firestore.collection('employeeProfiles').doc(id).get(),
      ),
    );
    return {
      for (final snapshot in snapshots)
        if (snapshot.exists) snapshot.id: snapshot.data() ?? {},
    };
  }
}

class EmployerDashboardData {
  EmployerDashboardData({
    required this.businessName,
    required this.stats,
    required this.attentionItems,
    required this.recentApplications,
    required this.activeJobs,
    required this.isNewEmployer,
  });

  final String businessName;
  final EmployerDashboardStats stats;
  final List<EmployerAttentionItem> attentionItems;
  final List<EmployerRecentApplication> recentApplications;
  final List<EmployerActiveJob> activeJobs;
  final bool isNewEmployer;

  factory EmployerDashboardData.fromSnapshots({
    required String employerId,
    required DocumentSnapshot<Map<String, dynamic>> profileSnapshot,
    required QuerySnapshot<Map<String, dynamic>> jobsSnapshot,
    required QuerySnapshot<Map<String, dynamic>> applicationsSnapshot,
    required QuerySnapshot<Map<String, dynamic>> matchesSnapshot,
    required QuerySnapshot<Map<String, dynamic>> chatsSnapshot,
    required Map<String, Map<String, dynamic>> candidateProfiles,
  }) {
    final profile = profileSnapshot.data();
    final jobs = jobsSnapshot.docs
        .map((doc) => _JobRecord.fromDoc(doc))
        .toList();
    final applications = applicationsSnapshot.docs
        .map(
          (doc) => _ApplicationRecord.fromDoc(
            doc,
            candidateProfile:
                candidateProfiles[_readString(doc.data()['employeeId'])],
          ),
        )
        .toList();
    final matches = matchesSnapshot.docs.map((doc) => doc.data()).toList();
    final chats = chatsSnapshot.docs.map((doc) => doc.data()).toList();

    final activeJobs = jobs.where((job) => job.isActive).toList()
      ..sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));
    final pendingApplications = applications
        .where((application) => application.status == 'pending')
        .toList();
    final activeMatches = matches
        .where((match) => _readString(match['status']) == 'active')
        .length;
    final unreadMessages = chats.fold<int>(0, (total, chat) {
      final unreadCounts = _readMap(chat['unreadCounts']);
      final count = unreadCounts[employerId];
      if (count is int) {
        return total + count;
      }
      if (count is num) {
        return total + count.toInt();
      }
      return total;
    });

    final applicationsByJobId = <String, int>{};
    for (final application in applications) {
      applicationsByJobId.update(
        application.jobId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final recentApplications = [...applications]
      ..sort((a, b) => b.createdAtMillis.compareTo(a.createdAtMillis));

    final urgentOpenJobs = activeJobs.where((job) => job.urgent).length;
    final attentionItems = <EmployerAttentionItem>[
      if (pendingApplications.isNotEmpty)
        EmployerAttentionItem(
          type: EmployerAttentionType.applications,
          count: pendingApplications.length,
          title:
              '${pendingApplications.length} applications waiting for review',
        ),
      if (unreadMessages > 0)
        EmployerAttentionItem(
          type: EmployerAttentionType.messages,
          count: unreadMessages,
          title: '$unreadMessages unread messages from workers',
        ),
      if (urgentOpenJobs > 0)
        EmployerAttentionItem(
          type: EmployerAttentionType.urgentJobs,
          count: urgentOpenJobs,
          title: '$urgentOpenJobs urgent jobs still need workers',
        ),
    ].take(3).toList();

    final stats = EmployerDashboardStats(
      activeJobs: activeJobs.length,
      pendingApplications: pendingApplications.length,
      activeMatches: activeMatches,
      unreadMessages: unreadMessages,
      urgentJobs: urgentOpenJobs,
    );

    return EmployerDashboardData(
      businessName: _readString(profile?['businessName']) ?? 'your business',
      stats: stats,
      attentionItems: attentionItems,
      recentApplications: recentApplications
          .take(3)
          .map((application) => application.toRecentApplication())
          .toList(),
      activeJobs: activeJobs
          .take(3)
          .map(
            (job) => job.toActiveJob(
              applicationsCount: applicationsByJobId[job.id] ?? 0,
            ),
          )
          .toList(),
      isNewEmployer:
          jobs.isEmpty &&
          applications.isEmpty &&
          activeMatches == 0 &&
          chats.isEmpty,
    );
  }
}

class EmployerDashboardStats {
  const EmployerDashboardStats({
    required this.activeJobs,
    required this.pendingApplications,
    required this.activeMatches,
    required this.unreadMessages,
    required this.urgentJobs,
  });

  final int activeJobs;
  final int pendingApplications;
  final int activeMatches;
  final int unreadMessages;
  final int urgentJobs;
}

enum EmployerAttentionType { applications, messages, urgentJobs }

class EmployerAttentionItem {
  const EmployerAttentionItem({
    required this.type,
    required this.count,
    required this.title,
  });

  final EmployerAttentionType type;
  final int count;
  final String title;
}

class EmployerRecentApplication {
  const EmployerRecentApplication({
    required this.id,
    required this.employeeName,
    this.employeeImageUrl,
    required this.jobTitle,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String employeeName;
  final String? employeeImageUrl;
  final String jobTitle;
  final String status;
  final DateTime? createdAt;
}

class EmployerActiveJob {
  const EmployerActiveJob({
    required this.id,
    required this.title,
    this.date,
    this.shiftStart,
    this.shiftEnd,
    required this.applicationsCount,
    required this.urgent,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? date;
  final String? shiftStart;
  final String? shiftEnd;
  final int applicationsCount;
  final bool urgent;
  final String? imageUrl;
}

class _JobRecord {
  const _JobRecord({
    required this.id,
    required this.title,
    this.date,
    this.shiftStart,
    this.shiftEnd,
    required this.status,
    required this.isActiveFlag,
    required this.urgent,
    required this.createdAtMillis,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String? date;
  final String? shiftStart;
  final String? shiftEnd;
  final String? status;
  final bool isActiveFlag;
  final bool urgent;
  final int createdAtMillis;
  final String? imageUrl;

  bool get isActive => status == 'open' || isActiveFlag;

  factory _JobRecord.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _JobRecord(
      id: doc.id,
      title: _readString(data['title']) ?? 'Open job',
      date: _readJobDate(data),
      shiftStart:
          _readFirstShiftValue(data['shifts'], 'startTime') ??
          _readString(data['shiftStart']),
      shiftEnd:
          _readFirstShiftValue(data['shifts'], 'endTime') ??
          _readString(data['shiftEnd']),
      status: _readString(data['status']),
      isActiveFlag: data['isActive'] == true,
      urgent: data['urgent'] == true,
      createdAtMillis: _readTimestampMillis(data['createdAt']),
      imageUrl: _readFirstString(data['imageUrls']),
    );
  }

  EmployerActiveJob toActiveJob({required int applicationsCount}) {
    return EmployerActiveJob(
      id: id,
      title: title,
      date: date,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      applicationsCount: applicationsCount,
      urgent: urgent,
      imageUrl: imageUrl,
    );
  }
}

class _ApplicationRecord {
  const _ApplicationRecord({
    required this.id,
    required this.jobId,
    required this.employeeName,
    this.employeeImageUrl,
    required this.jobTitle,
    required this.status,
    required this.createdAtMillis,
    this.createdAt,
  });

  final String id;
  final String jobId;
  final String employeeName;
  final String? employeeImageUrl;
  final String jobTitle;
  final String status;
  final int createdAtMillis;
  final DateTime? createdAt;

  factory _ApplicationRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    Map<String, dynamic>? candidateProfile,
  }) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return _ApplicationRecord(
      id: doc.id,
      jobId: _readString(data['jobId']) ?? '',
      employeeName:
          _readString(candidateProfile?['name']) ??
          _readString(data['employeeName']) ??
          'Worker',
      employeeImageUrl:
          _readString(candidateProfile?['profileImageUrl']) ??
          _readString(data['employeeImageUrl']),
      jobTitle: _readString(data['jobTitle']) ?? 'Job',
      status: _readString(data['status']) ?? 'pending',
      createdAtMillis: _readTimestampMillis(createdAt),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  EmployerRecentApplication toRecentApplication() {
    return EmployerRecentApplication(
      id: id,
      employeeName: employeeName,
      employeeImageUrl: employeeImageUrl,
      jobTitle: jobTitle,
      status: status,
      createdAt: createdAt,
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

String? _readDate(Object? value) {
  if (value is Timestamp) {
    final date = value.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }
  return _readString(value);
}

String? _readJobDate(Map<String, dynamic> data) {
  if (data['startAsSoonAsPossible'] == true) {
    return 'ASAP';
  }

  final start = data['startDate'];
  final end = data['endDate'];
  if (start is Timestamp && end is Timestamp) {
    return '${_readDate(start)} - ${_readDate(end)}';
  }
  if (start is Timestamp) {
    return _readDate(start);
  }
  return _readDate(data['date']);
}

String? _readFirstShiftValue(Object? value, String key) {
  if (value is! List || value.isEmpty) {
    return null;
  }

  final firstShift = value.first;
  if (firstShift is! Map) {
    return null;
  }

  return _readString(firstShift[key]);
}

int _readTimestampMillis(Object? value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}

Map<String, dynamic> _readMap(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

String? _readFirstString(Object? value) {
  if (value is! List) return null;
  for (final item in value) {
    final text = _readString(item);
    if (text != null) return text;
  }
  return null;
}

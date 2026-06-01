import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApplicationService {
  ApplicationService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _readString(Map<String, dynamic>? data, String key, String fallback) {
    final value = data?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  void _addOptionalField(
    Map<String, dynamic> target,
    String targetKey,
    Map<String, dynamic>? source,
    String sourceKey,
  ) {
    final value = source?[sourceKey];
    if (value != null) {
      target[targetKey] = value;
    }
  }

  Future<String> _resolveEmployeeName(String employeeId) async {
    final profileDoc = await _firestore
        .collection('employeeProfiles')
        .doc(employeeId)
        .get();
    final profileData = profileDoc.data();
    final profileName = profileData?['name'] as String?;

    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }

    final currentUser = _auth.currentUser;
    return currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : 'Worker';
  }

  Future<bool> hasApplied({
    required String jobId,
    required String employeeId,
  }) async {
    final query = await _firestore
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  Future<void> applyToJob({
    required String jobId,
    required String employerId,
    required String jobTitle,
    String? employeeId,
    String? employeeName,
    String message = '',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null && employeeId == null) {
      throw Exception('User not authenticated');
    }

    final applicantId = employeeId ?? currentUser!.uid;
    final applicantName =
        employeeName ?? await _resolveEmployeeName(applicantId);

    if (await hasApplied(jobId: jobId, employeeId: applicantId)) {
      throw Exception('You already applied to this job');
    }

    final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
    final jobData = jobDoc.data();

    if (jobData == null) {
      throw Exception('Job not found');
    }

    if (jobData['status'] != 'open') {
      throw Exception('Cannot apply to a closed job');
    }

    final applicationRef = _firestore.collection('applications').doc();
    final applicationData = {
      'applicationId': applicationRef.id,
      'jobId': jobId,
      'employerId': employerId,
      'employeeId': applicantId,
      'jobTitle': jobTitle,
      'employeeName': applicantName,
      'status': 'pending',
      'message': message.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await applicationRef.set(applicationData);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getEmployeeApplications(
    String employeeId,
  ) {
    return _firestore
        .collection('applications')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getApplicationsForEmployer(
    String employerId,
  ) {
    return _firestore
        .collection('applications')
        .where('employerId', isEqualTo: employerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getApplicationsForEmployerJob({
    required String employerId,
    required String jobId,
  }) {
    return _firestore
        .collection('applications')
        .where('employerId', isEqualTo: employerId)
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<List<EmployerApplicationItem>> watchEmployerApplications({
    String? jobId,
  }) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(const []);
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection('applications')
        .where('employerId', isEqualTo: currentUser.uid);

    final trimmedJobId = jobId?.trim();
    if (trimmedJobId != null && trimmedJobId.isNotEmpty) {
      query = query.where('jobId', isEqualTo: trimmedJobId);
    }

    return query.orderBy('createdAt', descending: true).snapshots().asyncMap((
      snapshot,
    ) async {
      final items = await Future.wait(
        snapshot.docs.map(_buildEmployerApplicationItem),
      );
      return items;
    });
  }

  Future<EmployerApplicationDetails> getApplicationDetails(
    String applicationId,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final applicationDoc = await _firestore
        .collection('applications')
        .doc(applicationId)
        .get();
    final applicationData = applicationDoc.data();
    if (!applicationDoc.exists || applicationData == null) {
      throw Exception('Application not found');
    }

    final employerId = _readText(applicationData['employerId']);
    if (employerId != currentUser.uid) {
      throw Exception('You can only view applications for your own jobs');
    }

    final item = await _buildEmployerApplicationItemFromDoc(applicationDoc);
    return EmployerApplicationDetails(item: item);
  }

  Future<void> approveApplication(String applicationId) {
    return updateApplicationStatus(
      applicationId: applicationId,
      status: 'approved',
    );
  }

  Future<void> rejectApplication(String applicationId) {
    return updateApplicationStatus(
      applicationId: applicationId,
      status: 'rejected',
    );
  }

  Future<EmployerApplicationItem> _buildEmployerApplicationItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    return _buildEmployerApplicationFromSnapshot(doc.id, doc.data());
  }

  Future<EmployerApplicationItem> _buildEmployerApplicationFromSnapshot(
    String applicationId,
    Map<String, dynamic> applicationData,
  ) async {
    final employeeId = _readText(applicationData['employeeId']);
    final jobId = _readText(applicationData['jobId']);

    final profileFuture = employeeId == null
        ? Future<DocumentSnapshot<Map<String, dynamic>>?>.value()
        : _firestore.collection('employeeProfiles').doc(employeeId).get();
    final jobFuture = jobId == null
        ? Future<DocumentSnapshot<Map<String, dynamic>>?>.value()
        : _firestore.collection('jobs').doc(jobId).get();

    final results = await Future.wait([profileFuture, jobFuture]);
    final profileDoc = results[0];
    final jobDoc = results[1];

    return EmployerApplicationItem.fromData(
      applicationId: applicationId,
      applicationData: applicationData,
      employeeId: employeeId ?? '',
      employeeProfileData: profileDoc?.data(),
      jobId: jobId ?? '',
      jobData: jobDoc?.data(),
    );
  }

  Future<EmployerApplicationItem> _buildEmployerApplicationItemFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    return _buildEmployerApplicationFromSnapshot(doc.id, doc.data() ?? {});
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final allowedStatuses = {'pending', 'approved', 'rejected'};
    if (!allowedStatuses.contains(status)) {
      throw Exception('Invalid application status');
    }

    final applicationRef = _firestore
        .collection('applications')
        .doc(applicationId);

    await _firestore.runTransaction((transaction) async {
      final applicationDoc = await transaction.get(applicationRef);

      if (!applicationDoc.exists) {
        throw Exception('Application not found');
      }

      final applicationData = applicationDoc.data();
      if (applicationData == null) {
        throw Exception('Application data is unavailable');
      }

      final employerId = applicationData['employerId'] as String?;
      if (employerId != currentUser.uid) {
        throw Exception('You can only update applications for your own jobs');
      }

      if (status == 'rejected') {
        transaction.update(applicationRef, {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      if (status == 'pending') {
        transaction.update(applicationRef, {
          'status': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final existingMatchId = applicationData['matchId'] as String?;
      final existingChatId = applicationData['chatId'] as String?;
      if (existingMatchId?.trim().isNotEmpty == true &&
          existingChatId?.trim().isNotEmpty == true) {
        transaction.update(applicationRef, {
          'status': 'approved',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final jobId = applicationData['jobId'] as String?;
      final employeeId = applicationData['employeeId'] as String?;
      if (jobId == null || jobId.trim().isEmpty) {
        throw Exception('Application job is missing');
      }
      if (employeeId == null || employeeId.trim().isEmpty) {
        throw Exception('Application employee is missing');
      }

      final jobRef = _firestore.collection('jobs').doc(jobId);
      final employeeProfileRef = _firestore
          .collection('employeeProfiles')
          .doc(employeeId);
      final employerProfileRef = _firestore
          .collection('employerProfiles')
          .doc(employerId);

      final jobDoc = await transaction.get(jobRef);
      final employeeProfileDoc = await transaction.get(employeeProfileRef);
      final employerProfileDoc = await transaction.get(employerProfileRef);

      final jobData = jobDoc.data();
      final employeeProfileData = employeeProfileDoc.data();
      final employerProfileData = employerProfileDoc.data();

      final employeeName = _readString(
        applicationData,
        'employeeName',
        _readString(employeeProfileData, 'name', 'Worker'),
      );
      final employeeImageUrl = _readString(
        employeeProfileData,
        'profileImageUrl',
        '',
      );
      final employerName = _readString(
        employerProfileData,
        'businessName',
        'Business',
      );
      final employerImageUrl = _readString(
        employerProfileData,
        'businessLogoUrl',
        '',
      );
      final jobTitle = _readString(
        applicationData,
        'jobTitle',
        _readString(jobData, 'title', _readString(jobData, 'jobTitle', 'Job')),
      );

      final matchRef = _firestore.collection('matches').doc();
      final chatRef = _firestore.collection('chats').doc();

      final matchData = <String, dynamic>{
        'matchId': matchRef.id,
        'applicationId': applicationId,
        'jobId': jobId,
        'employeeId': employeeId,
        'employerId': employerId,
        'employeeName': employeeName,
        'employeeImageUrl': employeeImageUrl,
        'employerName': employerName,
        'employerImageUrl': employerImageUrl,
        'jobTitle': jobTitle,
        'chatId': chatRef.id,
        'status': 'active',
        'seenByEmployee': false,
        'seenByEmployeeAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      _addOptionalField(matchData, 'jobLocation', jobData, 'location');
      _addOptionalField(matchData, 'workDate', jobData, 'workDate');
      _addOptionalField(matchData, 'salaryAmount', jobData, 'salaryAmount');
      _addOptionalField(matchData, 'paymentType', jobData, 'paymentType');

      final chatData = <String, dynamic>{
        'chatId': chatRef.id,
        'matchId': matchRef.id,
        'applicationId': applicationId,
        'jobId': jobId,
        'employeeId': employeeId,
        'employerId': employerId,
        'participants': [employeeId, employerId],
        'participantNames': {
          employeeId: employeeName,
          employerId: employerName,
        },
        'participantImages': {
          employeeId: employeeImageUrl,
          employerId: employerImageUrl,
        },
        'jobTitle': jobTitle,
        'lastMessage': '',
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'unreadCounts': {employeeId: 0, employerId: 0},
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      transaction.update(applicationRef, {
        'status': 'approved',
        'matchId': matchRef.id,
        'chatId': chatRef.id,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(matchRef, matchData);
      transaction.set(chatRef, chatData);
    });
  }
}

class EmployerApplicationDetails {
  const EmployerApplicationDetails({required this.item});

  final EmployerApplicationItem item;
}

class EmployerApplicationItem {
  const EmployerApplicationItem({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.message,
    required this.chatId,
    required this.matchId,
    required this.candidate,
    required this.job,
  });

  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? message;
  final String? chatId;
  final String? matchId;
  final CandidateProfileSummary candidate;
  final JobSummaryForApplication job;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory EmployerApplicationItem.fromData({
    required String applicationId,
    required Map<String, dynamic> applicationData,
    required String employeeId,
    required Map<String, dynamic>? employeeProfileData,
    required String jobId,
    required Map<String, dynamic>? jobData,
  }) {
    return EmployerApplicationItem(
      id: applicationId,
      status: _readText(applicationData['status']) ?? 'pending',
      createdAt: _readDateTime(applicationData['createdAt']),
      updatedAt: _readDateTime(applicationData['updatedAt']),
      message: _readText(applicationData['message']),
      chatId: _readText(applicationData['chatId']),
      matchId: _readText(applicationData['matchId']),
      candidate: CandidateProfileSummary.fromData(
        employeeId: employeeId,
        fallbackName: _readText(applicationData['employeeName']),
        data: employeeProfileData,
      ),
      job: JobSummaryForApplication.fromData(
        jobId: jobId,
        fallbackTitle: _readText(applicationData['jobTitle']),
        data: jobData,
      ),
    );
  }
}

class CandidateProfileSummary {
  const CandidateProfileSummary({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.ageRange,
    required this.city,
    required this.locationLabel,
    required this.skills,
    required this.jobCategories,
    required this.preferredRoles,
    required this.experienceLevel,
    required this.salaryExpectation,
    required this.preferredJobTypes,
    required this.availableDays,
    required this.preferredShiftTypes,
    required this.availableNow,
    required this.canWorkToday,
    required this.canWorkShortNotice,
    required this.shortBio,
    required this.pastExperiences,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final String? ageRange;
  final String? city;
  final String? locationLabel;
  final List<String> skills;
  final List<String> jobCategories;
  final List<String> preferredRoles;
  final String? experienceLevel;
  final String? salaryExpectation;
  final List<String> preferredJobTypes;
  final List<String> availableDays;
  final List<String> preferredShiftTypes;
  final bool availableNow;
  final bool canWorkToday;
  final bool canWorkShortNotice;
  final String? shortBio;
  final List<CandidateExperience> pastExperiences;

  String get availabilityLabel {
    if (availableNow) return 'Available now';
    if (canWorkToday) return 'Available today';
    if (canWorkShortNotice) return 'Short notice';
    if (availableDays.isNotEmpty) return availableDays.take(3).join(', ');
    return 'Availability not set';
  }

  String get experienceLabel {
    if (experienceLevel != null) return experienceLevel!;
    if (pastExperiences.isEmpty) return 'Not specified';
    if (pastExperiences.length == 1) return '1 past role';
    return '${pastExperiences.length} past roles';
  }

  factory CandidateProfileSummary.fromData({
    required String employeeId,
    required String? fallbackName,
    required Map<String, dynamic>? data,
  }) {
    return CandidateProfileSummary(
      id: employeeId,
      name: _readText(data?['name']) ?? fallbackName ?? 'Worker',
      imageUrl: _readText(data?['profileImageUrl']),
      ageRange: _readText(data?['ageRange']),
      city:
          _readText(data?['city']) ??
          _readText(
            (data?['location'] is Map) ? data!['location']['city'] : null,
          ),
      locationLabel:
          _readLocation(data?['location']) ?? _readText(data?['city']),
      skills: _readStringList(data?['skills']),
      jobCategories: _readStringList(data?['jobCategories']),
      preferredRoles: _readStringList(data?['preferredRoles']),
      experienceLevel: _readText(data?['experienceLevel']),
      salaryExpectation: _readSalaryExpectation(data?['salaryExpectation']),
      preferredJobTypes: _readStringList(data?['preferredJobTypes']),
      availableDays: _readStringList(data?['availableDays']),
      preferredShiftTypes: _readStringList(data?['preferredShiftTypes']),
      availableNow:
          data?['availableNow'] == true || data?['isAvailableNow'] == true,
      canWorkToday: data?['canWorkToday'] == true,
      canWorkShortNotice:
          data?['canWorkShortNotice'] == true ||
          data?['canWorkOnShortNotice'] == true,
      shortBio: _readText(data?['shortBio']),
      pastExperiences: _readExperiences(
        data?['pastWorkExperience'] ?? data?['pastExperiences'],
      ),
    );
  }
}

class JobSummaryForApplication {
  const JobSummaryForApplication({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.salaryText,
    required this.locationText,
    required this.status,
    required this.visibility,
  });

  final String id;
  final String title;
  final String? category;
  final String? imageUrl;
  final String? salaryText;
  final String? locationText;
  final String? status;
  final String? visibility;

  factory JobSummaryForApplication.fromData({
    required String jobId,
    required String? fallbackTitle,
    required Map<String, dynamic>? data,
  }) {
    final salaryAmount = _readDouble(data?['salaryAmount'] ?? data?['salary']);
    final salaryType = _readText(data?['salaryType']);
    return JobSummaryForApplication(
      id: jobId,
      title:
          _readText(data?['title']) ??
          _readText(data?['jobTitle']) ??
          fallbackTitle ??
          'Job',
      category: _readText(data?['jobCategory']),
      imageUrl: _readFirstString(data?['imageUrls']),
      salaryText: salaryAmount == null
          ? null
          : '${_formatCurrency(salaryAmount)}${_salarySuffix(salaryType)}',
      locationText: _readLocation(data?['location']),
      status: _readText(data?['status']),
      visibility: _readText(data?['visibility']),
    );
  }
}

class CandidateExperience {
  const CandidateExperience({
    required this.role,
    required this.workplace,
    required this.duration,
    required this.description,
  });

  final String? role;
  final String? workplace;
  final String? duration;
  final String? description;

  String get title => role ?? 'Past role';
}

String? _readText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _readFirstString(Object? value) {
  if (value is List) {
    for (final item in value) {
      final text = _readText(item);
      if (text != null) return text;
    }
  }
  return _readText(value);
}

String? _readLocation(Object? value) {
  if (value is String) return _readText(value);
  if (value is Map) {
    if (value['type'] == 'remote') return 'Remote';
    final parts = [
      _readText(value['address']),
      _readText(value['city']),
    ].whereType<String>().toList();
    if (parts.isNotEmpty) return parts.join(', ');
  }
  return null;
}

String? _readSalaryExpectation(Object? value) {
  if (value == null) return null;
  if (value is num) return '${_formatCurrency(value.toDouble())} / hour';
  return _readText(value);
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String _formatCurrency(double amount) {
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(1);
  return '₪$formatted';
}

String _salarySuffix(String? salaryType) {
  return salaryType == 'Hourly'
      ? ' / hour'
      : salaryType == 'Daily'
      ? ' / day'
      : salaryType == null
      ? ''
      : ' $salaryType';
}

List<CandidateExperience> _readExperiences(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) {
    return CandidateExperience(
      role:
          _readText(item['role']) ??
          _readText(item['title']) ??
          _readText(item['jobTitle']),
      workplace:
          _readText(item['workplace']) ??
          _readText(item['company']) ??
          _readText(item['businessName']),
      duration:
          _readText(item['duration']) ??
          _readText(item['timeframe']) ??
          _readText(item['period']),
      description: _readText(item['description']),
    );
  }).toList();
}

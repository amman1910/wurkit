import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MatchService {
  MatchService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUnseenEmployeeMatches() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('matches')
        .where('employeeId', isEqualTo: currentUser.uid)
        .where('status', isEqualTo: 'active')
        .where('seenByEmployee', isEqualTo: false)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getMatchCelebrationData(String matchId) async {
    final matchDoc = await _firestore.collection('matches').doc(matchId).get();
    final matchData = matchDoc.data();
    if (!matchDoc.exists || matchData == null) {
      return null;
    }

    final jobId = _readString(matchData['jobId']);
    final employerId = _readString(matchData['employerId']);

    final jobDoc = jobId == null
        ? null
        : await _firestore.collection('jobs').doc(jobId).get();
    final employerDoc = employerId == null
        ? null
        : await _firestore.collection('employerProfiles').doc(employerId).get();

    final jobData = jobDoc?.data();
    final employerData = employerDoc?.data();

    return <String, dynamic>{
      'matchId': matchId,
      'jobId': jobId,
      'chatId': _readString(matchData['chatId']),
      'employerId': employerId,
      'businessName':
          _readString(employerData?['businessName']) ??
          _readString(matchData['employerName']) ??
          'Business',
      'businessLogoUrl':
          _readString(employerData?['businessLogoUrl']) ??
          _readString(matchData['employerImageUrl']),
      'city': _readString(employerData?['city']),
      'businessAddress': _readString(employerData?['businessAddress']),
      'businessType': _readString(employerData?['businessType']),
      'jobTitle':
          _readString(jobData?['title']) ??
          _readString(jobData?['jobTitle']) ??
          _readString(matchData['jobTitle']) ??
          'Job',
      'date':
          _readDate(jobData?['date']) ??
          _readDate(jobData?['workDate']) ??
          _readDate(matchData['workDate']),
      'shiftStart': _readString(jobData?['shiftStart']),
      'shiftEnd': _readString(jobData?['shiftEnd']),
      'location':
          _readString(jobData?['location']) ??
          _readString(matchData['jobLocation']) ??
          _readString(employerData?['city']) ??
          _readString(employerData?['businessAddress']),
    };
  }

  Future<void> markMatchSeen(String matchId) async {
    await _firestore.collection('matches').doc(matchId).set({
      'seenByEmployee': true,
      'seenByEmployeeAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
}

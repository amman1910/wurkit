import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class JobService {
  JobService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Creates a new job document in Firestore
  Future<void> createJob({
    required String title,
    required String description,
    required String location,
    required DateTime date,
    required double salary,
    required String salaryType,
    required String requiredSkill,
    required TimeOfDay shiftStart,
    required TimeOfDay shiftEnd,
    required bool urgent,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final jobData = {
      'employerId': currentUser.uid,
      'title': title,
      'description': description,
      'location': location,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD format
      'salary': salary,
      'salaryType': salaryType,
      'requiredSkill': requiredSkill,
      'shiftStart':
          '${shiftStart.hour.toString().padLeft(2, '0')}:${shiftStart.minute.toString().padLeft(2, '0')}',
      'shiftEnd':
          '${shiftEnd.hour.toString().padLeft(2, '0')}:${shiftEnd.minute.toString().padLeft(2, '0')}',
      'urgent': urgent,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('jobs').add(jobData);
  }

  /// Stream of open jobs sorted by createdAt descending
  Stream<QuerySnapshot> getOpenJobs() {
    return _firestore
        .collection('jobs')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}

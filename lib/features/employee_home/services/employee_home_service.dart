import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class EmployeeHomeService {
  EmployeeHomeService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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

    await _firestore.collection('employeeProfiles').doc(user.uid).set({
      'locationPermissionGranted': true,
      'location': {'lat': position.latitude, 'lng': position.longitude},
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
}

class EmployeeHomeProfile {
  const EmployeeHomeProfile({
    required this.uid,
    this.name,
    this.profileImageUrl,
    required this.isAvailableNow,
    required this.locationPermissionGranted,
  });

  final String uid;
  final String? name;
  final String? profileImageUrl;
  final bool isAvailableNow;
  final bool locationPermissionGranted;

  factory EmployeeHomeProfile.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
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
  });

  final String id;
  final String employerId;
  final String title;
  final String? description;
  final String? location;
  final double? salary;
  final String? salaryType;
  final bool urgent;

  factory EmployeeHomeJob.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return EmployeeHomeJob(
      id: id,
      employerId: _readString(data['employerId']) ?? '',
      title: _readString(data['title']) ?? 'Open shift',
      description: _readString(data['description']),
      location: _readString(data['location']),
      salary: _readDouble(data['salary']),
      salaryType: _readString(data['salaryType']),
      urgent: _readBool(data['urgent']) ?? false,
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

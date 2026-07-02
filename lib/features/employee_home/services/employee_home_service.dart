import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/utils/address_format_utils.dart';
import '../../../shared/services/google_places_service.dart';

class EmployeeHomeService {
  EmployeeHomeService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googlePlacesService = GooglePlacesService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
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

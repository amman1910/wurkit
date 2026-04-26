import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class EmployerProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveBusinessInfo({
    required String businessName,
    required String businessType,
    required String businessPhone,
    String? businessEmail,
    String? businessDescription,
    String? businessLogoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();
    final employerDoc = _firestore.collection('employerProfiles').doc(uid);
    final snapshot = await employerDoc.get();

    final employerData = <String, dynamic>{
      'uid': uid,
      'businessName': businessName,
      'businessType': businessType,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'businessDescription': businessDescription,
      'businessLogoUrl': businessLogoUrl,
      'updatedAt': now,
    };

    if (!snapshot.exists) {
      employerData['createdAt'] = now;
    }

    await employerDoc.set(employerData, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set(
      {
        'role': 'employer',
        'onboardingStep': 'business_info',
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveBusinessLocation({
    required String businessAddress,
    required String city,
    required bool isPhysicalBusiness,
    required bool locationPermissionGranted,
    double? latitude,
    double? longitude,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();

    // Prepare location data
    Map<String, dynamic> updateData = {
      'businessAddress': businessAddress,
      'city': city,
      'isPhysicalBusiness': isPhysicalBusiness,
      'locationPermissionGranted': locationPermissionGranted,
      'updatedAt': now,
    };

    // Add location coordinates if available
    if (latitude != null && longitude != null) {
      updateData['location'] = {
        'lat': latitude,
        'lng': longitude,
      };
    }

    // Save to employerProfiles/{uid}
    await _firestore.collection('employerProfiles').doc(uid).set(
      updateData,
      SetOptions(merge: true),
    );

    // Update users/{uid}
    await _firestore.collection('users').doc(uid).set({
      'onboardingStep': 'business_location',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<LocationPermission> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services to continue.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied. Please grant location permission to continue.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable location permission in app settings.');
    }

    return permission;
  }

  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  Future<void> saveHiringPreferences({
    required List<String> hiringCategories,
    required List<String> requiredSkills,
    required List<String> typicalShiftTypes,
    required bool urgentHiringEnabled,
    required bool usuallyNeedsShortNoticeWorkers,
    required double defaultHourlyRateMin,
    required double defaultHourlyRateMax,
    required String preferredExperienceLevel,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();

    // Prepare hiring preferences data
    Map<String, dynamic> updateData = {
      'hiringCategories': hiringCategories,
      'requiredSkills': requiredSkills,
      'typicalShiftTypes': typicalShiftTypes,
      'urgentHiringEnabled': urgentHiringEnabled,
      'usuallyNeedsShortNoticeWorkers': usuallyNeedsShortNoticeWorkers,
      'defaultHourlyRateMin': defaultHourlyRateMin,
      'defaultHourlyRateMax': defaultHourlyRateMax,
      'preferredExperienceLevel': preferredExperienceLevel,
      'updatedAt': now,
    };

    // Save to employerProfiles/{uid}
    await _firestore.collection('employerProfiles').doc(uid).set(
      updateData,
      SetOptions(merge: true),
    );

    // Update users/{uid}
    await _firestore.collection('users').doc(uid).set({
      'onboardingStep': 'hiring_preferences',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getEmployerProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final snapshot = await _firestore.collection('employerProfiles').doc(user.uid).get();
    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  Future<void> completeEmployerProfile({
    String? publicBusinessNote,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();
    final employerData = <String, dynamic>{
      'profileCompletedAt': now,
      'updatedAt': now,
    };

    final trimmedNote = publicBusinessNote?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      employerData['publicBusinessNote'] = trimmedNote;
    }

    await _firestore.collection('employerProfiles').doc(uid).set(
      employerData,
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(uid).set(
      {
        'role': 'employer',
        'profileCompleted': true,
        'onboardingStep': 'completed',
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }
}

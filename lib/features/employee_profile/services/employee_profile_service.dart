import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

class EmployeeProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> saveBasicInfo({
    required String name,
    required String phoneNumber,
    String? ageRange,
    String? profileImageUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();

    // Build the data map - only include profileImageUrl if provided
    final Map<String, dynamic> data = {
      'uid': uid,
      'name': name,
      'phoneNumber': phoneNumber,
      'ageRange': ageRange,
      'updatedAt': now,
      'createdAt': now,
    };

    // Only add profileImageUrl if it's provided and not empty
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      data['profileImageUrl'] = profileImageUrl;
    }

    // Save to employeeProfiles/{uid}
    await _firestore.collection('employeeProfiles').doc(uid).set(
      data,
      SetOptions(merge: true),
    );

    // Update users/{uid}
    await _firestore.collection('users').doc(uid).set({
      'role': 'employee',
      'onboardingStep': 'basic_info',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> saveWorkPreferences({
    required List<String> jobCategories,
    required List<String> preferredRoles,
    required List<String> skills,
    String? experienceLevel,
    required double salaryExpectation,
    required List<String> preferredJobTypes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();

    // Prepare update data
    Map<String, dynamic> updateData = {
      'jobCategories': jobCategories,
      'preferredRoles': preferredRoles,
      'skills': skills,
      'salaryExpectation': salaryExpectation,
      'preferredJobTypes': preferredJobTypes,
      'updatedAt': now,
    };

    if (experienceLevel != null) {
      updateData['experienceLevel'] = experienceLevel;
    }

    // Save to employeeProfiles/{uid}
    await _firestore.collection('employeeProfiles').doc(uid).set(
      updateData,
      SetOptions(merge: true),
    );

    // Update users/{uid}
    await _firestore.collection('users').doc(uid).set({
      'onboardingStep': 'work_preferences',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Requests location permission and returns the result
  Future<LocationPermission> requestLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services to continue.');
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Request permission
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

  /// Gets the current position with reasonable accuracy
  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Saves location data to Firestore
  Future<void> saveLocationData({
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

    // Save to employeeProfiles/{uid}
    await _firestore.collection('employeeProfiles').doc(uid).set(
      updateData,
      SetOptions(merge: true),
    );

    // Update users/{uid}
    await _firestore.collection('users').doc(uid).set({
      'onboardingStep': 'availability_location',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Convenience method to handle the complete location setup flow
  Future<void> setupAndSaveLocation() async {
    try {
      // Request permission
      final permission = await requestLocationPermission();

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // Permission granted, get current position
        final position = await getCurrentPosition();

        // Save with coordinates
        await saveLocationData(
          locationPermissionGranted: true,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        // Permission not granted
        await saveLocationData(
          locationPermissionGranted: false,
          latitude: null,
          longitude: null,
        );
      }
    } catch (e) {
      // Handle location services disabled or permission denied
      await saveLocationData(
        locationPermissionGranted: false,
        latitude: null,
        longitude: null,
      );
      rethrow;
    }
  }

  Future<void> saveAvailabilityAndLocation({
    required bool locationPermissionGranted,
    double? latitude,
    double? longitude,
    required double preferredWorkRadiusKm,
    required bool isAvailableNow,
    required List<String> availableDays,
    required List<String> preferredShiftTypes,
    required bool canWorkShortNotice,
    required bool canWorkToday,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();

    // Prepare update data
    Map<String, dynamic> updateData = {
      'locationPermissionGranted': locationPermissionGranted,
      'preferredWorkRadiusKm': preferredWorkRadiusKm,
      'availableNow': isAvailableNow,
      'isAvailableNow': isAvailableNow,
      'availableDays': availableDays,
      'preferredShiftTypes': preferredShiftTypes,
      'canWorkOnShortNotice': canWorkShortNotice,
      'canWorkShortNotice': canWorkShortNotice,
      'canWorkToday': canWorkToday,
      'updatedAt': now,
    };

    // Add location coordinates if available
    if (latitude != null && longitude != null) {
      updateData['location'] = {
        'lat': latitude,
        'lng': longitude,
      };
    }

    // Save to employeeProfiles/{uid}
    await _firestore.collection('employeeProfiles').doc(uid).set(
      updateData,
      SetOptions(merge: true),
    );

    // Update users/{uid}
    await _firestore.collection('users').doc(uid).set({
      'onboardingStep': 'availability_location',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> saveExperienceAndSummary({
    String? shortBio,
    required List<Map<String, dynamic>> pastExperiences,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final now = FieldValue.serverTimestamp();

    // Prepare update data for employeeProfiles
    Map<String, dynamic> profileUpdateData = {
      'updatedAt': now,
    };

    if (shortBio != null && shortBio.isNotEmpty) {
      profileUpdateData['shortBio'] = shortBio;
    }

    profileUpdateData['pastWorkExperience'] = pastExperiences;
    profileUpdateData['pastExperiences'] = pastExperiences;

    // Save to employeeProfiles/{uid}
    await _firestore.collection('employeeProfiles').doc(uid).set(
      profileUpdateData,
      SetOptions(merge: true),
    );

    // Update users/{uid} - mark onboarding as complete
    await _firestore.collection('users').doc(uid).set({
      'profileCompleted': true,
      'onboardingStep': 'completed',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Streams the current authenticated employee profile from Firestore.
  /// Returns a Stream that emits the profile data as Map<String, dynamic>
  /// If no user is logged in, throws an error.
  /// The uid is included in the returned map.
  Stream<Map<String, dynamic>?> watchCurrentEmployeeProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.error(Exception('No authenticated user found'));
    }

    final uid = user.uid;
    return _firestore
        .collection('employeeProfiles')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }
          final data = snapshot.data() ?? {};
          // Ensure uid is included
          data['uid'] = uid;
          return data;
        });
  }

  /// Gets the current authenticated employee profile from Firestore.
  /// Returns a Future that resolves to the profile data as Map<String, dynamic>
  /// If no user is logged in or profile doesn't exist, returns null.
  Future<Map<String, dynamic>?> getCurrentEmployeeProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final uid = user.uid;
    final snapshot = await _firestore
        .collection('employeeProfiles')
        .doc(uid)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data() ?? {};
    data['uid'] = uid;
    return data;
  }

  /// Uploads a profile image to Firebase Storage and returns the download URL.
  /// The image is stored at: employee_profile_images/{uid}/profile.jpg
  /// If the image already exists at this path, it will be replaced.
  Future<String> uploadEmployeeProfileImage({
    required File imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final uid = user.uid;
    final ref = _storage.ref().child('employee_profile_images/$uid/profile.jpg');

    // Upload the file
    final uploadTask = await ref.putFile(imageFile);

    // Get the download URL
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return downloadUrl;
  }
}

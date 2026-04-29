import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum PostLoginNavigationState {
  completed,
  chooseRole,
  employeeBasicInfo,
  employeeWorkPreferences,
  employeeAvailabilityLocation,
  employeeExperienceSummary,
  employerBusinessInfo,
  employerBusinessLocation,
  employerHiringPreferences,
  employerProfileSummary,
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  /// Stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed in user
  User? get currentUser => _auth.currentUser;

  /// Register with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _createUserDocumentIfNeeded(
        firebaseUser: credential.user,
        authProvider: 'email',
      );

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Unexpected error during email sign up: $e');
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _createUserDocumentIfNeeded(
        firebaseUser: credential.user,
        authProvider: 'email',
      );

      await _updateLastLogin(credential.user);

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Unexpected error during email sign in: $e');
    }
  }

  /// Sign in / sign up with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled the flow
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      await _createUserDocumentIfNeeded(
        firebaseUser: userCredential.user,
        authProvider: 'google',
      );

      await _updateLastLogin(userCredential.user);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Unexpected error during Google sign in: $e');
    }
  }

  /// Sign out from Firebase and Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore Google sign-out errors so Firebase sign-out still happens
    }

    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Unexpected error sending reset email: $e');
    }
  }

  /// Create minimal users/{uid} document only if it does not exist
  Future<void> _createUserDocumentIfNeeded({
    required User? firebaseUser,
    required String authProvider,
  }) async {
    if (firebaseUser == null) {
      throw Exception('User is null after authentication.');
    }

    final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);
    final docSnapshot = await userDocRef.get();

    if (!docSnapshot.exists) {
      await userDocRef.set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email,
        'authProvider': authProvider,
        'role': null,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Update last login timestamp for existing users
  Future<void> _updateLastLogin(User? firebaseUser) async {
    if (firebaseUser == null) return;

    final userDocRef = _firestore.collection('users').doc(firebaseUser.uid);

    await userDocRef.set({
      'lastLoginAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update the current user's role
  Future<void> setUserRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update the current user's role with merge-safe behavior
  Future<void> updateUserRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Get the current user's document
  Future<DocumentSnapshot<Map<String, dynamic>>> getCurrentUserDoc() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    return await _firestore.collection('users').doc(user.uid).get();
  }

  Future<String?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    return data?['role'] as String?;
  }

  /// Determine the next navigation state after login
  Future<PostLoginNavigationState> getPostLoginNavigationState() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final userDocRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userDocRef.get();

    if (!userDoc.exists) {
      return PostLoginNavigationState.chooseRole;
    }

    final data = userDoc.data();
    final profileCompleted = data?['profileCompleted'] == true;
    final role = data?['role'] as String?;

    if (profileCompleted) {
      return PostLoginNavigationState.completed;
    }

    if (role == null || role.isEmpty) {
      return PostLoginNavigationState.chooseRole;
    }

    if (role == 'employee') {
      final profileDoc = await _firestore.collection('employeeProfiles').doc(user.uid).get();

      if (!profileDoc.exists) {
        return PostLoginNavigationState.employeeBasicInfo;
      }

      final profileData = profileDoc.data();
      final name = profileData?['name'] as String?;
      final salaryExpectation = profileData?['salaryExpectation'];
      final preferredWorkRadiusKm = profileData?['preferredWorkRadiusKm'];

      if (name == null || name.trim().isEmpty) {
        return PostLoginNavigationState.employeeBasicInfo;
      }

      if (salaryExpectation == null) {
        return PostLoginNavigationState.employeeWorkPreferences;
      }

      if (preferredWorkRadiusKm == null) {
        return PostLoginNavigationState.employeeAvailabilityLocation;
      }

      // All fields exist but profileCompleted is false
      return PostLoginNavigationState.employeeExperienceSummary;
    }

    if (role == 'employer') {
      final onboardingStep = data?['onboardingStep'] as String?;

      if (onboardingStep == null || onboardingStep.isEmpty) {
        return PostLoginNavigationState.employerBusinessInfo;
      }

      switch (onboardingStep) {
        case 'business_info':
          return PostLoginNavigationState.employerBusinessLocation;
        case 'business_location':
          return PostLoginNavigationState.employerHiringPreferences;
        case 'hiring_preferences':
          return PostLoginNavigationState.employerProfileSummary;
        case 'completed':
          return PostLoginNavigationState.completed;
        default:
          return PostLoginNavigationState.employerBusinessInfo;
      }
    }

    return PostLoginNavigationState.chooseRole;
  }

  /// Send email verification to the current user
  Future<void> sendCurrentUserEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    await user.sendEmailVerification();
  }

  /// Reload current user and check if email is verified
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    await user.reload();
    final reloadedUser = _auth.currentUser;
    return reloadedUser?.emailVerified ?? false;
  }

  /// Map Firebase errors to cleaner user-facing messages
  Exception _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return Exception('This email is already in use.');
      case 'invalid-email':
        return Exception('The email address is invalid.');
      case 'weak-password':
        return Exception('The password is too weak.');
      case 'user-not-found':
        return Exception('No user found for this email.');
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('Email or password is incorrect.');
      case 'user-disabled':
        return Exception('This user account has been disabled.');
      case 'network-request-failed':
        return Exception('Network error. Please check your connection.');
      case 'account-exists-with-different-credential':
        return Exception(
          'An account already exists with a different sign-in method.',
        );
      case 'popup-closed-by-user':
        return Exception('Google sign in was cancelled.');
      default:
        return Exception(e.message ?? 'Authentication error occurred.');
    }
  }
}

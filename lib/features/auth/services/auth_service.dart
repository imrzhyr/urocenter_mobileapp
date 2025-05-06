import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Re-enabled Google Sign In dependency
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Ensure UserCredential is available
import 'package:urocenter/core/utils/logger.dart';

// Mock class for test auth - not to be used in production
class MockUserCredential {
  final String uid;
  final String displayName;
  final String phoneNumber;
  
  MockUserCredential({
    required this.uid,
    required this.displayName,
    required this.phoneNumber,
  });
}

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  // Add other dependencies like Firestore if needed

  AuthService(this._firebaseAuth, this._googleSignIn);
  
  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  
  // Test authentication bypass (for development only)
  Future<MockUserCredential> testSignIn() async {
    try {
      AppLogger.d('Using test authentication bypass');
      
      // Return a mock user for testing
      return MockUserCredential(
        uid: 'test-user-1234',
        displayName: 'Test User',
        phoneNumber: '+9647700000000',
      );
    } catch (e) {
      AppLogger.e('Error with test sign in: $e');
      rethrow;
    }
  }
  
  // Test phone auth bypass (for development only)
  Future<UserCredential> testPhoneSignIn() async {
    try {
      AppLogger.d('Using test phone authentication bypass');
      
      // Just for testing - in a real app you would use signInWithPhoneCredential
      // but we'll simulate its behavior during development
      throw FirebaseAuthException(
        code: 'test-bypass-active',
        message: 'Test authentication. Bypass normal auth flow.'
      );
    } catch (e) {
      AppLogger.e('Test auth exception (expected): ${e}');
      // This will be caught in the sign-in screen and we'll handle navigation there
      throw FirebaseAuthException(
        code: 'test-mode-active',
        message: 'Test mode active - authentication bypassed'
      );
    }
  }
  
  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Re-enabled Google Sign In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _firebaseAuth.signInWithCredential(credential);
      
    } catch (e) {
      AppLogger.e('Error signing in with Google: $e');
      rethrow;
    }
  }
  
  // Phone Authentication - Step 1: Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
    int? forceResendingToken,
  }) async {
    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: timeout,
      forceResendingToken: forceResendingToken,
    );
  }
  
  // Phone Authentication - Step 2: Sign in with phone credential
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      AppLogger.e('Error signing in with phone credential: $e');
      rethrow;
    }
  }
  
  // Phone Authentication - Create credential from verification ID and SMS code
  PhoneAuthCredential createPhoneAuthCredential(String verificationId, String smsCode) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
  
  // Sign in with Email and Password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(), 
        password: password.trim(),
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
       // Rethrow specific exceptions for UI handling
       AppLogger.e('FirebaseAuthException during email/password sign in: ${e.code} - ${e.message}');
       rethrow; 
    } catch (e) {
       AppLogger.e('Generic error during email/password sign in: $e');
       // Rethrow as a generic exception or a FirebaseAuthException
       throw FirebaseAuthException(
          code: 'sign-in-error', 
          message: 'An unexpected error occurred during sign in.', 
       );
    }
  }
  
  // Create User with Email and Password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(), // Trim email
        password: password.trim(), // Trim password
      );
    } on FirebaseAuthException {
      // Let the UI handle specific Firebase exceptions
      rethrow; 
    } catch (e) {
       AppLogger.e("Unexpected error during email/password user creation: $e");
       // Rethrow a generic error or handle appropriately
       rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Re-enabled Google Sign Out
      await _firebaseAuth.signOut();
    } catch (e) {
      AppLogger.e('Error signing out: $e');
      rethrow;
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      await currentUser?.updateProfile(displayName: displayName, photoURL: photoURL);
      // Optionally reload user to get updated info
      await currentUser?.reload();
    } catch (e) {
      AppLogger.e('Error updating user profile: $e');
      rethrow;
    }
  }
} 

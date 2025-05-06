import 'package:firebase_auth/firebase_auth.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Central service for handling verification operations
class VerificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final VerificationService _instance = VerificationService._internal();
  
  factory VerificationService() => _instance;
  
  VerificationService._internal();
  
  /// Verify a phone number and send an OTP
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: timeout,
    );
  }
  
  /// Sign in with phone credential
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    try {
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      AppLogger.e('Error signing in with phone credential: $e');
      rethrow;
    }
  }
  
  /// Create a phone auth credential
  PhoneAuthCredential createPhoneAuthCredential(String verificationId, String smsCode) {
    return PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
  
  /// Process an OTP verification
  Future<bool> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      AppLogger.e('Verification error: $e');
      rethrow;
    }
  }

  /// Check onboarding verification status (simulate actual verification)
  Future<bool> checkOnboardingVerification() async {
    // TODO: Implement actual verification status check with backend
    await Future.delayed(const Duration(seconds: 2));
    return true;
  }
  
  /// Complete onboarding
  Future<bool> completeOnboarding() async {
    // TODO: Implement actual onboarding completion with backend
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
} 

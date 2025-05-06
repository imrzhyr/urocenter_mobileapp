import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/error_handler.dart'; // Assuming error handler exists
import 'package:urocenter/core/utils/logger.dart';

/// Service class for managing user profile data in Firestore.
class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Firestore collection reference
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Saves or updates user profile data in Firestore.
  ///
  /// [userId]: The Firebase Authentication user ID.
  /// [data]: A map containing the profile data fields to save.
  Future<void> saveUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Use userId as the document ID in the 'users' collection
      await _usersCollection.doc(userId).set(
        data,
        SetOptions(merge: true), // Use merge: true to update existing fields without overwriting the entire document
      );
      AppLogger.d('User profile data saved successfully for user: $userId');
    } catch (e) {
      AppLogger.e('Error saving user profile: $e');
      // Rethrow the original exception to be handled by the caller
      rethrow;
    }
  }

  /// Fetches user profile data from Firestore.
  /// Returns null if the user document doesn't exist.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final docSnapshot = await _usersCollection.doc(userId).get();
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>?;
      } else {
        AppLogger.d('User profile document does not exist for user: $userId');
        return null;
      }
    } catch (e) {
      AppLogger.e('Error fetching user profile: $e');
      // Rethrow the original exception to be handled by the caller
      rethrow;
    }
  }

  /// Fetches the profile data for the currently authenticated user.
  /// Returns null if the user is not logged in or the profile doesn't exist.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppLogger.e('Error: No user is currently logged in.');
      return null; // Or throw an exception if this case should be handled differently
    }
    return await getUserProfile(currentUser.uid);
  }

  // TODO: Add other methods as needed (e.g., updateUserField, deleteUserProfile)
}

// Example custom exception (optional, depends on your error handling strategy)
// class AppFirebaseException implements Exception {
//   final String message;
//   final dynamic originalException;
//   AppFirebaseException(this.message, [this.originalException]);
// 
//   @override
//   String toString() {
//     return 'AppFirebaseException: $message ${originalException != null ? "\nOriginal Exception: $originalException" : ""}';
//   }
// } 

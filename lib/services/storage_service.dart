import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p; // For path manipulation
import 'package:urocenter/core/utils/logger.dart';

/// Service class for interacting with Firebase Cloud Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a file to a specified path in Firebase Storage and returns the download URL.
  ///
  /// [userId]: The ID of the user uploading the file (used for path structuring).
  /// [filePath]: The local path of the file to upload.
  /// [destinationFolder]: The top-level folder in Storage (e.g., 'user_documents', 'profile_pictures').
  /// [fileName]: The desired name for the file in Storage. If null, extracts from filePath.
  Future<String?> uploadFile({
    required String userId,
    required String filePath,
    required String destinationFolder, 
    String? fileName,
  }) async {
    try {
      final File file = File(filePath);
      if (!file.existsSync()) {
        AppLogger.e('Error: File does not exist at path: $filePath');
        return null;
      }
      
      // Determine the file name in storage
      final String storageFileName = fileName ?? p.basename(filePath); 
      
      // Construct the full path in Firebase Storage
      final String fullPath = '$destinationFolder/$userId/$storageFileName';
      
      AppLogger.d('Uploading to: $fullPath');
      
      // Get reference and upload
      final Reference ref = _storage.ref().child(fullPath);
      final UploadTask uploadTask = ref.putFile(file);

      // Wait for upload completion
      final TaskSnapshot taskSnapshot = await uploadTask;

      if (taskSnapshot.state == TaskState.success) {
        final String downloadUrl = await ref.getDownloadURL();
        AppLogger.d('Upload successful! Download URL: $downloadUrl');
        return downloadUrl;
      } else {
        AppLogger.e('Error: Upload task did not succeed. State: ${taskSnapshot.state}');
        return null; 
      }
    } on FirebaseException catch (e) {
      // Handle Firebase specific errors (e.g., permissions)
      AppLogger.e('Firebase Storage Error during upload: ${e.code} - ${e.message}');
      // Consider rethrowing a custom exception or returning null/error code
      return null;
    } catch (e) {
      // Handle other potential errors
      AppLogger.e('General Error during file upload: $e');
      return null;
    }
  }

  // TODO: Add methods for deleting files, listing files etc. if needed
} 

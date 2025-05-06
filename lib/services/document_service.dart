import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:urocenter/core/models/models.dart'; // Import models
import 'package:urocenter/core/utils/logger.dart';

// TODO: Implement dependency injection (e.g., using Riverpod) to provide this service.

/// Service class for handling document metadata in Firestore and potentially related storage operations.
class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Keep storage instance if needed for delete, or rely on a separate StorageService
  // final FirebaseStorage _storage = FirebaseStorage.instance; 

  /// Adds document metadata to the user's 'documents' subcollection in Firestore.
  /// Returns the ID of the newly created document, or null on failure.
  Future<String?> addUserDocument(String userId, DocumentModel documentData) async {
    if (userId.isEmpty) return null;
    try {
      final CollectionReference userDocsRef = 
          _firestore.collection('users').doc(userId).collection('documents');
      
      // Add the document data (Firestore generates the ID)
      final DocumentReference newDocRef = await userDocsRef.add(documentData.toMap());
      
      AppLogger.d('Document metadata added to Firestore with ID: ${newDocRef.id}');
      return newDocRef.id;
    } catch (e) {
      AppLogger.e('Error adding document metadata to Firestore: $e');
      return null;
    }
  }
  
  /// Fetches the list of documents for a specific user from Firestore.
  Future<List<DocumentModel>> getUserDocuments(String userId) async {
    if (userId.isEmpty) return [];
    AppLogger.d('DocumentService: Fetching documents for user $userId from Firestore...');
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('users').doc(userId).collection('documents')
          .orderBy('upload_date', descending: true) // Order by upload date
          .get();
          
      return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // IMPORTANT: Create DocumentModel including the Firestore document ID
          return DocumentModel.fromMap(data).copyWith(id: doc.id); 
      }).toList();
      
    } catch (e) {
      AppLogger.e('Error fetching user documents from Firestore: $e');
      return []; // Return empty list on error
    }
  }

  /// Deletes a document metadata entry from Firestore by its ID.
  /// Returns true if deletion was successful.
  Future<bool> deleteDocument(String userId, String documentId) async {
     if (userId.isEmpty || documentId.isEmpty) return false;
     AppLogger.d('DocumentService: Deleting document metadata $documentId for user $userId...');
    // TODO: Implement deletion from Firestore
    // Example:
    // try {
    //   await _firestore.collection('users').doc(userId).collection('documents').doc(documentId).delete();
    //   AppLogger.d('Firestore metadata deleted successfully');
    //   // TODO: Trigger deletion from Firebase Storage as well (needs file path/URL)
    //   // final storageService = ref.read(storageServiceProvider); // Need Riverpod ref or pass service
    //   // await storageService.deleteFile(...); 
    //   return true;
    // } catch (e) {
    //   AppLogger.e('Error deleting document metadata: $e');
    //   return false;
    // }
    return false; // Placeholder
  }

  // Note: Original uploadDocument method is removed as StorageService handles the upload.
  // The metadata saving is now done via addUserDocument.
} 

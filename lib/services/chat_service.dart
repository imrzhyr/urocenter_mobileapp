import 'package:urocenter/core/models/chat_model.dart'; // Specific import
import 'package:urocenter/core/models/message_model.dart'; // Specific import
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< ADD Firestore import
import 'package:firebase_storage/firebase_storage.dart'; // <<< ADD Firebase Storage import
import 'dart:io'; // <<< ADD Dart IO import
import 'package:firebase_auth/firebase_auth.dart'; // <<< ADD Firebase Auth import
import 'package:uuid/uuid.dart'; // <<< ADD Uuid import
import 'package:urocenter/core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:urocenter/providers/in_app_notification_provider.dart'; // Import NotificationData
import 'package:urocenter/features/user/services/user_profile_service.dart'; // To get user names
import 'package:urocenter/providers/service_providers.dart'; // <<< Import service providers

// TODO: Implement dependency injection (e.g., using Riverpod) to provide this service.

/// Service class for handling chat related operations.
/// Interacts with the backend API or a real-time service (like Firestore, WebSockets).
class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Ref _ref; // Add Ref for accessing other providers

  // Update constructor to accept dependencies
  ChatService(this._firestore, this._auth, this._ref);

  // TODO: Inject necessary clients (API client, real-time DB reference, etc.)
  // final ApiClient _apiClient;
  // final FirestoreClient _firestoreClient; 
  // ChatService(this._apiClient, this._firestoreClient);

  /// Fetches the list of chat sessions for the current user.
  Future<List<Chat>> getChatList() async {
    // TODO: Implement API/DB call to fetch chat list
    AppLogger.d('ChatService: Fetching chat list...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    // Example: Replace with actual API call
    // final response = await _apiClient.get('/chats');
    // final List<dynamic> chatList = response.data ?? [];
    // return chatList.map((data) => Chat.fromMap(data)).toList();
    return []; // Placeholder
  }

  /// Fetches messages for a specific chat session.
  /// Might include pagination (e.g., fetch older messages).
  Future<List<Message>> getChatMessages(String chatId, {String? lastMessageId}) async {
    // TODO: Implement API/DB call to fetch messages for a chat
    AppLogger.d('ChatService: Fetching messages for chat $chatId...');
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    // Example: Replace with actual API call
    // final response = await _apiClient.get('/chats/$chatId/messages', queryParams: {'before': lastMessageId});
    // final List<dynamic> messageList = response.data ?? [];
    // return messageList.map((data) => Message.fromMap(data)).toList();
    return []; // Placeholder
  }

  /// Sends a new message in a specific chat.
  Future<bool> sendMessage(String chatId, Message message) async {
    // TODO: Implement API/DB call to send a message
    AppLogger.d('ChatService: Sending message in chat $chatId...');
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay
    // Example: Replace with actual API call
    // final response = await _apiClient.post('/chats/$chatId/messages', data: message.toMap());
    // return response.statusCode == 201;
    return false; // Placeholder
  }

  /// Returns a stream of messages for a specific chat ID, ordered by timestamp.
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // Show oldest first
        .snapshots()
        .map<List<Message>>((snapshot) { // Explicit return type for map
      if (snapshot.docs.isEmpty) {
        AppLogger.d("ChatService ($chatId): Snapshot is empty");
        return <Message>[]; // Return empty list of correct type
      }
      AppLogger.d("ChatService ($chatId): Received ${snapshot.docs.length} messages");
      return snapshot.docs.map<Message>((doc) { // Explicit type for inner map
        // Create message from map first
        final message = Message.fromMap(doc.data() as Map<String, dynamic>);
        // Use copyWith to set the Firestore document ID
        return message.copyWith(id: doc.id); 
      }).toList();
    }).handleError((error) {
      // Add error handling for the stream
      AppLogger.e("Error in chat stream for $chatId: $error");
      // Return an empty list of the correct type on error
      return <Message>[];
    });
  }
  
  // Add other chat-related methods as needed (e.g., mark as read, create chat)

  /// Sends a message and saves it to Firestore.
  /// Also handles creating the chat document if it doesn't exist.
  Future<void> sendMessageToFirestore(String chatId, Message message) async {
    // Get sender name (Requires UserProfileService to be available)
    String senderName = 'Unknown User'; // Default
    final userProfileService = _ref.read(userProfileServiceProvider); // Assume userProfileServiceProvider exists
    try {
      final userProfile = await userProfileService.getUserProfile(message.senderId);
      // Check if this is an admin user
      final bool isAdmin = userProfile?['isAdmin'] == true;
      
      if (isAdmin) {
        // Always use Dr. Ali Kamal for admin users
        senderName = "Dr. Ali Kamal";
        AppLogger.d("[ChatService] Using admin doctor name: $senderName");
      } else {
        // For regular users, use their full name
        senderName = userProfile?['fullName'] as String? ?? 'Unknown User';
      }
    } catch (e) {
      AppLogger.e("Error fetching sender name for chat update: $e");
    }
    
    try {
      final messagesCollection = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages');
      final chatDocRef = _firestore.collection('chats').doc(chatId);

      final messageData = message.toMap();
      messageData['timestamp'] = FieldValue.serverTimestamp(); 

      WriteBatch batch = _firestore.batch();
      batch.set(messagesCollection.doc(), messageData); 

      final chatUpdateData = {
        'lastMessageContent': message.content,
        'lastMessageSenderId': message.senderId,
        'lastMessageSenderName': senderName, // <<< ADD sender name
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': chatId.split('_'),
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageType': message.type.value,
        'status': 'active',
        // Potentially add/update participant details (names, roles) here too
      };

      batch.set(chatDocRef, chatUpdateData, SetOptions(merge: true));

      AppLogger.d("[DEBUG] Committing batch for chatId: $chatId (MESSAGE + CHAT DOC UPDATE with senderName: $senderName)");
      await batch.commit();
      AppLogger.d("ChatService: Message sent and chat document updated for $chatId");
    } catch (e) {
      AppLogger.e("Error sending message to Firestore for chat $chatId: $e");
      rethrow; 
    }
  }

  /// Uploads an image file to Firebase Storage for a specific chat.
  /// Returns the download URL of the uploaded image.
  Future<String?> uploadChatImage(String chatId, String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        AppLogger.e("Error uploading image: File does not exist at $filePath");
        return null;
      }

      // --- Force refresh Auth Token (Attempt to fix permission issue) ---
      AppLogger.d("[DEBUG] Forcing ID token refresh before storage upload...");
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      AppLogger.d("[DEBUG] Token refreshed.");
      // ------------------------------------------------------------------

      // Create a unique filename (e.g., using timestamp)
      String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.${file.path.split('.').last}';
      
      // Create a reference to the Firebase Storage path
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chats') // Root folder for chats
          .child(chatId)  // Subfolder for this specific chat
          .child('images') // Subfolder for images in this chat
          .child(fileName); // The actual file

      AppLogger.d("Uploading image to: ${storageRef.fullPath}");

      // Upload the file
      UploadTask uploadTask = storageRef.putFile(file);

      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.d("Image uploaded successfully. URL: $downloadUrl");
      
      return downloadUrl;

    } on FirebaseException catch (e, s) {
      AppLogger.e(
        "Firebase Storage Error during image upload: Code='${e.code}', Plugin='${e.plugin}', Message='${e.message}'", 
        e,
        s
      );
      return null;
    } catch (e, s) {
      AppLogger.e(
        "General Error during image upload: Type='${e.runtimeType}', Error='$e'", 
        e,
        s
      );
      return null;
    }
  }

  /// Uploads a document file to Firebase Storage for a specific chat.
  /// Returns the download URL of the uploaded document.
  Future<String?> uploadChatDocument(String chatId, String filePath, String? originalFileName) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        AppLogger.e("Error uploading document: File does not exist at $filePath");
        return null;
      }

      // Use original filename if available, otherwise generate one
      String extension = file.path.split('.').last;
      String fileName = originalFileName != null 
        ? 'doc_${DateTime.now().millisecondsSinceEpoch}_${originalFileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_')}' 
        : 'doc_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      // Ensure filename is reasonably safe and doesn't contain invalid characters
      // (The replaceAll above helps, but storage might have stricter rules)

      // Create a reference to the Firebase Storage path
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chats') // Root folder for chats
          .child(chatId)  // Subfolder for this specific chat
          .child('documents') // Subfolder for documents in this chat
          .child(fileName); // The actual file

      AppLogger.d("Uploading document to: ${storageRef.fullPath}");

      // --- Force refresh Auth Token ---
      // Keep this from the image upload as it might still be relevant
      AppLogger.d("[DEBUG] Forcing ID token refresh before storage upload...");
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      AppLogger.d("[DEBUG] Token refreshed.");
      // --------------------------------

      // Upload the file with metadata (specify content type if possible)
      // This helps the browser/app handle the file correctly on download
      // Determine content type based on extension (can be more sophisticated)
      String? contentType;
      if (extension == 'pdf') {
        contentType = 'application/pdf';
      } else if (extension == 'doc') {
        contentType = 'application/msword';
      } else if (extension == 'docx') {
        contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }
      // Add more types as needed (txt, xls, etc.)

      SettableMetadata? metadata = contentType != null ? SettableMetadata(contentType: contentType) : null;
      
      UploadTask uploadTask = storageRef.putFile(file, metadata);

      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.d("Document uploaded successfully. URL: $downloadUrl");
      
      return downloadUrl;

    } on FirebaseException catch (e, s) {
      AppLogger.e(
        "Firebase Storage Error during document upload: Code='${e.code}', Plugin='${e.plugin}', Message='${e.message}'", 
        e,
        s
      );
      return null;
    } catch (e, s) {
      AppLogger.e(
        "General Error during document upload: Type='${e.runtimeType}', Error='$e'", 
        e,
        s
      );
      return null;
    }
  }

  /// Uploads a voice message file to Firebase Storage for a specific chat.
  /// Returns the download URL of the uploaded audio file.
  Future<String?> uploadChatVoice(String chatId, String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        AppLogger.e("Error uploading voice message: File does not exist at $filePath");
        return null;
      }

      // Create a unique filename for the voice message (e.g., using timestamp)
      String fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.aac'; // Assuming AAC format from flutter_sound
      
      // Create a reference to the Firebase Storage path
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chats') // Root folder for chats
          .child(chatId)  // Subfolder for this specific chat
          .child('voice') // Subfolder for voice messages in this chat
          .child(fileName); // The actual file

      AppLogger.d("Uploading voice message to: ${storageRef.fullPath}");

      // --- Force refresh Auth Token ---
      AppLogger.d("[DEBUG] Forcing ID token refresh before storage upload...");
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      AppLogger.d("[DEBUG] Token refreshed.");
      // --------------------------------

      // Upload the file with metadata (specify content type for AAC)
      SettableMetadata metadata = SettableMetadata(contentType: 'audio/aac');
      UploadTask uploadTask = storageRef.putFile(file, metadata);

      // Wait for the upload to complete
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.d("Voice message uploaded successfully. URL: $downloadUrl");
      
      return downloadUrl;

    } on FirebaseException catch (e, s) {
      AppLogger.e(
        "Firebase Storage Error during voice upload: Code='${e.code}', Plugin='${e.plugin}', Message='${e.message}'", 
        e,
        s
      );
      return null;
    } catch (e, s) {
      AppLogger.e(
        "General Error during voice upload: Type='${e.runtimeType}', Error='$e'", 
        e,
        s
      );
      return null;
    }
  }

  /// Deletes a specific message document from Firestore.
  Future<void> deleteMessage(String chatId, String messageId) async {
    if (chatId.isEmpty || messageId.isEmpty) {
      AppLogger.e("Error deleting message: Invalid chatId or messageId.");
      return;
    }
    
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      AppLogger.d("ChatService: Message $messageId deleted from chat $chatId");
      
      // TODO: Optional - Update the parent chat document's last message info.
      // This is complex as it requires finding the *new* last message after deletion.
      // Consider using a Cloud Function trigger for robustness or skipping for simplicity.
      
    } catch (e) {
      AppLogger.e("Error deleting message $messageId from chat $chatId: $e");
      rethrow; // Rethrow the error for UI handling
    }
  }

  /// Updates the status of a specific chat document.
  Future<void> updateChatStatus(String chatId, String newStatus) async {
    AppLogger.d("[ChatService UpdateStatus] Called with chatId: '$chatId', newStatus: '$newStatus'");
    if (chatId.isEmpty) {
      AppLogger.e("Error updating chat status: Invalid chatId.");
      return;
    }
    // Validate newStatus if needed (e.g., ensure it's 'active' or 'resolved')
    if (newStatus != 'active' && newStatus != 'resolved') {
       AppLogger.e("Error updating chat status: Invalid status '$newStatus'.");
      return;
    }

    try {
      AppLogger.d("[ChatService UpdateStatus] Attempting Firestore set for doc: ${chatId}");
      await _firestore
          .collection('chats')
          .doc(chatId)
          .set({'status': newStatus}, SetOptions(merge: true));
      AppLogger.d("ChatService: Chat $chatId status updated/set to $newStatus");
    } catch (e) {
      AppLogger.e("Error updating/setting status for chat $chatId: $e");
      rethrow; // Rethrow for UI handling
    }
  }

  // --- ADDED: Start Audio Call ---
  /// Initiates an audio call by creating the call document in Firestore.
  ///
  /// Returns the generated callId on success, or null on failure.
  Future<String?> startAudioCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
  }) async {
    final callId = const Uuid().v4(); // Generate unique ID
    AppLogger.d("[ChatService startAudioCall] Generated Call ID: $callId");
    
    // Ensure we have a proper caller name for admin users
    String finalCallerName = callerName;
    if (finalCallerName.isEmpty || finalCallerName == "UroCenter User" || finalCallerName == "Unknown Caller") {
      // Try to get caller name from user profile
      try {
        final currentAuth = FirebaseAuth.instance;
        final userProfilePath = 'users/$callerId';
        final userDoc = await _firestore.doc(userProfilePath).get();
        
        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data()!;
          // Check for fullName or name fields
          final name = userData['fullName'] ?? userData['name'];
          if (name is String && name.isNotEmpty) {
            finalCallerName = name;
            AppLogger.d("[ChatService startAudioCall] Found proper name for caller: $finalCallerName");
          }
          
          // Special handling for admin users - ensure "Dr." prefix for known doctors
          if (userData['isAdmin'] == true && !finalCallerName.startsWith('Dr.')) {
            // Always use Dr. Ali Kamal for admin users (only doctor in the app)
            finalCallerName = "Dr. Ali Kamal";
            AppLogger.d("[ChatService startAudioCall] Using fixed admin name: Dr. Ali Kamal");
          }
        }
      } catch (e) {
        AppLogger.e("[ChatService startAudioCall] Error getting caller profile: $e");
        // Continue with original name if error
      }
    }

    final callData = {
      'callId': callId,
      'callerId': callerId,
      'callerName': finalCallerName, // Use enhanced name
      'calleeId': calleeId,
      'calleeName': calleeName,
      'status': 'ringing', // Change to 'ringing' to be detected by call listeners
      'type': 'audio', // Add type field to fix call event message error
      // 'offer': null, // Explicitly null or absent is fine
      // 'answer': null,
      'createdAt': FieldValue.serverTimestamp(), // Track creation time
    };

    try {
      AppLogger.d("[ChatService startAudioCall] Writing call initiation data to Firestore for call ID: $callId");
      await _firestore.collection('calls').doc(callId).set(callData);
      AppLogger.d("[ChatService startAudioCall] Call document created successfully with caller name: $finalCallerName");
      return callId; // Return the ID on success
    } catch (e) {
      AppLogger.e("[ChatService startAudioCall] Error writing call initiation data to Firestore: $e");
      return null; // Return null on failure
    }
  }
  // --- END: Start Audio Call ---

  /// Returns a stream of incoming messages across all user chats for notifications.
  Stream<NotificationData?> getGlobalIncomingMessagesStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      AppLogger.w("[ChatService] Cannot get global message stream: User not logged in.");
      return Stream.value(null); // Return a stream with a single null value
    }

    // Check if user is an admin or properly authenticated
    _checkUserAuthenticationStatus(currentUserId).then((isAuthenticated) {
      if (!isAuthenticated) {
        AppLogger.w("[ChatService] User not authenticated: ${_auth.currentUser!.email}");
        // We don't stop the stream here, but log the warning
      }
    }).catchError((e) {
      AppLogger.e("[ChatService] Error checking user auth status: $e");
    });

    AppLogger.d("[ChatService] Setting up global message listener for user: $currentUserId");

    try {
      return _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          // .orderBy('lastMessageTime', descending: true) // Ordering might be complex with filters
          .snapshots(includeMetadataChanges: true) // Listen for metadata changes
          .map((querySnapshot) {
        AppLogger.d("[ChatService Global Listener] Received snapshot with ${querySnapshot.docs.length} docs. Metadata: hasPendingWrites=${querySnapshot.metadata.hasPendingWrites}");
        // Find the document that triggered the notification (latest change, not from self)
        DocumentChange? relevantChange;
        for (var change in querySnapshot.docChanges) {
            if (change.type == DocumentChangeType.modified && !change.doc.metadata.hasPendingWrites) {
                final data = change.doc.data() as Map<String, dynamic>?;
                if (data != null && data['lastMessageSenderId'] != currentUserId && data['lastMessageTime'] != null) {
                  // This looks like a new message from someone else
                  // Prioritize this change
                  AppLogger.d("[ChatService Global Listener] Potential notification change detected for doc: ${change.doc.id}");
                  relevantChange = change;
                  break; // Process the first valid change
                }
            }
        }

        if (relevantChange == null) {
          AppLogger.d("[ChatService Global Listener] No relevant modified documents found in this snapshot.");
          return null; // No notification-worthy change in this snapshot
        }
        
        final doc = relevantChange.doc;
        final data = doc.data() as Map<String, dynamic>; // Already checked for null

        AppLogger.i("[ChatService Global Listener] Processing notification for chat: ${doc.id}");

        // Extract data for notification
        final String chatId = doc.id;
        final String senderName = data['lastMessageSenderName'] as String? ?? 'Unknown User';
        final String messageContent = data['lastMessageContent'] as String? ?? '';
        final String messageType = data['lastMessageType'] as String? ?? MessageType.text.value;

        String messageSnippet;
        if (messageType == MessageType.text.value) {
          messageSnippet = messageContent;
        } else if (messageType == MessageType.image.value) {
          messageSnippet = 'Sent an image'; // TODO: Localize
        } else if (messageType == MessageType.document.value) {
          messageSnippet = 'Sent a document'; // TODO: Localize
        } else if (messageType == MessageType.voice.value) {
          messageSnippet = 'Sent a voice message'; // TODO: Localize
        } else {
          messageSnippet = 'Sent a message'; // TODO: Localize
        }

        // Return the data object
        return NotificationData(
          chatId: chatId,
          senderName: senderName,
          messageSnippet: messageSnippet,
        );

      }).handleError((error) {
        // More specific error handling by error type
        if (error.toString().contains('permission-denied')) {
          AppLogger.w("Permission denied in global message stream - user may not have access: $error");
        } else {
          AppLogger.e("Error in global incoming messages stream: $error");
        }
        return null; // Emit null on error
      });
    } catch (e) {
      AppLogger.e("Error setting up global message stream: $e");
      return Stream.value(null);
    }
  }

  /// Sends a system message to a chat, used for call events and other system notifications
  Future<void> sendSystemMessage({
    required String chatId,
    required String content,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    AppLogger.d("[ChatService] Sending system message to chat $chatId: $content");
    try {
      // Create a "system" message - no particular sender
      final systemMessage = Message(
        id: '', // Firestore will generate
        chatId: chatId,
        senderId: 'system', // Special sender ID for system messages
        recipientId: null,
        content: content,
        type: MessageType.fromString(type),
        status: MessageStatus.sent,
        metadata: metadata,
        createdAt: DateTime.now(), // Will be replaced with server timestamp
      );

      final messagesCollection = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages');
      final chatDocRef = _firestore.collection('chats').doc(chatId);

      final messageData = systemMessage.toMap();
      messageData['timestamp'] = FieldValue.serverTimestamp();
      
      WriteBatch batch = _firestore.batch();
      batch.set(messagesCollection.doc(), messageData);

      // Update the chat document with the system message info
      final chatUpdateData = {
        'lastMessageContent': systemMessage.content,
        'lastMessageSenderId': 'system',
        'lastMessageSenderName': 'System',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageType': systemMessage.type.value,
      };

      batch.set(chatDocRef, chatUpdateData, SetOptions(merge: true));
      
      await batch.commit();
      AppLogger.d("[ChatService] System message sent to chat $chatId");
    } catch (e) {
      AppLogger.e("[ChatService] Error sending system message: $e");
    }
  }

  // Helper method to check if user is authenticated properly or is an admin
  Future<bool> _checkUserAuthenticationStatus(String userId) async {
    try {
      // First check if this is an admin user
      final userProfilePath = 'users/$userId';
      final userDoc = await _firestore.doc(userProfilePath).get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        // If user is admin, they're always authenticated
        if (userData['isAdmin'] == true) {
          AppLogger.d("[ChatService] Admin user detected, bypassing strict verification");
          return true;
        }
      }
      
      // For regular users, check if they're properly authenticated
      if (_auth.currentUser != null) {
        return _auth.currentUser!.emailVerified || _auth.currentUser!.phoneNumber != null;
      }
      
      return false;
    } catch (e) {
      AppLogger.e("[ChatService] Error checking authentication status: $e");
      return true; // Default to allowing in case of error
    }
  }

} 

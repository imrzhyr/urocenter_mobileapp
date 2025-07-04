import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:urocenter/app/routes.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles Firebase Cloud Messaging (FCM) setup and notification interactions
class FCMHandler {
  final GoRouter router;
  bool _isInitialized = false;

  FCMHandler({required this.router});

  /// Initialize the FCM handler, set up message listeners
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.d("[FCMHandler] Already initialized, skipping");
      return;
    }
    
    AppLogger.d("[FCMHandler] Initializing");
    
    // Only handle background and terminated message taps
    // Skip foreground message handling since that's done by in-app notifications
    
    // Set up background/terminated app message open handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Check for initial message (app opened from terminated state via notification)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.d("[FCMHandler] App opened from terminated state via notification");
      _handleMessageTap(initialMessage);
    }
    
    _isInitialized = true;
    AppLogger.d("[FCMHandler] Initialization complete");
  }

  /// We don't need this for foreground messages as they're handled by the in-app notification system
  /// from the stream listener in UroApp
  /*
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.d("[FCMHandler] Received foreground message: ${message.messageId}");
    // Foreground messages are already handled by the in-app notification system
    // No need to do anything here as the app is already showing notifications via stream
  }
  */

  /// Handles when a notification message is tapped to open the app from background state
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.d("[FCMHandler] Notification opened app from background: ${message.messageId}");
    _handleMessageTap(message);
  }

  /// Process notification tap and navigate to the appropriate screen
  void _handleMessageTap(RemoteMessage message) {
    try {
      AppLogger.d("[FCMHandler] Processing message tap: ${message.data}");
      
      // Check for required data
      final type = message.data['type'];
      if (type == null) {
        AppLogger.w("[FCMHandler] Message data missing 'type' field");
        return;
      }
      
      // Handle chat message notifications
      if (type == 'chat_message') {
        final chatId = message.data['chatId'];
        final senderId = message.data['senderId'];
        
        AppLogger.d("[FCMHandler] Chat message data: chatId=$chatId, senderId=$senderId, data=${message.data}");
        
        if (chatId == null) {
          AppLogger.w("[FCMHandler] Chat message missing chatId");
          return;
        }
        
        // Get the current user ID
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null) {
          AppLogger.w("[FCMHandler] Cannot handle message: User not logged in");
          return;
        }
        
        // Get the participants from the chat ID to find the other user
        final participants = chatId.split('_');
        AppLogger.d("[FCMHandler] Chat participants: $participants, currentUserId: $currentUserId");
        
        final otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => senderId ?? '', // Fall back to senderId if available
        );
        
        // Get sender name from notification or data
        final senderName = message.data['senderName'] ?? 
                          message.notification?.title?.replaceAll('New message from ', '') ?? 
                          'Chat';
        
        AppLogger.d("[FCMHandler] Resolved sender info: name=$senderName, id=$otherUserId");
        
        // Navigate to the chat screen
        final navigationData = {
          'chatId': chatId,
          'otherUserId': otherUserId,
          'otherUserName': senderName,
        };
        
        AppLogger.d("[FCMHandler] Navigating to chat: $chatId with otherUserId: $otherUserId, otherUserName: $senderName");
        
        // Use the router to navigate
        router.pushNamed(RouteNames.userChat, extra: navigationData);
      }
      // Add other notification types here as needed
      
    } catch (e) {
      AppLogger.e("[FCMHandler] Error handling message tap: $e");
    }
  }
} 
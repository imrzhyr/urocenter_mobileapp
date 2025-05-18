import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:urocenter/app/routes.dart'; // Assuming routes are defined here
import 'package:overlay_support/overlay_support.dart'; // Import overlay_support
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod for context access
import 'package:urocenter/providers/service_providers.dart'; // For routerProvider
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urocenter/core/utils/logger.dart'; // Correct import for AppLogger

// Data class to hold notification info
class NotificationData {
  final String chatId;
  final String senderName;
  final String messageSnippet;
  // Add any other relevant info needed for navigation/display

  NotificationData({
    required this.chatId,
    required this.senderName,
    required this.messageSnippet,
  });
}

// Provider definition remains the same (defined in main.dart or service_providers.dart)
// final inAppNotificationProvider = ChangeNotifierProvider<InAppNotificationProvider>((ref) => InAppNotificationProvider(ref));

class InAppNotificationProvider extends ChangeNotifier {
  final Ref _ref; // Need Ref to access router
  DateTime _lastNotificationTime = DateTime(2000); // Initialize with old date

  InAppNotificationProvider(this._ref); // Constructor to accept Ref

  // Call this method when a new message arrives that should trigger a notification
  void showNotification(NotificationData notificationData) { 
    AppLogger.d("[InAppNotificationProvider] Showing notification for: ${notificationData.chatId}, sender: ${notificationData.senderName}");
    
    // Prevent multiple notifications in quick succession (within 1 second)
    final now = DateTime.now();
    if (now.difference(_lastNotificationTime).inMilliseconds < 1000) {
      AppLogger.d("[InAppNotificationProvider] Throttling notification (too soon after previous notification)");
      return;
    }
    _lastNotificationTime = now;
    
    // Try the standard overlay notification approach
    try {
      showOverlayNotification(
        (context) {
          AppLogger.d("[InAppNotificationProvider] Building notification widget");
          return _InAppChatNotification(
            notificationData: notificationData,
            onTap: () {
              // Get the main navigator context for navigation
              final router = _ref.read(routerProvider);
              final navContext = router.routerDelegate.navigatorKey.currentContext;
              if (navContext != null) {
                _navigateToChat(navContext, notificationData.chatId, notificationData.senderName);
              }
              // Dismiss the notification
              OverlaySupportEntry.of(context)?.dismiss();
            },
          );
        },
        duration: const Duration(seconds: 5),
        position: NotificationPosition.top,
      );
      AppLogger.d("[InAppNotificationProvider] Notification display requested");
    } catch (e) {
      AppLogger.e("[InAppNotificationProvider] Error showing notification: $e");
    }
  }

  // Private method to handle navigation
  void _navigateToChat(BuildContext context, String chatId, String senderName) { 
    // Get the sender ID from the chat ID (format: user1_user2)
    final participants = chatId.split('_');
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Find the other user's ID
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '', // Fallback if not found
    );
    
    final navigationData = {
      'chatId': chatId,
      'otherUserId': otherUserId,
      'otherUserName': senderName, // Use the passed sender name
    };
    
    AppLogger.d('[Notification Navigation] Navigating to chat: $chatId with otherUserId: $otherUserId');
    
    // Use the passed context (navigator context) to navigate
    context.pushNamed(RouteNames.userChat, extra: navigationData);
    // Dismissal is handled by onTap in the overlay widget
  }
}

// --- Define the Notification Widget --- 
class _InAppChatNotification extends StatelessWidget {
  final NotificationData notificationData;
  final VoidCallback onTap;

  const _InAppChatNotification({required this.notificationData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            border: Border(
              left: BorderSide(
                color: colorScheme.primaryContainer,
                width: 5.0,
              ),
            ),
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(140),
                blurRadius: 8.0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 22,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notificationData.senderName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notificationData.messageSnippet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: colorScheme.onPrimary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
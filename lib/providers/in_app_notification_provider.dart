import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:urocenter/app/routes.dart'; // Assuming routes are defined here
import 'package:overlay_support/overlay_support.dart'; // Import overlay_support
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod for context access
import 'package:urocenter/providers/service_providers.dart'; // For routerProvider

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

  InAppNotificationProvider(this._ref); // Constructor to accept Ref

  // Call this method when a new message arrives that should trigger a notification
  void showNotification(NotificationData notificationData) { 
    // Use overlay_support to show the notification
    showOverlayNotification(
      (context) { // This context is from the overlay
        // Build the actual notification widget using this overlay context
        return _InAppChatNotification( // Pass data to the widget
          notificationData: notificationData,
          onTap: () {
            // Get the main navigator context for navigation
            final router = _ref.read(routerProvider);
            final navContext = router.routerDelegate.navigatorKey.currentContext;
            if (navContext != null) {
              _navigateToChat(navContext, notificationData.chatId);
            }
            OverlaySupportEntry.of(context)?.dismiss(); // Dismiss notification on tap
          },
        );
      },
      duration: const Duration(seconds: 5), // Auto-dismiss duration
      position: NotificationPosition.top, // Show at the top
    );
    // No need to call notifyListeners() for visibility
  }

  // Private method to handle navigation
  void _navigateToChat(BuildContext context, String chatId) { 
    final navigationData = {
      'chatId': chatId,
    };
    // Use the passed context (navigator context) to navigate
    context.pushNamed(RouteNames.userChat, extra: navigationData);
    // Dismissal is handled by onTap in the overlay widget
  }

  // No need for hideNotification, dispose, isVisible, _overlayContext, _hideTimer anymore
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            border: Border(
              left: BorderSide(
                color: colorScheme.primaryContainer,
                width: 4.0,
              ),
            ),
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(128),
                blurRadius: 6.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble,
                size: 22,
                color: colorScheme.onPrimary,
              ),
              const SizedBox(width: 14),
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
              // Optional close button (styling would also need update if used)
            ],
          ),
        ),
      ),
    );
  }
} 
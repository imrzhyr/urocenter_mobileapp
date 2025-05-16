import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_utils.dart';
import 'user_avatar_style2.dart';
import 'status_badge_style2.dart';

/// A reusable chat list item component for displaying conversations.
///
/// This can be used for both admin consultation lists and user chat lists
/// with customizable styling and information display.
class ChatListItemStyle2 extends StatelessWidget {
  /// The name of the participant
  final String name;
  
  /// The last message content
  final String lastMessage;
  
  /// Time of the last message
  final String timeString;
  
  /// Number of unread messages (0 for none)
  final int unreadCount;
  
  /// Whether this chat is marked as urgent
  final bool isUrgent;
  
  /// Status of the chat (active, completed, etc.)
  final String status;
  
  /// Optional status display text (defaults to status)
  final String? statusDisplay;
  
  /// Optional avatar image URL
  final String? avatarUrl;
  
  /// Callback when the item is tapped
  final VoidCallback? onTap;
  
  /// Optional route name to navigate to
  final String? routeName;
  
  /// Optional extra data to pass when navigating
  final dynamic routeExtra;
  
  /// Optional additional widget to display at the bottom
  final Widget? additionalInfo;
  
  const ChatListItemStyle2({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.timeString,
    this.unreadCount = 0,
    this.isUrgent = false,
    this.status = 'active',
    this.statusDisplay,
    this.avatarUrl,
    this.onTap,
    this.routeName,
    this.routeExtra,
    this.additionalInfo,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    void handleTap() {
      if (onTap != null) {
        onTap!();
      } else if (routeName != null) {
        HapticUtils.lightTap();
        context.pushNamed(
          routeName!,
          extra: routeExtra,
        );
      }
    }
    
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                UserAvatarStyle2(
                  name: name,
                  imageUrl: avatarUrl,
                  isUrgent: isUrgent,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Name and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadgeStyle2(
                            text: statusDisplay ?? status,
                            color: _getStatusColor(status, isDarkMode, context),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Second row: Last message and time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              timeString,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Only show indicators if urgent or has unread messages or additional info
                      if (isUrgent || unreadCount > 0 || additionalInfo != null)
                        const SizedBox(height: 8),
                      
                      if (isUrgent || unreadCount > 0 || additionalInfo != null)
                        Row(
                          children: [
                            // Urgent indicator
                            if (isUrgent)
                              StatusBadgeStyle2(
                                text: 'Urgent',
                                color: theme.colorScheme.error,
                              ),
                            
                            if (additionalInfo != null)
                              additionalInfo!,
                            
                            const Spacer(),
                            
                            // Unread indicator
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status, bool isDarkMode, BuildContext context) {
    final theme = Theme.of(context);
    
    switch (status.toLowerCase()) {
      case 'active':
        return isDarkMode ? AppColors.primaryDarkTheme : theme.colorScheme.primary;
      case 'completed':
        return isDarkMode ? AppColors.successDarkTheme : AppColors.success;
      case 'missed':
      case 'rejected':
        return isDarkMode ? AppColors.errorDarkTheme : AppColors.error;
      case 'urgent':
        return isDarkMode ? AppColors.warningDarkTheme : AppColors.warning;
      default:
        return isDarkMode ? AppColors.primaryDarkTheme : theme.colorScheme.primary;
    }
  }
} 
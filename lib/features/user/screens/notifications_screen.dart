import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../providers/service_providers.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/app_bar_style2.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationsAsyncValue = ref.watch(notificationsStreamProvider);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          AppBarStyle2(
            title: 'profile.notifications'.tr(),
            showBackButton: true,
            showActionButtons: false,
            showSearch: false,
            showFilters: false,
            onBackPressed: () {
              HapticUtils.lightTap();
              context.pop();
            },
          ),
          Expanded(
            child: notificationsAsyncValue.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: theme.colorScheme.primary)
              ),
              error: (error, stackTrace) => Center(
                child: Text('Error loading notifications: $error'),
              ),
              data: (notifications) {
                if (notifications.isEmpty) {
                  // Force the empty state to be centered in the available space
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: const Center(
                            child: EmptyState(
                              icon: Icons.notifications_none,
                              title: 'No notifications',
                              message: 'You don\'t have any notifications yet',
                            ),
                          ),
                        ),
                      );
                    }
                  );
                }
                
                return Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(notificationsStreamProvider);
                      },
                      color: theme.colorScheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
                    ),
                    
                    // Mark all as read button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        tooltip: 'Mark all as read',
                        child: const Icon(Icons.done_all),
                        onPressed: () {
                          HapticUtils.lightTap();
                          ref.read(notificationServiceProvider).markAllAsRead();
                        },
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationCard(NotificationModel notification) {
    final theme = Theme.of(context);
    final formattedTime = _formatNotificationTime(notification.timestamp);
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (direction) {
        ref.read(notificationServiceProvider).deleteNotification(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: notification.isRead ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(77)),
        ),
        color: notification.isRead 
            ? (theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow)
            : theme.colorScheme.primaryContainer.withAlpha(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticUtils.lightTap();
            _handleNotificationTap(notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(notification.type),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedTime,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!notification.isRead)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
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
  
  Widget _buildNotificationIcon(NotificationType type) {
    final theme = Theme.of(context);
    
    IconData iconData;
    Color backgroundColor;
    Color iconColor = theme.colorScheme.onPrimary;
    
    switch (type) {
      case NotificationType.message:
        iconData = Icons.chat_outlined;
        backgroundColor = theme.colorScheme.primary;
        break;
      case NotificationType.document:
        iconData = Icons.description_outlined;
        backgroundColor = theme.colorScheme.tertiary;
        break;
      default:
        iconData = Icons.notifications_outlined;
        backgroundColor = theme.colorScheme.primary;
    }
    
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }
  
  String _formatNotificationTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && now.day == timestamp.day) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (difference.inDays == 1 || (now.day == timestamp.day + 1 && now.month == timestamp.month && now.year == timestamp.year)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
  
  void _handleNotificationTap(NotificationModel notification) {
    // Mark notification as read
    if (!notification.isRead) {
      ref.read(notificationServiceProvider).markAsRead(notification.id);
    }
    
    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.message:
        if (notification.data != null && notification.data!.containsKey('senderId')) {
          final senderId = notification.data!['senderId'] as String;
          final senderName = notification.title.replaceAll('New message from ', '');
          // Navigate to chat
          context.pushNamed(
            RouteNames.userChat,
            extra: {
              'otherUserId': senderId,
              'otherUserName': senderName,
            },
          );
        }
        break;
      case NotificationType.document:
        if (notification.data != null && notification.data!.containsKey('documentId')) {
          // Navigate to document details
          context.pushNamed(RouteNames.userDocuments);
        }
        break;
      default:
        // Do nothing for other types
    }
  }
} 
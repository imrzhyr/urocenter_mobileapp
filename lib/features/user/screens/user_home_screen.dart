import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../../../core/utils/haptic_utils.dart';
import '../../../core/utils/logger.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../app/routes.dart';
import '../../../providers/service_providers.dart';
import '../../../core/models/models.dart';
import '../widgets/dashboard_card.dart';
import '../../../core/widgets/animated_gradient_card_background.dart';
import '../../../core/widgets/app_bar_style2.dart';

/// Home tab for the user dashboard
class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  // --- State Variables ---
  String _userName = ''; 
  bool _isLoadingName = true;
  User? _user;
  Chat? _drKamalChat; 
  bool _isLoadingDrKamalChat = true;
  StreamSubscription? _drKamalChatSubscription;
  final String _drKamalUid = 'A7qj5kfk1sPuv11Q3DJdY2UmTur1'; // Store Dr. Kamal's UID
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingName = true);
    try {
      final userService = ref.read(userProfileServiceProvider);
      final Map<String, dynamic>? userProfileMap = await userService.getCurrentUserProfile(); 
      final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;

      if (mounted && userProfileMap != null && currentUserId != null) {
        final User user = User.fromMap(userProfileMap).copyWith(id: currentUserId);

        setState(() {
          _userName = user.fullName;
          _user = user;
          _isLoadingName = false;
        });

        if (_user?.id != null && _user!.id.isNotEmpty) {
           _subscribeToDrKamalChat(_user!.id);
        } else {
           AppLogger.d("[DEBUG] Custom User model ID is null or empty, cannot load Dr. Kamal chat details.");
           if (mounted) setState(() => _isLoadingDrKamalChat = false);
        }
      } else if (mounted) {
        AppLogger.d("User profile not found or user not logged in.");
        setState(() {
          _userName = "User"; 
          _user = null;
          _isLoadingName = false;
          _isLoadingDrKamalChat = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading user data: $e');
      if (mounted) setState(() => _isLoadingDrKamalChat = false); 
    }
  }

  String _generateChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  void _subscribeToDrKamalChat(String currentUserId) {
    if (!mounted) return;

    final chatId = _generateChatId(currentUserId, _drKamalUid);
    AppLogger.d("[DEBUG] Subscribing to Dr. Kamal chat stream for chatId: $chatId");

    _drKamalChatSubscription?.cancel(); 

    _drKamalChatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen(
      (chatDoc) {
        if (!mounted) return;
        
        AppLogger.d("[DEBUG] Received snapshot for Dr. Kamal chat $chatId. Exists: ${chatDoc.exists}");
        
        if (chatDoc.exists) {
          final chatData = chatDoc.data();
          if (chatData != null) {
            chatData['id'] = chatDoc.id; 
            setState(() {
              _drKamalChat = Chat.fromMap(chatData);
              _isLoadingDrKamalChat = false;
              AppLogger.d("[DEBUG] Updated Dr. Kamal chat state: ${_drKamalChat?.lastMessageContent}");
            });
          } else {
             setState(() { 
               _drKamalChat = null;
               _isLoadingDrKamalChat = false;
             });
          }
        } else {
          AppLogger.d("[DEBUG] Dr. Kamal chat document $chatId does not exist.");
          setState(() {
             _drKamalChat = null;
             _isLoadingDrKamalChat = false;
          });
        }
      },
      onError: (error) {
        AppLogger.e("Error in Dr. Kamal chat stream listener: $error");
        if (mounted) {
          setState(() {
            _drKamalChat = null;
            _isLoadingDrKamalChat = false;
          });
        }
      },
      onDone: () {
         AppLogger.d("Dr. Kamal chat stream listener closed.");
      }
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'dashboard.greeting_morning'.tr();
    if (hour < 17) return 'dashboard.greeting_afternoon'.tr();
    return 'dashboard.greeting_evening'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBarStyle2(
          title: 'dashboard.home'.tr(),
          showSearch: false,
          showFilters: false,
          showBackButton: false,
        ),
      ),
      body: _buildHomeContent(),
    );
  }
  
  Widget _buildHomeContent() {
    final theme = Theme.of(context);
    
    return AnimationLimiter(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              // Welcome message - Updated with state
              AnimatedGradientCardBackground(
                child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: theme.colorScheme.onPrimary.withAlpha(230),
                          child: Icon(
                            Icons.person,
                            color: theme.colorScheme.primary,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _isLoadingName
                            ? _buildNamePlaceholder() // Show placeholder while loading
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_getGreeting()},', // Use state variable
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary.withAlpha(230),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userName, // Use state variable
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary, 
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'dashboard.help_message'.tr(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary.withAlpha(230),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // --- Conditionally Render Consultation Button/Widget ---
                    _buildConsultationWidget(), 
                    // --- END Conditional Render ---
                  ],
                ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Section title
              Text(
                'dashboard.quick_actions'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Quick actions - updated to vertical layout
              Column(
                children: [
                  DashboardCard(
                    title: 'dashboard.medical_history'.tr(),
                    icon: Icons.history,
                    iconColor: theme.colorScheme.primary,
                    onTap: () => context.pushNamed(RouteNames.userMedicalHistory),
                  ),
                  const SizedBox(height: 8),
                  DashboardCard(
                    title: 'dashboard.my_documents'.tr(),
                    icon: Icons.folder_outlined,
                    iconColor: theme.colorScheme.secondary,
                    onTap: () => context.pushNamed(RouteNames.userDocuments),
                  ),
                  const SizedBox(height: 8),
                  DashboardCard(
                    title: 'dashboard.help_support'.tr(),
                    icon: Icons.help_outline,
                    iconColor: AppColors.warning, // Icon itself should be orange
                    onTap: () => context.pushNamed(RouteNames.helpSupport),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNamePlaceholder() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use theme colors for placeholders
        Container(height: 16, width: 100, color: theme.colorScheme.onPrimary.withAlpha(77), margin: const EdgeInsets.only(bottom: 8)),
        Container(height: 20, width: 150, color: theme.colorScheme.onPrimary.withAlpha(128)),
      ],
    );
  }

  Widget _buildConsultationWidget() {
    final theme = Theme.of(context);
    if (_isLoadingDrKamalChat) {
      // Loading state placeholder
      return Container(
        height: 60, // Approximate height of the button/card
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
          borderRadius: BorderRadius.circular(12),
        ),
        // Use theme progress indicator color
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))),
      );
    }

    if (_drKamalChat == null) {
      // --- No existing chat: Show "Start New Consultation" button ---
      return AnimatedButton(
        text: 'dashboard.start_consultation'.tr(),
        onPressed: () {
           HapticUtils.lightTap();
           context.pushNamed(
            RouteNames.userChat,
            extra: {
              'otherUserId': _drKamalUid,
              'otherUserName': 'Dr. Ali Kamal',
                    },
         );
        },
        icon: Icon(
          Icons.add_circle_outline,
          color: theme.colorScheme.primary, 
        ),
      );
    } else {
      // --- Existing chat: Show "Continue Consultation" widget ---
      return InkWell(
        onTap: () {
          HapticUtils.lightTap();
          context.pushNamed(
            RouteNames.userChat,
            extra: {
              'otherUserId': _drKamalUid,
              'otherUserName': 'Dr. Ali Kamal',
            },
          );
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface, 
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: theme.colorScheme.primary.withAlpha(77)), 
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. Ali Kamal',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    if (_drKamalChat!.lastMessageContent != null && _drKamalChat!.lastMessageContent!.isNotEmpty)
                      Text(
                        (_drKamalChat!.lastMessageSenderId == _user?.id ? "You: " : "Dr: ") + 
                        _drKamalChat!.lastMessageContent!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else 
                      Text(
                        'Continue Consultation',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_drKamalChat!.lastMessageTime != null)
                Text(
                  _formatChatTimestamp(_drKamalChat!.lastMessageTime!),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else 
                const SizedBox.shrink(),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20), 
            ],
          ),
        ),
      );
    }
  }

  String _formatChatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24 && now.day == timestamp.day) return DateFormat('h:mm a').format(timestamp);
    if (difference.inDays == 1 || (difference.inDays == 0 && timestamp.day == now.day - 1)) return 'Yesterday';
    if (difference.inDays < 7) return DateFormat.E().format(timestamp);
    return DateFormat('dd/MM/yy').format(timestamp);
  }

  @override
  void dispose() {
    _drKamalChatSubscription?.cancel();
    super.dispose();
  }
} 
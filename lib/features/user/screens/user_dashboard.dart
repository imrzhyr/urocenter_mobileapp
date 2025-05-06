import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../app/routes.dart';
import '../../../providers/service_providers.dart';
import '../../../core/models/models.dart';
import '../widgets/dashboard_card.dart';
import './profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../../core/widgets/animated_gradient_card_background.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/animated_gradient_top_border.dart';
import '../../../core/services/call_service.dart';
import '../../../core/widgets/incoming_call_widget.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Main dashboard for regular users
class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});

  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard> {
  int _selectedIndex = 0;
  
  // --- State Variables ---
  String _userName = ''; 
  bool _isLoadingName = true;
  User? _user;
  // --- ADD State for Dr. Kamal's specific chat ---
  Chat? _drKamalChat; 
  bool _isLoadingDrKamalChat = true; // Start loading initially
  StreamSubscription? _drKamalChatSubscription;
  final String _drKamalUid = 'A7qj5kfk1sPuv11Q3DJdY2UmTur1'; // Store Dr. Kamal's UID
  // --- END State Variables ---
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _startCallListener();
    });
  }

  // --- Updated Data Loading Methods ---
  Future<void> _loadUserData() async {
    setState(() => _isLoadingName = true);
    try {
      final userService = ref.read(userProfileServiceProvider);
      final Map<String, dynamic>? userProfileMap = await userService.getCurrentUserProfile(); 
      final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid; // <<< Use prefixed FirebaseAuth and .uid

      if (mounted && userProfileMap != null && currentUserId != null) { // Check UID not null
        // Explicitly pass the Auth UID as the ID when creating the User object
        final User user = User.fromMap(userProfileMap).copyWith(id: currentUserId);

        setState(() {
          _userName = user.fullName;
          _user = user; // _user is our custom User model object
          _isLoadingName = false;
        });

        // Load Dr. Kamal chat details AFTER user ID is confirmed
        // Use the id field from our custom User model instance (_user)
        if (_user?.id != null && _user!.id.isNotEmpty) { // <<< Correctly use .id from our User model
           _subscribeToDrKamalChat(_user!.id);
        } else {
           AppLogger.d("[DEBUG] Custom User model ID is null or empty, cannot load Dr. Kamal chat details.");
           if (mounted) setState(() => _isLoadingDrKamalChat = false);
        }
      } else if (mounted) {
        // Handle case where profile map or currentUserId is null
        AppLogger.d("User profile not found or user not logged in.");
        setState(() {
          _userName = "User"; 
          _user = null;
          _isLoadingName = false;
          _isLoadingDrKamalChat = false; // Stop loading chat details
        });
      }
    } catch (e) {
      AppLogger.e('Error loading user data: $e');
       if (mounted) setState(() => _isLoadingDrKamalChat = false); 
    }
  }

  // --- ADD Helper to generate consistent Chat ID ---
  String _generateChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // --- ADD Method to load specific chat details for Dr. Kamal ---
  void _subscribeToDrKamalChat(String currentUserId) {
    if (!mounted) return;
    // Set loading true initially if needed, but listener will handle subsequent states
    // setState(() => _isLoadingDrKamalChat = true); 

    final chatId = _generateChatId(currentUserId, _drKamalUid);
    AppLogger.d("[DEBUG] Subscribing to Dr. Kamal chat stream for chatId: $chatId");

    // <<< Cancel previous subscription if exists >>>
    _drKamalChatSubscription?.cancel(); 

    _drKamalChatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen(
      (chatDoc) { // Changed from get() result to stream snapshot
        if (!mounted) return; // Check mounted again inside async callback
        
        AppLogger.d("[DEBUG] Received snapshot for Dr. Kamal chat $chatId. Exists: ${chatDoc.exists}");
        
        if (chatDoc.exists) {
          final chatData = chatDoc.data();
          if (chatData != null) {
            // Add the document ID to the map before creating the Chat object
            chatData['id'] = chatDoc.id; 
            setState(() {
              _drKamalChat = Chat.fromMap(chatData);
              _isLoadingDrKamalChat = false; // Stop loading once data arrives
              AppLogger.d("[DEBUG] Updated Dr. Kamal chat state: ${_drKamalChat?.lastMessageContent}");
            });
          } else {
             // Document exists but data is null (shouldn't happen often)
             setState(() { 
               _drKamalChat = null;
               _isLoadingDrKamalChat = false;
             });
          }
        } else {
          AppLogger.d("[DEBUG] Dr. Kamal chat document $chatId does not exist.");
          setState(() {
             _drKamalChat = null;
             _isLoadingDrKamalChat = false; // Stop loading if doc doesn't exist
          });
        }
      },
      onError: (error) {
        AppLogger.e("Error in Dr. Kamal chat stream listener: $error");
       if (mounted) {
        setState(() {
              _drKamalChat = null; // Assume no chat on error
              _isLoadingDrKamalChat = false; // Stop loading on error
        });
      }
      },
      onDone: () {
         AppLogger.d("Dr. Kamal chat stream listener closed.");
         // Optional: Handle stream closing if needed
         if (mounted) {
            // Might set loading to false or keep the last state
         }
      }
    );
  }
  // --- END Method for subscribing to chat ---

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'dashboard.greeting_morning'.tr();
    if (hour < 17) return 'dashboard.greeting_afternoon'.tr();
    return 'dashboard.greeting_evening'.tr();
  }
  // --- END Updated Data Loading Methods ---

  void _onNavItemTapped(int index) {
    HapticUtils.selection();
    setState(() {
      _selectedIndex = index;
    });
  }
  
  // Placeholder content for when we haven't implemented all tabs yet
  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const ProfilePage();
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final incomingCall = ref.watch(incomingCallProvider);
    final List<String> tabTitles = [
      'dashboard.home'.tr(), 
      'dashboard.profile'.tr()
    ];
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // No longer needed

    // Calculate the desired background color based on theme // No longer needed
    // final Color scaffoldBackgroundColor = isDark 
    //     ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.3)! 
    //     : Color.lerp(theme.colorScheme.surface, Colors.grey, 0.03)!;

    return Scaffold(
      // Use the theme's default scaffold background color
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Use the theme's default AppBar background color
        backgroundColor: theme.appBarTheme.backgroundColor, 
        // elevation: 0, // Rely on theme's AppBar elevation
        title: Text(
          tabTitles[_selectedIndex],
          style: theme.appBarTheme.titleTextStyle, 
        ),
        actions: [
          IconButton(
            // icon: const Icon(Icons.notifications_outlined), // Use theme icon color
            icon: Icon(Icons.notifications_outlined, color: theme.appBarTheme.actionsIconTheme?.color),
            tooltip: 'profile.notifications'.tr(), // Updated to use existing localization key
            onPressed: () {
              HapticUtils.lightTap();
              context.pushNamed(RouteNames.notifications);
            },
          ),
          IconButton(
            // icon: const Icon(Icons.settings_outlined), // Use theme icon color
            icon: Icon(Icons.settings_outlined, color: theme.appBarTheme.actionsIconTheme?.color),
            tooltip: 'settings.title'.tr(), // Updated to use existing localization key
            onPressed: () {
              HapticUtils.lightTap();
              context.pushNamed(RouteNames.settings);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _getBodyForIndex(_selectedIndex),
          if (incomingCall != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: IncomingCallWidget(incomingCall: incomingCall),
            ),
        ],
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.topCenter,
        children: [
          NavigationBar(
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            onDestinationSelected: _onNavItemTapped,
            selectedIndex: _selectedIndex,
            // Use primaryContainer for an indicator derived from the primary color
            indicatorColor: theme.colorScheme.primaryContainer, 
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: 'dashboard.home'.tr(),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: 'dashboard.profile'.tr(),
              ),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedGradientTopBorder(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHomeContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      // Remove the explicit color setting to use the Scaffold's background
      // color: isDark 
      //     ? Color.lerp(theme.colorScheme.surface, Colors.black, 0.3)
      //     : Color.lerp(theme.colorScheme.surface, Colors.grey, 0.03),
      child: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
                            // backgroundColor: const Color.fromRGBO(255, 255, 255, 0.9), // Use theme color
                             backgroundColor: theme.colorScheme.onPrimary.withAlpha(230),
                            child: Icon(
                              Icons.person,
                              // color: AppColors.primary, // Use theme color
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
                                        // Use theme color suitable for gradient background (onPrimary/onSecondary?)
                                        color: theme.colorScheme.onPrimary.withAlpha(230),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _userName, // Use state variable
                                      style: TextStyle(
                                        // Use theme color suitable for gradient background
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
                        'dashboard.help_message'.tr(), // TODO: Localize
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
      ),
    );
  }
  
  // --- ADDED Placeholder Widget ---
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
  // --- END Placeholder Widget ---

  // --- ADDED: Widget builder for Consultation Area ---
  Widget _buildConsultationWidget() {
    final theme = Theme.of(context);
    if (_isLoadingDrKamalChat) {
      // Loading state placeholder
      return Container(
        height: 60, // Approximate height of the button/card
        decoration: BoxDecoration(
          // color: const Color.fromRGBO(224, 224, 224, 0.5),
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
           // <<< Add Light Tap Haptic >>>
           HapticUtils.lightTap();
           // Navigate to chat, passing Dr. Kamal's UID
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
          // color: AppColors.primary, // Use theme color
          color: theme.colorScheme.primary, 
        ),
      );
    } else {
      // --- Existing chat: Show "Continue Consultation" widget ---
      // Use InkWell for tap feedback on a custom card-like structure
      return InkWell(
                  onTap: () {
          // <<< Add Light Tap Haptic >>>
          HapticUtils.lightTap();
          // Navigate to chat, passing Dr. Kamal's UID
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
            // color: Colors.white, // Or AppColors.card if preferred // Use theme card color
            color: theme.cardTheme.color ?? theme.colorScheme.surface, 
            borderRadius: BorderRadius.circular(12.0),
            // border: Border.all(color: const Color.fromRGBO(4, 118, 244, 0.3)), // Use theme border color
            border: Border.all(color: theme.colorScheme.primary.withAlpha(77)), 
            boxShadow: [ // Use theme shadow or adjust
               BoxShadow(
                  // color: const Color.fromRGBO(4, 118, 244, 0.05),
                  color: theme.colorScheme.primary.withAlpha(13),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
             ]
          ),
          child: Row(
            children: [
              // Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 28),
              Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary, size: 28), // Use theme color
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. Ali Kamal', // <<< Show Doctor's Name instead
                      // style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary), // Use theme color
                    ),
                    const SizedBox(height: 4),
                    // --- Display Last Message Content --- 
                    if (_drKamalChat!.lastMessageContent != null && _drKamalChat!.lastMessageContent!.isNotEmpty)
                      Text(
                         // Optional: Indicate sender? (e.g., "You: ..." or "Dr: ...")
                         // Add prefix based on sender ID
                         (_drKamalChat!.lastMessageSenderId == _user?.id ? "You: " : "Dr: ") + 
                         _drKamalChat!.lastMessageContent!,
                        // style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), // Use theme color
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else 
                       Text(
                        'Continue Consultation', // More accurate fallback
                        // style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                         style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic), // Use theme color
                      ),
                    // --- END Display Last Message --- 
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // --- Display formatted timestamp --- 
              if (_drKamalChat!.lastMessageTime != null)
                Text(
                  _formatChatTimestamp(_drKamalChat!.lastMessageTime!), // <<< Use existing helper
                  // style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), // Use theme color
                )
              else 
                 // Optional: Show something if time is null?
                 const SizedBox.shrink(), // Or Text('--:--')
              // --- END Timestamp --- 
              const SizedBox(width: 4), // Add small space before chevron
              // const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20), // Smaller chevron // Use theme color
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20), 
            ],
          ),
      ),
    );
  }
  }
  // --- END Widget builder ---

  // --- ADDED Helper to format chat timestamp (example) ---
  String _formatChatTimestamp(DateTime timestamp) {
    // TODO: Move this to a shared utility (e.g., AppDateUtils)
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24 && now.day == timestamp.day) return DateFormat('h:mm a').format(timestamp); // Use 12-hour format with AM/PM
    if (difference.inDays == 1 || (difference.inDays == 0 && timestamp.day == now.day - 1)) return 'Yesterday';
    if (difference.inDays < 7) return DateFormat.E().format(timestamp); // Day name (e.g., Mon)
    return DateFormat('dd/MM/yy').format(timestamp); // Date
  }
  // --- END Helper ---

  // <<< Add method to start the call listener >>>
  void _startCallListener() {
     final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;
     if (currentUserId != null) {
        AppLogger.d("[UserDashboard] Starting call listener for user: $currentUserId");
        // Read the service provider and start listening
        ref.read(callServiceProvider).listenForIncomingCalls(currentUserId);
     } else {
        AppLogger.d("[UserDashboard] Cannot start call listener: User ID is null.");
     }
  }

  @override
  void dispose() {
    // <<< Cancel the chat subscription >>>
    _drKamalChatSubscription?.cancel();
    // <<< Stop the call listener >>>
    AppLogger.d("[UserDashboard] Stopping call listener.");
    ref.read(callServiceProvider).stopListening(); 
    // Dispose other controllers if any
    super.dispose();
  }
} 

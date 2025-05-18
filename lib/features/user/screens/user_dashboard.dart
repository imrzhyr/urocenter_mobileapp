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
import './user_call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../../core/widgets/animated_gradient_card_background.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/animated_gradient_top_border.dart';
import '../../../core/services/call_service.dart';
import '../../../core/widgets/app_bar_style2.dart';
import '../../../core/widgets/navigation_bar_style2.dart';
import 'package:urocenter/core/utils/logger.dart';
import '../../../features/chat/models/call_params.dart';

// Import the full screen components
import './user_home_screen.dart';

/// Main dashboard for regular users
class UserDashboard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData;

  const UserDashboard({super.key, this.extraData});

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
  // --- Active Call State ---
  Map<String, dynamic>? _activeCallParams;
  // --- END State Variables ---
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _startCallListener();
      _checkForActiveCall();
    });
  }

  void _checkForActiveCall() {
    if (widget.extraData != null && widget.extraData!.containsKey('activeCall')) {
      setState(() {
        _activeCallParams = widget.extraData!['activeCall'] as Map<String, dynamic>?;
      });
    }
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
  
  // Start call listener for incoming calls
  void _startCallListener() {
     final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;
     if (currentUserId != null) {
        AppLogger.d("[UserDashboard] Starting call listener for user: $currentUserId");
        ref.read(callServiceProvider).listenForIncomingCalls(currentUserId);
     } else {
        AppLogger.d("[UserDashboard] Cannot start call listener: User ID is null.");
     }
  }
  
  void _returnToActiveCall() {
    if (_activeCallParams != null) {
      HapticUtils.mediumTap();
      context.pushNamed(
        RouteNames.callScreen,
        extra: _activeCallParams,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            UserHomeScreen(),
            UserCallScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarStyle2(
        selectedIndex: _selectedIndex,
        onItemSelected: _onNavItemTapped,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primaryContainer,
        items: const [
          NavigationItem(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
          ),
          NavigationItem(
            label: 'Calls',
            icon: Icons.call_outlined,
            activeIcon: Icons.call,
          ),
        ],
      ),
    );
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

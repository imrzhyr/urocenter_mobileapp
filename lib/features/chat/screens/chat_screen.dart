import 'dart:io'; // Import for File
import 'dart:async'; // Import for Timer
// Import for Uint8List
import 'dart:ui' as ui; // Import for ui.Image, ui.decodeImageFromPixels, ui.ImageByteFormat
import 'package:urocenter/core/utils/logger.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added import
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState; // Import flutter_sound, HIDE PlayerState
import 'package:path_provider/path_provider.dart'; // Import path_provider
// Needed for DateFormat in _formatDateHeader
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:audioplayers/audioplayers.dart'; // Import audioplayers
import 'package:pdf_render/pdf_render.dart'; // Import pdf_render
// Import for kIsWeb and Uint8List
import 'package:flutter/services.dart'; // Import for BinaryMessenger
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <<< ADD Riverpod import
import 'package:firebase_auth/firebase_auth.dart' hide User; // <<< HIDE Firebase Auth User >>>
import 'package:http/http.dart' as http; // <<< ADD HTTP import >>>
import '../../../providers/service_providers.dart'; // <<< ADD Service Providers import
import '../../../core/theme/theme.dart';
import '../../../core/models/message_model.dart'; // Re-add import for Message model
import '../../../core/models/user_model.dart' as UserModel; // <<< ADD specific user model import with alias >>>
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permission_manager.dart'; // Import permission manager
import '../../../app/routes.dart'; // Correct import for routes
import '../../../core/utils/dialog_utils.dart'; // Import DialogUtils
import '../../../providers/service_providers.dart'; // <<< ADD Service Providers for playback service
import 'package:flutter/scheduler.dart'; // <<< Import SchedulerBinding >>>
// Import for AutomaticKeepAliveClientMixin
// <<< ADD Import for UI Providers >>>
import '../../../providers/ui_providers.dart'; 
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:firebase_auth/firebase_auth.dart' hide User;
import '../../../core/models/user_model.dart' as UserModel;
// <<< Import Haptic Utils >>>
import '../../../core/utils/haptic_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/widgets/circular_loading_indicator.dart';
import 'fullscreen_image_viewer.dart'; // <<< ADD CORRECT IMPORT

// --- Revised Patient Onboarding Data Model ---
// Reflects data explicitly gathered in ProfileSetup, MedicalHistory, DocumentUpload screens
class PatientOnboardingData {
  final String userId;
  final String name; // Assuming name comes from auth/previous step
  final String? profilePictureUrl; // RE-ADDED
  final int? age; // From ProfileSetup
  final String? gender; // From ProfileSetup
  final String? height; // ADDED
  final String? weight; // ADDED
  final String? country; // ADDED
  final String? city; // ADDED
  // Height/Weight/Location skipped for brevity in intro card, but could be added
  final List<String> conditions; // Selected checkboxes from MedicalHistory
  final String? otherConditions; // Text field from MedicalHistory
  final String? medications; // Text field or indication of None/Uploaded from MedicalHistory
  final String? allergies; // Text field or indication of None from MedicalHistory
  final String? surgicalHistory; // Text field or indication of None from MedicalHistory
  final List<Map<String, String>> documents; // From DocumentUpload

  PatientOnboardingData({
    required this.userId,
    required this.name,
    this.profilePictureUrl, // RE-ADDED
    this.age,
    this.gender,
    this.height, // ADDED
    this.weight, // ADDED
    this.country, // ADDED
    this.city, // ADDED
    this.conditions = const [],
    this.otherConditions,
    this.medications,
    this.allergies,
    this.surgicalHistory,
    this.documents = const [],
  });
}
// --- End Revised Patient Onboarding Data Model ---

class ChatScreen extends ConsumerStatefulWidget {
  final String? doctorName; // Made optional as it might come from extra
  final String? doctorTitle; // Made optional
  final bool isNewChat; // Keep this to know context (user vs admin?)
  final dynamic extraData; // Accept the extra data from go_router
  
  const ChatScreen({
    super.key,
    this.doctorName,
    this.doctorTitle,
    this.isNewChat = false,
    this.extraData,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

// Add SingleTickerProviderStateMixin for animation
class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  StreamSubscription<List<Message>>? _messageSubscription; // <<< ADD Stream Subscription
  // <<< ADD Stream Subscription for Chat Status >>>
  StreamSubscription<DocumentSnapshot>? _chatStatusSubscription;
  final ImagePicker _picker = ImagePicker(); // Instance of ImagePicker
  
  // --- Voice Message State ---
  final FlutterSoundRecorder _soundRecorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer; // Timer for recording duration feedback
  Duration _recordingDuration = Duration.zero;
  // --- End Voice Message State ---
  
  // --- Patient Intro State ---
  PatientOnboardingData? _patientData; 
  bool _shouldShowIntro = false; // Flag to trigger intro animation
  bool _introIsVisible = false; // Flag to control actual visibility in build
  late AnimationController _introController;
  late Animation<Offset> _slideAnimation;
  String _chatPartnerId = 'default_partner'; // Store the ID of the other person
  String _displayPartnerName = 'Chat Partner'; // Name to display in AppBar
  String _displayPartnerTitle = ' '; // Title to display in AppBar
  // --- END Patient Intro State ---
  
  // --- ADDED: Chat Status State ---
  String? _chatStatus; // Can be 'active', 'resolved', or null initially
  // --- END: Chat Status State ---
  
  // --- ADDED: Admin Role Flag ---
  bool _isAdmin = false; // Assume false by default
  // --- END: Admin Role Flag ---
  
  @override
  void initState() {
    super.initState();

    // --- Initialize Intro Animation Controller ---
    _introController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0), // Start above the screen
      end: Offset.zero, // End at its natural position
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    ));
    // --- End Intro Animation Controller Init ---
    
    // Process extra data from router
    _processExtraData();

    // TODO: Determine if the current user is an admin and set _isAdmin
    // This needs actual implementation based on your auth/user role system.
    // Example Placeholder (replace with real logic):
    // _isAdmin = AuthService.currentUserIsAdmin; 
    // Or, if role info is passed via navigation:
    // _isAdmin = widget.extraData?['currentUserRole'] == 'admin';
    // REMOVED incorrect placeholder logic below:
    // if (!_displayPartnerName.startsWith("Dr.")) {
    //    _isAdmin = true; 
    // }
    // _isAdmin will remain false by default for users accessing from UserDashboard

    _initializeRecorder();
    _subscribeToMessages(); // <<< CALL new subscription method
    // <<< ADD call to subscribe to chat status >>>
    _subscribeToChatStatus();
    
    // Check if intro should be shown *after* processing extra data
    _checkAndShowIntro(); 
    
    // Listen to text controller changes to toggle send/mic button
    _messageController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    
    // <<< ADD: Fetch Admin Status >>>
    _fetchCurrentUserAdminStatus();
    
    // <<< ADD: Update currently viewed chat ID >>>
    final chatId = _generateChatId(FirebaseAuth.instance.currentUser?.uid ?? '', _chatPartnerId);
    // Update the provider after the first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
          ref.read(currentlyViewedChatIdProvider.notifier).state = chatId;
          AppLogger.d("[ChatScreen] Set currently viewed chat ID: $chatId");
      }
    });
    // <<< END: Update currently viewed chat ID >>>
  }

  // <<< ADD: Method to fetch admin status >>>
  Future<void> _fetchCurrentUserAdminStatus() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return; // Should not happen if logged in

    try {
      final profileService = ref.read(userProfileServiceProvider);
      final profileMap = await profileService.getUserProfile(currentUserId);
      if (mounted && profileMap != null) {
        // <<< Use UserModel alias >>>
        final currentUserProfile = UserModel.User.fromMap(profileMap); 
        setState(() {
          _isAdmin = currentUserProfile.isAdmin;
        });
        AppLogger.d("[DEBUG] Current user admin status: $_isAdmin");
      }
    } catch (e) {
      AppLogger.e("Error fetching current user profile for admin check: $e");
      // Keep _isAdmin as false on error
    }
  }

  void _processExtraData() {
     if (widget.extraData is Map) {
      final Map data = widget.extraData as Map;
      // <<< Use CORRECT keys from AdminConsultationsScreen >>>
      _chatPartnerId = data['otherUserId'] ?? _chatPartnerId; // Use 'otherUserId'
      _displayPartnerName = data['otherUserName'] ?? widget.doctorName ?? _displayPartnerName; // Use 'otherUserName'
      // _displayPartnerTitle = data['doctorTitle'] ?? widget.doctorTitle ?? _displayPartnerTitle; // Comment out - Not passed
      AppLogger.d('[DEBUG] Processed Extra Data - Partner ID: $_chatPartnerId, Name: $_displayPartnerName');
    } else {
       _displayPartnerName = widget.doctorName ?? _displayPartnerName;
       _displayPartnerTitle = widget.doctorTitle ?? _displayPartnerTitle;
       AppLogger.d('[DEBUG] No valid extra data. Using defaults/widget params. Partner ID: $_chatPartnerId');
    }
  }

  Future<void> _checkAndShowIntro() async {
    AppLogger.d('[DEBUG] _checkAndShowIntro called for $_chatPartnerId');
    if (_chatPartnerId != 'default_partner') { 
      final prefs = await SharedPreferences.getInstance();
      final introViewedKey = 'viewedIntro_$_chatPartnerId';
      final bool hasViewedIntro = prefs.getBool(introViewedKey) ?? false;

      AppLogger.d('[DEBUG] Intro viewed flag for $introViewedKey: $hasViewedIntro');

      if (!hasViewedIntro) {
        setState(() {
          _shouldShowIntro = true;
        });
        AppLogger.d('[DEBUG] Fetching patient data because intro not viewed...');
        await _fetchPatientData(); 
        AppLogger.d('[DEBUG] Patient data fetched. _patientData is null? ${(_patientData == null)}');
        
        if (_patientData != null && mounted && _shouldShowIntro) {
          AppLogger.d('[DEBUG] Conditions met. Starting intro animation for $_chatPartnerId');
          setState(() {
             _introIsVisible = true; 
          });
          _introController.forward();
          await prefs.setBool(introViewedKey, true); 
          AppLogger.d('[DEBUG] Marked intro as viewed for $introViewedKey');
        } else {
           AppLogger.d('[DEBUG] Conditions NOT met for showing intro. _patientData: ${_patientData?.name}, mounted: $mounted, _shouldShowIntro: $_shouldShowIntro');
        }
      } else {
         AppLogger.i('[DEBUG] Intro already viewed. Fetching data for info button...');
         await _fetchPatientData();
      }
    } else {
       AppLogger.d('[DEBUG] Default partner ID. Fetching default data...');
       await _fetchPatientData();
    }
  }

  // <<< Modify to fetch REAL patient data >>>
  Future<void> _fetchPatientData() async {
    AppLogger.d('[DEBUG] _fetchPatientData called for: $_chatPartnerId');
    // Reset state immediately
    if (mounted) { // Ensure widget is still mounted before setState
    setState(() { _patientData = null; }); 
    }
    
    // Exit if chat partner ID is invalid/default
    if (_chatPartnerId == 'default_partner') {
       AppLogger.d('[DEBUG] Cannot fetch data for default_partner ID.');
       // Optionally set a default/error state for _patientData here
       return;
    }

    // <<< Fetch from Firestore >>>
    PatientOnboardingData? fetchedData;
    List<Map<String, String>> userDocuments = []; // Initialize empty list for documents
    try {
      final profileService = ref.read(userProfileServiceProvider);
      final profileMap = await profileService.getUserProfile(_chatPartnerId);

      // <<< COMBINED DOCUMENT FETCH LOGIC (Mirroring DocumentManagementScreen) >>>
      // 1. Fetch documents from the dedicated subcollection
      try {
        AppLogger.d("[DEBUG Docs] Fetching documents from subcollection for user: $_chatPartnerId"); 
        final documentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_chatPartnerId)
            .collection('documents')
            .orderBy('upload_date', descending: true) // <<< CORRECTED FIELD NAME
            .get();
        
        if (documentsSnapshot.docs.isNotEmpty) {
           AppLogger.d("[DEBUG Docs] Found ${documentsSnapshot.docs.length} documents in subcollection."); 
           userDocuments = documentsSnapshot.docs.map((doc) {
             final data = doc.data();
             AppLogger.d("[DEBUG Docs] Raw subcollection doc data: $data"); 
             // <<< Map Firestore fields to the expected structure >>>
             final mappedDoc = {
               'name': data['name'] as String? ?? 'Unknown Name', // <<< CORRECTED PREVIOUSLY >>>
               'url': data['url'] as String? ?? '',           // <<< CORRECTED PREVIOUSLY >>>
               'type': data['type'] as String? ?? 'document',    // <<< CORRECTED PREVIOUSLY >>>
             };
             AppLogger.d("[DEBUG Docs] Mapped subcollection doc data: $mappedDoc"); 
             return mappedDoc;
           }).toList();
        } else {
          AppLogger.d("[DEBUG Docs] No documents found in subcollection for user $_chatPartnerId");
        }
      } catch (e) {
         AppLogger.e("[DEBUG] Error fetching documents subcollection for $_chatPartnerId: $e");
         // Proceed even if subcollection fetch fails
      }

      // 2. Fetch document URLs from the main user profile (if profile exists)
      if (profileMap != null) {
         AppLogger.d("[DEBUG Docs] Fetching additional document URLs from main profile...");
         final userProfile = UserModel.User.fromMap(profileMap); // Reuse existing mapping

         List<String> onboardingUrls = [];
         // a. Get URLs from 'uploadedDocumentUrls' list
         if (profileMap['uploadedDocumentUrls'] is List) { // Check directly in map
            onboardingUrls = List<String>.from(profileMap['uploadedDocumentUrls']);
            AppLogger.d("[DEBUG Docs] Found ${onboardingUrls.length} URLs in 'uploadedDocumentUrls'.");
         }
         
         // b. Get URL from 'medicationDocumentUrl' field
         String? medicationUrl = profileMap['medicalHistory']?['medicationDocumentUrl'] as String?;
         if (medicationUrl != null && medicationUrl.isNotEmpty) {
            AppLogger.d("[DEBUG Docs] Found medication URL: $medicationUrl");
            onboardingUrls.add(medicationUrl); 
         }

         // c. Convert URLs to the Map format needed for PatientOnboardingData.documents
         for (String url in onboardingUrls) {
            // Avoid adding duplicates if already present in subcollection (check by URL)
            if (!userDocuments.any((doc) => doc['url'] == url)) {
               String name = 'Onboarding Document'; // Default name
               String type = 'unknown'; // Default type
               try {
                  Uri uri = Uri.parse(url);
                  String pathSegment = uri.pathSegments.last;
                  name = Uri.decodeComponent(pathSegment.split('?').first); // Get part before query params
                  if (name.contains('.')) {
                     type = name.split('.').last.toLowerCase(); // Get file extension as type
                  } 
               } catch (e) {
                  AppLogger.e("[DEBUG Docs] Could not parse filename/type from URL: $url - Error: $e");
               }
            
               // Create the map structure
               final profileDocMap = {
                  'name': name,
                  'url': url,
                  'type': type,
               };
               userDocuments.add(profileDocMap); 
               AppLogger.d("[DEBUG Docs] Added document map from profile URL: $profileDocMap");
            } else {
               AppLogger.d("[DEBUG Docs] Skipping duplicate URL found in subcollection: $url");
            }
         }
      } else {
         AppLogger.d("[DEBUG Docs] User profile map was null, skipping check for profile document URLs.");
      }
      // --- END COMBINED DOCUMENT FETCH LOGIC ---

      // --- Map Firestore data to PatientOnboardingData ---
      if (profileMap != null) {
        final userProfile = UserModel.User.fromMap(profileMap); 
        fetchedData = PatientOnboardingData(
           userId: userProfile.id,
           name: userProfile.fullName, 
           profilePictureUrl: null, 
           age: userProfile.age,
           gender: userProfile.gender,
           height: userProfile.height?.toString(), 
           weight: userProfile.weight?.toString(),
           country: profileMap['country'] as String?, // <<< Get directly from map >>>
           city: profileMap['city'] as String?,    // <<< Get directly from map >>>
           conditions: (userProfile.medicalHistory?['conditions'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
           otherConditions: userProfile.medicalHistory?['otherConditions'] as String?,
           medications: userProfile.medicalHistory?['medications'] as String?,
           allergies: userProfile.medicalHistory?['allergies'] as String?,
           surgicalHistory: userProfile.medicalHistory?['surgicalHistory'] as String?,
           documents: userDocuments, // <<< Use the COMBINED documents list >>>
        );
         AppLogger.d('[DEBUG] Successfully fetched and mapped user profile for $_chatPartnerId');
      } else {
         AppLogger.d('[DEBUG] No profile found in Firestore for $_chatPartnerId');
         fetchedData = PatientOnboardingData(
           userId: _chatPartnerId,
           name: _displayPartnerName, 
           age: null, gender: null, height: null, weight: null, country: null, city: null,
           conditions: [], otherConditions: null, medications: null, allergies: null, surgicalHistory: null, 
           documents: userDocuments // <<< Still include COMBINED documents >>>
         );
      }
    } catch (e) {
       AppLogger.e('[DEBUG] Error during _fetchPatientData for $_chatPartnerId: $e');
       fetchedData = PatientOnboardingData(
         userId: _chatPartnerId, 
           name: _displayPartnerName, 
           age: null, gender: null, height: null, weight: null, country: null, city: null,
           conditions: [], otherConditions: null, medications: null, allergies: null, surgicalHistory: null, 
           documents: userDocuments // <<< Still include COMBINED documents >>>
       );
    }

    if (mounted) {
      setState(() {
        _patientData = fetchedData;
      });
      AppLogger.d('[DEBUG] _fetchPatientData completed. Set _patientData to: ${_patientData?.name}, with ${_patientData?.documents.length ?? 0} documents.');
    }
  }
  
  // Call this to hide the intro card
  void _dismissIntro() {
    if (_shouldShowIntro && mounted) {
      _introController.reverse().whenComplete(() {
         if (mounted) {
           setState(() {
             _shouldShowIntro = false; // Prevents trying to show again
             _introIsVisible = false; // Remove from layout
           });
           AppLogger.d('Intro dismissed for $_chatPartnerId');
         }
      });
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel(); // <<< CANCEL subscription
    _chatStatusSubscription?.cancel(); // <<< CANCEL chat status subscription
    _soundRecorder.closeRecorder(); // Close the sound recorder
    _recordingTimer?.cancel(); // Cancel recording timer
    _introController.dispose(); // Dispose animation controller
    
    // <<< ADD: Clear currently viewed chat ID >>>
    // Use SchedulerBinding to avoid calling setState during dispose
    SchedulerBinding.instance.addPostFrameCallback((_) {
        // Check if the current value is still this chat before clearing
        // This prevents accidentally clearing if the user navigates away
        // and back to a *different* chat before this dispose frame callback runs.
        final currentChatIdInProvider = ref.read(currentlyViewedChatIdProvider);
        final thisChatId = _generateChatId(FirebaseAuth.instance.currentUser?.uid ?? '', _chatPartnerId);
        if (currentChatIdInProvider == thisChatId) {
            ref.read(currentlyViewedChatIdProvider.notifier).state = null;
            AppLogger.d("[ChatScreen] Cleared currently viewed chat ID: $thisChatId");
        }
    });
    // <<< END: Clear currently viewed chat ID >>>
    
    super.dispose();
  }
  
  // Initialize FlutterSoundRecorder
  Future<void> _initializeRecorder() async {
    // Check permission status using the permission manager ONLY
    // Do not try to open the recorder here.
    final status = await Permission.microphone.status;
    
    // If status is permanently denied, show a snackbar with guidance
    if (status.isPermanentlyDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Voice messages require microphone access.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => PermissionManager.resetIOSPermissions(context),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
      // Set recorder as not initialized if permanently denied
      _isRecorderInitialized = false; 
    } else {
      // We assume the recorder *can* be initialized, but don't open it yet.
      // The actual opening happens in _startRecording after permission grant.
      _isRecorderInitialized = false; // Explicitly set to false until opened successfully
    }
    
    // No need for setState here as we are not opening the recorder
  }
  
  // --- Helper Methods for Date Formatting ---
  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'chat.today'.tr();
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'chat.yesterday'.tr();
    } else if (date.year == now.year) {
      return DateFormat.MMMMd().format(date); // e.g., "August 22"
    } else {
      return DateFormat.yMMMMd().format(date); // e.g., "August 22, 2023"
    }
  }
  // --- End Helper Methods ---

  // Load existing messages or set up initial message for new chat
  // Future<void> _loadMessages() async { ... }

  // --- ADDED: Helper to generate consistent Chat ID >>>
  String _generateChatId(String userId1, String userId2) {
    // Sort IDs to ensure consistency regardless of who starts the chat
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // --- ADDED: Method to subscribe to message stream >>>
  void _subscribeToMessages() {
    setState(() => _isLoading = true); // Show loading initially
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      AppLogger.e("Error: Current user is null, cannot subscribe to messages.");
      setState(() => _isLoading = false); // Stop loading if no user
      // Optionally show an error message on the UI
      return;
    }

    // Assuming _chatPartnerId is correctly set from navigation
    final chatId = _generateChatId(currentUserId, _chatPartnerId);
    AppLogger.d("[DEBUG] Current User ID: $currentUserId");
    AppLogger.d("[DEBUG] Chat Partner ID (from extraData/widget): $_chatPartnerId");
    AppLogger.d("[DEBUG] Generated Chat ID for subscription: $chatId");

    final chatService = ref.read(chatServiceProvider);
    _messageSubscription = chatService.getMessagesStream(chatId).listen(
      (newMessages) {
        AppLogger.d("[DEBUG] Received ${newMessages.length} messages from stream for chatId: $chatId");
      if (mounted) {
          // <<< Update state FIRST >>>
          setState(() {
            _messages.clear(); // Clear old list
            _messages.addAll(newMessages); // Add all messages from stream
            _isLoading = false; // Stop loading once messages arrive
          });
          // <<< THEN schedule scroll for after layout >>>
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(); // Scroll down after updating messages and layout
          });
        }
      },
      onError: (error) {
        AppLogger.e("[DEBUG] Error in message stream listener for chatId: $chatId -> $error");
        if (mounted) {
          setState(() => _isLoading = false); // Stop loading on error
          // Optionally show an error message on the UI
        }
      },
      onDone: () {
        AppLogger.d("[DEBUG] Message stream for $chatId closed.");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    );
  }

  // --- ADDED: Method to subscribe to chat document status >>>
  void _subscribeToChatStatus() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _chatPartnerId == 'default_partner') {
      AppLogger.d("[DEBUG Status] Cannot subscribe to chat status: Invalid user or partner ID.");
      return;
    }

    final chatId = _generateChatId(currentUserId, _chatPartnerId);
    AppLogger.d("[DEBUG Status] Subscribing to chat document: $chatId");

    _chatStatusSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final newStatus = data['status'] as String?;
            setState(() {
              _chatStatus = newStatus ?? 'active'; // Default to active if null
            });
            AppLogger.d("[DEBUG Status] Received chat status update for $chatId: $_chatStatus");
          } else {
            // Document might not exist initially, treat as active
            setState(() {
              _chatStatus = 'active';
            });
            AppLogger.d("[DEBUG Status] Chat document $chatId does not exist. Assuming status: active");
          }
        }
      },
      onError: (error) {
        AppLogger.e("[DEBUG Status] Error in chat status stream listener for $chatId: $error");
        if (mounted) {
          // Optionally handle error state, maybe keep current status or default to active
          // setState(() => _chatStatus = 'error'); 
      }
      },
      onDone: () {
        AppLogger.d("[DEBUG Status] Chat status stream for $chatId closed.");
      },
    );
  }
  
  // Send a new text message
  Future<void> _sendMessage() async { // <<< Mark as async
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    
    // --- Get IDs --- 
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recipientId = _chatPartnerId; // Already available in state

    if (currentUserId == null) {
      AppLogger.e("Error: Cannot send message, user not logged in.");
      // Optionally show a user-facing error
      return;
    }

    // --- Generate Chat ID ---
    final chatId = _generateChatId(currentUserId, recipientId);

    // --- Create Message Object ---
    // Note: We don't set createdAt here; Firestore handles it with serverTimestamp
    final message = Message(
      id: '', // Firestore will generate ID, can leave empty or use temporary UUID
      chatId: chatId,
      senderId: currentUserId, // Current logged-in user
      recipientId: recipientId, // The person we are chatting with
      content: messageText, // Content is the text
      type: MessageType.text, // Type is text
      localFilePath: null, 
      status: MessageStatus.sending, // Optimistic status, Firestore listener will confirm
      createdAt: DateTime.now(), // Placeholder, Firestore uses server timestamp
    );
    
    // --- Clear input BEFORE sending to prevent accidental double-sends ---
      _messageController.clear();

    // --- Call the Service --- 
    try {
      AppLogger.d("[DEBUG] Attempting to call sendMessageToFirestore...");
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessageToFirestore(chatId, message);
      AppLogger.d("[DEBUG] Successfully called sendMessageToFirestore for chat: $chatId");
      // No need for setState here, the stream listener will update the UI
      // No need to scroll here, stream listener handles it
    } catch (e) {
      AppLogger.e("[DEBUG] Error calling sendMessageToFirestore: $e");
      // TODO: Handle error - maybe show snackbar, maybe add message back to text field?
      // Maybe update the status of a temporarily added local message to 'failed'?
      // For now, just print the error.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message. Please try again.')),
        );
        // Optionally put the text back for the user
        _messageController.text = messageText; 
      }
    }

    // --- REMOVE Old Local Update & Fake Response ---
    // setState(() {
    //   _messages.add(message);
    //   _messageController.clear();
    // });
    // WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    // Future.delayed(const Duration(seconds: 2), () {
    //    if (!mounted) return;
    //   final responseMessage = Message(...);
    //   setState(() {
    //     _messages.add(responseMessage);
    //   });
    //   WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    // });
  }

  // --- Send Attachment Message --- (Modified for Upload)
  Future<void> _sendAttachmentMessage(String localPath, MessageType type, {String? fileName}) async { // <<< Make async
    
    // --- Get IDs and Chat ID --- 
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recipientId = _chatPartnerId; 
    if (currentUserId == null) {
      AppLogger.e("Error: Cannot send attachment, user not logged in.");
      DialogUtils.showMessageDialog(context: context, title: 'Error', message: 'Cannot send message. Please log in.');
      return;
    }
    final chatId = _generateChatId(currentUserId, recipientId);
    
    // --- Create Temporary Message for UI --- 
    final tempMessageId = const Uuid().v4(); // Generate a unique temporary ID
    final tempMessage = Message(
      id: tempMessageId, // Use temporary ID
      chatId: chatId,
      senderId: currentUserId, 
      recipientId: recipientId,
      content: fileName ?? localPath.split('/').last, // Use filename or derive from path
      type: type, // image, document, etc.
      localFilePath: localPath, // Store the local path for display
      mediaUrl: null, // No mediaUrl yet
      status: MessageStatus.sending, // Initially sending
      createdAt: DateTime.now(), // Use current time for local display order
    );

    // --- Add Optimistically to UI --- 
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    // --- Start Upload Process --- 
    String? downloadUrl;
    bool uploadError = false;
    try {
      final chatService = ref.read(chatServiceProvider);
      
      // Upload based on type (currently only image implemented in service)
      if (type == MessageType.image) {
        AppLogger.d("Starting image upload for: $localPath");
        downloadUrl = await chatService.uploadChatImage(chatId, localPath);
        if (downloadUrl == null) {
           uploadError = true;
           AppLogger.e("Image upload failed for $localPath");
        }
      } else if (type == MessageType.document) {
          // --- Call Document Upload Service --- 
          AppLogger.d("Starting document upload for: $localPath (filename: $fileName)");
          downloadUrl = await chatService.uploadChatDocument(chatId, localPath, fileName);
          if (downloadUrl == null) {
            uploadError = true;
            AppLogger.e("Document upload failed for $localPath");
          }
          // --- END Document Upload Call --- 
      } else {
         AppLogger.d("Unsupported attachment type for upload: ${type.name}");
         uploadError = true;
      }

      // --- Send Final Message Data if Upload Succeeded --- 
      if (!uploadError && downloadUrl != null) {
        AppLogger.d("Upload successful, sending final message data...");
        final finalMessage = Message(
          id: '', // Firestore will generate ID
          chatId: chatId,
          senderId: currentUserId,
          recipientId: recipientId,
          content: fileName ?? localPath.split('/').last, // Keep original name/content info
          type: type, 
          localFilePath: null, // Clear local path after upload
          mediaUrl: downloadUrl, // <<< Use the uploaded URL >>>
          status: MessageStatus.sent, // Can set to sent, Firestore timestamp confirms
          createdAt: DateTime.now(), // Placeholder, Firestore uses server timestamp
          metadata: tempMessage.metadata, // Carry over any metadata if needed
        );
        
        // Send the final message data to Firestore
        await chatService.sendMessageToFirestore(chatId, finalMessage);
        AppLogger.d("Final message data sent for attachment.");
        
        // Optional: Update the local message status to sent (stream should handle this too)
        // final index = _messages.indexWhere((m) => m.id == tempMessageId);
        // if (index != -1 && mounted) {
        //   setState(() {
        //     _messages[index] = _messages[index].copyWith(status: MessageStatus.sent, mediaUrl: downloadUrl, localFilePath: null);
        //   });
        // }
        
      } else {
         AppLogger.e("Upload failed or URL was null. Message not sent to Firestore.");
         // Error already marked, will be handled in finally block
      }
      
    } catch (e) {
      AppLogger.e("Error during attachment send process: $e");
      uploadError = true; // Mark error on general exception
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload ${type.name}. Please try again.')),
        );
      }
    } finally {
      // --- Update UI on Error --- 
      if (uploadError && mounted) {
        // Find the temporary message and update its status to failed
        final index = _messages.indexWhere((m) => m.id == tempMessageId);
        if (index != -1) {
          setState(() {
            _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
          });
        }
      }
    }
  }

  // Scroll to the bottom of the list
  void _scrollToBottom() {
    // <<< Remove SchedulerBinding.instance.addPostFrameCallback wrapper >>>
    // SchedulerBinding.instance.addPostFrameCallback((_) async { 
      // // Initial delay for layout
      // await Future.delayed(const Duration(milliseconds: 50)); 
      
      // <<< Perform check and jump directly >>>
      if (!mounted || !_scrollController.hasClients) return;

      const double targetOffsetPadding = 50.0; // Keep padding

      // --- Jump directly to the target --- 
      final double target = _scrollController.position.maxScrollExtent + targetOffsetPadding;
      _scrollController.jumpTo(
        target,
      );

      // --- Removed second check and animation logic ---
      
    // <<< Remove closing parenthesis for addPostFrameCallback >>>
    // }); 
  }
  
  // --- Show Attachment Options ---
  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor, // Use theme card color
      shape: const RoundedRectangleBorder( // Add rounded corners
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bc) {
        return SafeArea( 
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text('Upload Document', style: Theme.of(context).textTheme.bodyMedium),
                  onTap: () async {
                    // <<< Add Haptic Tap >>>
                    HapticUtils.lightTap();
                    Navigator.of(context).pop();
                    try {
                       FilePickerResult? result = await FilePicker.platform.pickFiles(
                         type: FileType.custom,
                         allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
                       );
                       if (result != null && result.files.first.path != null) {
                         PlatformFile file = result.files.first;
                         _sendAttachmentMessage(file.path!, MessageType.document, fileName: file.name);
                       } else {
                         AppLogger.d('Document picking cancelled or path is null');
                       }
                     } catch (e) {
                       AppLogger.e('Error picking document: $e');
                     }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text('Take Photo', style: Theme.of(context).textTheme.bodyMedium),
                  onTap: () async {
                    // <<< Add Haptic Tap >>>
                    HapticUtils.lightTap();
                     Navigator.of(context).pop();
                      try {
                        final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
                        if (photo != null) {
                          _sendAttachmentMessage(photo.path, MessageType.image);
                        } else {
                          AppLogger.d('Photo capture cancelled');
                        }
                      } catch (e) {
                        AppLogger.e('Error taking photo: $e');
                      }
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text('Upload Photo', style: Theme.of(context).textTheme.bodyMedium),
                  onTap: () async {
                    // <<< Add Haptic Tap >>>
                    HapticUtils.lightTap();
                     Navigator.of(context).pop();
                      try {
                         final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                           _sendAttachmentMessage(image.path, MessageType.image);
                        } else {
                          AppLogger.d('Image picking cancelled');
                        }
                      } catch (e) {
                        AppLogger.e('Error picking image: $e');
                      }
                  },
                ),
                // Optional: Add a cancel button
                Divider(height: 1, color: Theme.of(context).dividerColor),
                 ListTile(
                  leading: Icon(Icons.cancel_outlined, color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153)),
                  title: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153))),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // --- End Show Attachment Options ---

  // --- Start Recording (Modified for Permissions) ---
  Future<void> _startRecording() async {
    // 1. Request Permission
    final hasPermission = await PermissionManager.requestMicrophonePermission(context);
    if (!hasPermission) {
      AppLogger.d('Microphone permission denied or permanently denied. Cannot start recording.');
      return;
    }

    // 2. Ensure Recorder is Opened (only if permission granted)
    if (!_isRecorderInitialized) {
      AppLogger.d('Permission granted. Attempting to open recorder...');
      try {
        await _soundRecorder.openRecorder();
        _isRecorderInitialized = true; // Set to true ONLY after successful open
        AppLogger.d('Sound Recorder successfully opened.');
      } catch (e) {
        AppLogger.e('Error opening sound recorder after permission grant: $e');
        _isRecorderInitialized = false; // Ensure it's false if open failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not prepare audio recorder. Please try again.')),
          );
        }
        return; // Don't proceed if open failed
      }
    }

    // 3. Start Recording (only if recorder is initialized/opened)
    if (_isRecorderInitialized) {
      try {
        Directory tempDir = await getTemporaryDirectory();
        _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        
        // Start recording with improved quality settings
        await _soundRecorder.startRecorder(
          toFile: _recordingPath,
          codec: Codec.aacADTS,
          sampleRate: 44100,    // Explicitly set sample rate (CD Quality)
          numChannels: 1,       // Explicitly set mono
          bitRate: 128000,      // Increase bit rate to 128 kbps for better quality
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        // Start timer for duration feedback
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isRecording) {
            timer.cancel();
            return;
          }
          if (mounted) { // Add mounted check before setState
            setState(() {
              _recordingDuration += const Duration(seconds: 1);
            });
          } else { // Cancel timer if not mounted
             timer.cancel();
          }
        });

        AppLogger.d('Recording started...');
      } catch (e) {
        AppLogger.e('Error starting recording: $e');
        if (mounted) { // Add mounted check before setState
           setState(() => _isRecording = false);
        }
        _recordingTimer?.cancel();
      }
    } else {
       AppLogger.d('Cannot start recording: Recorder is not initialized.');
       // Redundant check usually, but good for safety
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Could not start audio recording.')),
         );
       }
    }
  }

  // --- Stop Recording --- 
  Future<void> _stopRecording({bool cancelled = false}) async {
    if (!_isRecorderInitialized || !_isRecording) return;

    try {
      await _soundRecorder.stopRecorder();
      _recordingTimer?.cancel(); // Stop the timer
      String? path = _recordingPath;
      Duration duration = _recordingDuration;
      
      setState(() {
         _isRecording = false;
         _recordingPath = null; // Reset path after stopping
         _recordingDuration = Duration.zero; // Reset duration
      });

      if (!cancelled && path != null && duration > Duration.zero) {
        // AppLogger.d('Recording stopped: $path, Duration: $duration');
        // TODO: Send the voice message using the path
        // AppLogger.d('Conditions met, calling _sendVoiceMessage...');
        _sendVoiceMessage(path, duration);
      } else if (cancelled && path != null) {
        // AppLogger.d('Recording cancelled. Deleting file: $path');
        // Delete the cancelled recording file
        try {
           File(path).delete();
        } catch (e) {
           AppLogger.e('Error deleting cancelled recording: $e');
        }
      }
    } catch (e) {
      AppLogger.e('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
       _recordingTimer?.cancel();
    }
  }

  // --- Cancel Recording (Placeholder for potential slide gesture) ---
  void _cancelRecording() {
    if (_isRecording) {
       _stopRecording(cancelled: true);
    }
  }

  // --- Send Voice Message (Modified for Upload) ---
  Future<void> _sendVoiceMessage(String localPath, Duration duration) async { // <<< Make async
    
    // --- Get IDs and Chat ID --- 
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final recipientId = _chatPartnerId; 
    if (currentUserId == null) {
      AppLogger.e("Error: Cannot send voice message, user not logged in.");
      DialogUtils.showMessageDialog(context: context, title: 'Error', message: 'Cannot send message. Please log in.');
      return;
    }
    final chatId = _generateChatId(currentUserId, recipientId);
    
    // --- Create Temporary Message for UI --- 
    final tempMessageId = const Uuid().v4(); 
    final tempMessage = Message(
      id: tempMessageId, 
      chatId: chatId,
      senderId: currentUserId, 
      recipientId: recipientId,
      content: 'Voice Message', // Placeholder content
      type: MessageType.voice, 
      localFilePath: localPath, // Store local path for initial playback/UI
      mediaUrl: null, 
      status: MessageStatus.sending, 
      createdAt: DateTime.now(),
       metadata: {'duration_ms': duration.inMilliseconds}, // Store duration
    );

    // --- Add Optimistically to UI --- 
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    // --- Start Upload Process --- 
    String? downloadUrl;
    bool uploadError = false;
    try {
      final chatService = ref.read(chatServiceProvider);
      AppLogger.d("Starting voice upload for: $localPath");
      downloadUrl = await chatService.uploadChatVoice(chatId, localPath);
      if (downloadUrl == null) {
         uploadError = true;
         AppLogger.e("Voice upload failed for $localPath");
  }

      // --- Send Final Message Data if Upload Succeeded --- 
      if (!uploadError && downloadUrl != null) {
        AppLogger.d("Upload successful, sending final voice message data...");
        final finalMessage = Message(
          id: '', // Firestore will generate ID
          chatId: chatId,
          senderId: currentUserId,
          recipientId: recipientId,
          content: 'Voice Message', // Keep placeholder or use duration string?
          type: MessageType.voice, 
          localFilePath: null, // Clear local path
          mediaUrl: downloadUrl, // Use the uploaded URL
          status: MessageStatus.sent, 
          createdAt: DateTime.now(), // Placeholder for Firestore timestamp
          metadata: {'duration_ms': duration.inMilliseconds}, // Keep duration
        );
        
        await chatService.sendMessageToFirestore(chatId, finalMessage);
        AppLogger.d("Final voice message data sent.");
        
      } else {
         AppLogger.e("Voice upload failed or URL was null. Message not sent to Firestore.");
      }
      
    } catch (e) {
      AppLogger.e("Error during voice message send process: $e");
      uploadError = true; 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload voice message.')) // Corrected missing parenthesis
        );
      }
    } finally {
      // --- Update UI on Error --- 
      if (uploadError && mounted) {
        final index = _messages.indexWhere((m) => m.id == tempMessageId);
        if (index != -1) {
          setState(() {
            _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
          });
        }
      }
    }
  }

  // --- ADDED: Mark Resolved Action (extracted from AppBar button) ---
  void _markAsResolved() {
    // --- Define Action Logic ---
    Future<void> _performResolveAction() async {
      final BuildContext currentContext = context;
      if (!currentContext.mounted) return;

      AppLogger.d('[MarkResolved AppBar] Resolve action initiated.');
      try {
        final chatService = ref.read(chatServiceProvider);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        AppLogger.d("[MarkResolved AppBar] Current User ID: $currentUserId");
        AppLogger.d("[MarkResolved AppBar] Chat Partner ID: $_chatPartnerId");
        if (currentUserId != null) {
          final chatId = _generateChatId(currentUserId, _chatPartnerId);
          AppLogger.d("[MarkResolved AppBar] Generated Chat ID: $chatId");
          AppLogger.d("[MarkResolved AppBar] Attempting updateChatStatus...");
          await chatService.updateChatStatus(chatId, 'resolved');
          AppLogger.e("[MarkResolved AppBar] updateChatStatus call completed (no immediate error).");

          // Navigate back AFTER successful update
          if (currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Consultation marked as resolved.')) // TODO: Localize
            );
            // Only pop the chat screen itself now
            GoRouter.of(currentContext).pop(true);
          }
        } else {
          AppLogger.e("Error: Could not get current user ID to update status.");
          if (currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Error updating status. User not found.')),
            );
          }
        }
      } catch (e) {
        AppLogger.e("Error calling updateChatStatus from AppBar: $e");
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Failed to mark as resolved. Please try again.')),
          );
        }
      }
    }
    // --- End Action Logic ---

    // Show confirmation dialog
    showDialog<void>(
      context: context, // Use the original context for dialog
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Resolution'),
        content: const Text('Are you sure you want to mark this consultation as resolved? The chat will be closed.'),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            onPressed: () => Navigator.pop(dialogContext), // Just close dialog
          ),
          TextButton(
            child: Text('Resolve', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
            onPressed: () {
              // <<< Add Medium Tap Haptic on Confirmation >>>
              HapticUtils.mediumTap();
              Navigator.pop(dialogContext); // Close dialog first
              _performResolveAction();    // Then trigger the action
            },
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
  // --- END: Mark Resolved Action ---

  // --- ADDED: Mark Active (Unresolve) Action ---
  void _markAsActive() {
    // --- Define Action Logic ---
    Future<void> _performUnresolveAction() async {
      final BuildContext currentContext = context;
      if (!currentContext.mounted) return;

      AppLogger.d('[MarkActive AppBar] Unresolve action initiated.');
      try {
        final chatService = ref.read(chatServiceProvider);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null) {
          final chatId = _generateChatId(currentUserId, _chatPartnerId);
          AppLogger.d("[MarkActive AppBar] Generated Chat ID: $chatId");
          AppLogger.d("[MarkActive AppBar] Attempting updateChatStatus to active...");
          await chatService.updateChatStatus(chatId, 'active');
          AppLogger.d("[MarkActive AppBar] updateChatStatus call completed.");

          if (currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Consultation marked as active again.')) // TODO: Localize
            );
            // <<< ADD navigation pop >>>
            GoRouter.of(currentContext).pop(true);
          }
        } else {
          AppLogger.e("Error: Could not get current user ID to update status.");
          if (currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(content: Text('Error updating status. User not found.')),
            );
          }
        }
      } catch (e) {
        AppLogger.e("Error calling updateChatStatus to active from AppBar: $e");
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Failed to mark as active. Please try again.')),
          );
        }
      }
    }
    // --- End Action Logic ---

    // Show confirmation dialog
    showDialog<void>(
      context: context, // Use the original context for dialog
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as Active?'),
        content: const Text('Are you sure you want to mark this consultation as active again?'),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            onPressed: () => Navigator.pop(dialogContext), // Just close dialog
          ),
          TextButton(
            child: Text('Mark Active', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            onPressed: () {
              // <<< Add Medium Tap Haptic on Confirmation >>>
              HapticUtils.mediumTap();
              Navigator.pop(dialogContext); // Close dialog first
              _performUnresolveAction();    // Then trigger the action
            },
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
  // --- END: Mark Active Action ---

  @override
  Widget build(BuildContext context) {
    // Determine if text field is empty
    bool isTextFieldEmpty = _messageController.text.trim().isEmpty;

    // --- Calculate hint text ---\n    String hintTextValue; \n    if (_isRecording) {\n      final formattedDuration = \'${\_recordingDuration.inMinutes.toString().padLeft(2, \'0\')}:${(\_recordingDuration.inSeconds % 60).toString().padLeft(2, \'0\')}\';\n      // Ensure the key \'chat.recording\' in your translation files has \"{}\" placeholder\n      hintTextValue = \'chat.recording\'.tr(args: [formattedDuration]); \n    } else {\n      hintTextValue = \'chat.send_message\'.tr();\n    }\n    // --- End Calculate hint text ---\n

    return Scaffold(
      backgroundColor: Theme.of(context).cardColor, // Set Scaffold BG to Card color
      appBar: AppBar(
        backgroundColor: AppColors.primary, // Blue background color
        foregroundColor: Colors.white, // White text and icons
        elevation: 2, // Add some elevation for depth
        titleSpacing: 0.0, // <<< ADD THIS LINE to reduce space before title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white), // White back icon
          onPressed: () => context.pop(),
        ),
        title: Row(
          // <<< Align items vertically centered >>>
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            // Conditional Avatar Logic ...
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withAlpha(77), // White with opacity
              // Show doctor image ONLY if current user is NOT admin
              backgroundImage: !_isAdmin 
                  ? const AssetImage('assets/images/profile_pictures/doctor-profile.jpg') 
                  : null,
              // Show user initial ONLY if current user IS admin
              child: _isAdmin 
                  ? Text(
                      _displayPartnerName.isNotEmpty ? _displayPartnerName[0].toUpperCase() : '?', // Use partner name initial
                      style: const TextStyle(
                        color: Colors.white, // White text
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null, // No child text if showing doctor image
              // Optional: Add error handling for image loading
              // <<< Only provide error handler if image is being set >>>
              onBackgroundImageError: !_isAdmin 
                  ? (exception, stackTrace) {
                AppLogger.e('Error loading doctor profile image in Chat AppBar: $exception');
                // Keep the fallback background color if image fails
                    } 
                  : null, // Set to null when not using backgroundImage
            ),
            // <<< End Conditional Avatar Logic >>>
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                // <<< Align text to the start >>>
                crossAxisAlignment: CrossAxisAlignment.start,
                // <<< Center column content vertically (might not be needed with Row alignment) >>>
                // mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  Text(
                    _displayPartnerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // <<< Remove potentially problematic title if empty >>>
                  if (_displayPartnerTitle.trim().isNotEmpty)
                  Text(
                    _displayPartnerTitle,
                    style: TextStyle(
                      color: Colors.white.withAlpha(217),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // --- Conditionally show Info Button for Admins ---
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white), // White icon
              tooltip: 'View Patient Info', // TODO: Localize
              onPressed: _patientData != null ? () {
                 // <<< Add Haptic Tap >>>
                 HapticUtils.lightTap();
                 _showPatientInfoSheet(_patientData!);
              } : null,
            ),
            
          // --- DYNAMIC Resolve/Unresolve Button ---
          if (_isAdmin && _chatStatus != null) // Only show if admin and status loaded
            if (_chatStatus == 'resolved') 
              // --- Show "Mark as Active" Button ---
             IconButton(
                 icon: const Icon(Icons.refresh, color: Colors.white), // White icon
                 tooltip: 'Mark as Active', // TODO: Localize
                 onPressed: () {
                     // <<< Add Haptic Tap >>>
                     HapticUtils.lightTap();
                     _markAsActive();
                  },
              )
            else 
              // --- Show "Mark as Resolved" Button ---
              IconButton(
                 icon: const Icon(Icons.check_circle_outline, color: Colors.white), // White icon
                 tooltip: 'Mark as Resolved', // TODO: Localize
                 onPressed: () {
                     // <<< Add Haptic Tap >>>
                     HapticUtils.lightTap();
                     _markAsResolved();
                  },
              ),
          // --- END DYNAMIC Button ---
          // Add the Call button
          IconButton(
            icon: const Icon(Icons.call_outlined, color: Colors.white), // White icon
            tooltip: 'chat.start_audio_call'.tr(),
            onPressed: () async { 
              HapticUtils.lightTap();
              AppLogger.d('Call button pressed!');
              
              // --- Refactored Call Initiation Logic ---
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              String currentUserName = 'User'; // Default name
              
              // 1. Validate User and Partner IDs
              if (currentUserId == null) {
                 AppLogger.e("Error: Cannot start call, user not logged in.");
                 DialogUtils.showMessageDialog(context: context, title: 'chat.error'.tr(), message: 'chat.auth_required'.tr());
                 return;
              }
              
              // Attempt to fetch user profile for the name
              try {
                final profileService = ref.read(userProfileServiceProvider);
                final profileMap = await profileService.getUserProfile(currentUserId);
                if (profileMap != null) {
                  final currentUserProfile = UserModel.User.fromMap(profileMap);
                  currentUserName = currentUserProfile.fullName; // Use fullName
                } else {
                   AppLogger.w("Warning: Could not fetch user profile to get caller name.");
                }
              } catch (e) {
                 AppLogger.e("Error fetching user profile for caller name: $e");
                 // Proceed with default name
              }
              
              final String partnerId = _chatPartnerId;
              final String partnerName = _displayPartnerName;
              
              if (partnerId == 'default_partner') {
                 AppLogger.e("Error: Cannot start call, invalid partner ID.");
                 DialogUtils.showMessageDialog(context: context, title: 'chat.error'.tr(), message: 'chat.invalid_contact'.tr());
                 return;
              }

              // 2. Call the Chat Service to start the call
              final chatService = ref.read(chatServiceProvider);
              String? callId; // Initialize callId as nullable
              try {
                 callId = await chatService.startAudioCall(
                    callerId: currentUserId,
                    callerName: currentUserName, // Use fetched/default name
                    calleeId: partnerId,
                    calleeName: partnerName,
                 );
              } catch (e) {
                  AppLogger.e("Error occurred while calling chatService.startAudioCall: $e");
                  // Error is already printed within the service, show generic message
                  DialogUtils.showMessageDialog(context: context, title: 'chat.call_error'.tr(), message: 'chat.call_failed'.tr());
                  return;
              }
              
              // 3. Handle the result from the service
              if (callId != null) {
                AppLogger.d("Call initiated successfully by service. Call ID: $callId");
                // TODO: (Optional) Send FCM data message to callee

                // Navigate to Call Screen
                context.pushNamed(
                  RouteNames.callScreen,
                  extra: {
                    'callId': callId,
                    'partnerName': partnerName, // Pass partner name
                    'isCaller': true,
                  },
                );
              } else {
                 // Service returned null, meaning Firestore write failed
                 AppLogger.e("Call initiation failed (service returned null).");
                 DialogUtils.showMessageDialog(context: context, title: 'chat.call_error'.tr(), message: 'chat.call_failed'.tr());
              }
              // --- End Refactored Call Initiation Logic ---
            },
          ),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        // --- Wrap body content with GestureDetector --- 
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside the TextField
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
          },
        child: Column(
          children: [
              // Messages list (Expanded remains inside Column)
            Expanded(
              child: Container(
                // Use theme's scaffold background color for consistency
                color: Theme.of(context).scaffoldBackgroundColor, 
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                          ? Center(child: Text('chat.no_messages'.tr()))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                                final currentUserId = FirebaseAuth.instance.currentUser?.uid; 
                                final isMe = message.senderId == currentUserId;
                              bool showDateHeader = false;
                              if (index == 0 ||
                                  !_isSameDay(
                                      _messages[index - 1].createdAt, message.createdAt)) {
                                showDateHeader = true;
                              }
                              return Column(
                                children: [
                                  if (showDateHeader)
                                    _DateHeader(date: message.createdAt, formatDate: _formatDateHeader),
                                  _MessageBubble(
                                    message: message,
                                    isMe: isMe,
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ),
              // Input Area (remains at the bottom of the Column)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor, // Use theme card color
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Attach button (conditional based on recording state)
                  _isRecording 
                    ? IconButton(
                        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), 
                        tooltip: 'common.cancel'.tr(),
                        onPressed: () {
                            // <<< Add Haptic Tap >>>
                            HapticUtils.lightTap();
                            _stopRecording(cancelled: true);
                        }, // Cancel recording
                      )
                    : IconButton(
                        icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                        tooltip: 'common.attach'.tr(),
                        onPressed: () {
                            // <<< Add Haptic Tap >>>
                            HapticUtils.lightTap();
                            _showAttachmentOptions(context);
                        }, // Show attachment options
                      ),
                  // Text input field (remains mostly the same)
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: () { // Use a function to determine hintText dynamically
                          if (_isRecording) {
                            final formattedDuration = '${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}';
                            // Ensure the key 'chat.recording' in your translation files has "{}" placeholder
                            return 'chat.recording'.tr(args: [formattedDuration]); 
                          } else {
                            return 'chat.send_message'.tr();
                          }
                        }(), // Immediately invoke the function
                        hintStyle: TextStyle(color: Theme.of(context).hintColor),
                        filled: true,
                        fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? AppColors.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none, 
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor.withAlpha(128)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      ),
                      enabled: !_isRecording, // Disable TextField while recording
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      minLines: 1,
                      maxLines: 5,
                      // Add text direction to support RTL languages properly
                      textDirection: Directionality.of(context),
                      // Ensure text alignment matches text direction
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send or Record button (using onTap)
                  isTextFieldEmpty
                      ? FloatingActionButton(
                          mini: true,
                          tooltip: _isRecording ? 'chat.stop_recording'.tr() : 'chat.record_voice'.tr(),
                          onPressed: () {
                            // <<< Add Haptic Tap >>>
                            HapticUtils.lightTap();
                            if (_isRecording) {
                              _stopRecording(cancelled: false); // Stop and send
                            } else {
                              _startRecording(); // Start recording
                            }
                          },
                          backgroundColor: _isRecording ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                          elevation: 1,
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic, // Change icon based on state
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 20,
                          ),
                        )
                      : FloatingActionButton(
                          // Standard Send Button
                          mini: true,
                          tooltip: 'chat.send'.tr(),
                          onPressed: () {
                              // <<< Add Haptic Tap >>>
                              HapticUtils.lightTap();
                              _sendMessage();
                          },
                          backgroundColor: AppColors.primary,
                          elevation: 1,
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                ],
              ),
            ),
          ],
        ),
        ),
        // --- End GestureDetector Wrap ---
      ),
    );
  }

  // --- Intro Card Implementation - REVISED TO MATCH MODEL ---
  Widget _buildIntroCard() {
    if (_patientData == null) return const SizedBox.shrink(); 
    final patient = _patientData!;
    final age = patient.age;
    final theme = Theme.of(context); // <<< Get Theme

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8), 
      // elevation: 4.0, // <<< Reduce elevation
      elevation: 1.5,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // <<< Add border
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // Slightly larger radius
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(100), width: 1.0)
      ),
      clipBehavior: Clip.antiAlias, 
      // color: theme.colorScheme.surfaceContainerHighest, // <<< Set solid background color
      color: theme.colorScheme.surface, // Use surface for better contrast with chat bg
      child: Container(
         // decoration: BoxDecoration( // <<< Remove gradient
         //   gradient: LinearGradient(
         //     colors: [AppColors.primary.withAlpha(26), AppColors.accent.withAlpha(26), Colors.white.withAlpha(204)],
         //     begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.7, 1.0]
         //   ),
         // ),
         padding: const EdgeInsets.all(16.0),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             // Header with Dismiss
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Text('Patient Introduction', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('Patient Introduction', // <<< Use theme color
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.primary
                    )
                  ),
                  IconButton(
                    // icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20), padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant, size: 20), // <<< Use theme color
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(), tooltip: 'Dismiss Introduction', onPressed: _dismissIntro,
                  )
                ],
             ),
             // const Divider(height: 16),
             Divider(height: 16, thickness: 0.5, color: theme.dividerColor.withAlpha(100)), // <<< Use theme divider color

             // Basic Info Row with Avatar
             Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   CircleAvatar(
                     radius: 28,
                    //  backgroundColor: AppColors.primary.withAlpha(51),
                     backgroundColor: theme.colorScheme.primaryContainer, // <<< Use theme color
                     child: Text( // Always show initial
                       patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                      //  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)
                       style: TextStyle( // <<< Use theme color
                         fontSize: 24, 
                         fontWeight: FontWeight.bold, 
                         color: theme.colorScheme.onPrimaryContainer
                       )
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(patient.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), // <<< Use titleLarge
                         if (age != null || patient.gender != null)
                           Padding(
                             padding: const EdgeInsets.only(top: 4.0),
                             child: Text(
                               '${patient.gender ?? ''}${patient.gender != null && age != null ? ', ' : ''}${age != null ? '$age years old' : ''}', 
                              //  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimaryDark)
                               style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) // <<< Use theme color
                             ),
                           ),
                       ],
                     ),
                   ),
                ],
             ),
              const SizedBox(height: 12), 

             // --- ADDED: Vitals & Location Row --- 
             _buildVitalsLocationRow(patient),
             const SizedBox(height: 12), // <<< Adjusted spacing
             // --- END: Vitals & Location Row ---

             // Conditions Section
             if (patient.conditions.isNotEmpty)
               _buildIntroSection(context, title: 'Conditions', icon: Icons.monitor_heart_outlined, items: patient.conditions),
               
             // Other Conditions Section
             if (patient.otherConditions != null && patient.otherConditions!.isNotEmpty)
               _buildIntroSection(context, title: 'Other Conditions', icon: Icons.help_outline_rounded, items: [patient.otherConditions!]),

             // Surgical History Section
             if (patient.surgicalHistory != null && patient.surgicalHistory!.toLowerCase() != 'none')
               _buildIntroSection(context, title: 'Surgical History', icon: Icons.content_cut_rounded, items: [patient.surgicalHistory!]), // <<< Changed Icon
               
             // Current Medications Section
             if (patient.medications != null && patient.medications!.toLowerCase() != 'none')
               _buildIntroSection(context, title: 'Current Medications', icon: Icons.medication_outlined, items: [patient.medications!]),

             // Allergies Section
             if (patient.allergies != null && patient.allergies!.toLowerCase() != 'none')
              //  _buildIntroSection(context, title: 'Reported Allergies', icon: Icons.warning_amber_rounded, items: [patient.allergies!], itemColor: Colors.red.shade700),
               _buildIntroSection(context, title: 'Reported Allergies', icon: Icons.warning_amber_rounded, items: [patient.allergies!], useErrorColor: true), // <<< Use theme error color
               
             // Documents Section
             if (patient.documents.isNotEmpty)
               _buildIntroSection(context, title: 'Uploaded Documents', icon: Icons.attach_file_outlined, isDocumentList: true, documentItems: patient.documents),
           ],
         ),
      ),
    );
  }

  // --- ADDED: Helper for Vitals & Location Row --- 
  Widget _buildVitalsLocationRow(PatientOnboardingData patient) {
     final theme = Theme.of(context); // <<< Get Theme
     Widget buildItem(IconData icon, String? value) {
       if (value == null || value.isEmpty) return const SizedBox.shrink();
       return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
          //  Icon(icon, size: 16, color: AppColors.textSecondary),
           Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant), // <<< Use theme color & size
           const SizedBox(width: 4),
          //  Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
           Text(value, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)), // <<< Use theme style/color
           const SizedBox(width: 12), // Space between items
         ],
       );
     }

     return Wrap(
       spacing: 4.0, // Minimal spacing between items in a row
       runSpacing: 4.0, // Space if wraps to next line
       children: [
          if (patient.height != null) buildItem(Icons.height, patient.height),
          if (patient.weight != null) buildItem(Icons.monitor_weight_outlined, patient.weight),
          // <<< Simplify location display >>>
          // if (patient.country != null) buildItem(Icons.public_outlined, '${patient.city ?? ''}${patient.city != null ? ', ' : ''}${patient.country}'),
          if (patient.city != null || patient.country != null)
             buildItem(Icons.location_on_outlined, '${patient.city ?? ''}${patient.city != null && patient.country != null ? ', ' : ''}${patient.country ?? ''}'),
       ],
     );
  }
  // --- END: Helper for Vitals & Location Row --- 

  // Helper to build sections within the intro card
  Widget _buildIntroSection(BuildContext context, {
    required String title,
    required IconData icon,
    List<String>? items,
    List<Map<String, dynamic>>? documentItems, // Allow dynamic map
    bool isDocumentList = false,
    // Color? itemColor, // <<< Remove explicit itemColor
    bool useErrorColor = false, // <<< Add flag for error color
  }) {
    final theme = Theme.of(context); // <<< Get Theme
    // <<< Adjusted logic to handle different types correctly >>>
    final List<dynamic> contentItems = isDocumentList 
        ? (documentItems?.map((e) => e).toList() ?? []) // Keep maps for documents
        : (items ?? []); // Keep strings for other items

    // <<< Log received document items >>>
    if (isDocumentList) {
      AppLogger.d("[DEBUG Docs UI] _buildIntroSection received documentItems: $documentItems"); 
    }
    // <<< End log >>>

    if (contentItems.isEmpty) return const SizedBox.shrink();

    // <<< Determine chip colors based on flag >>>
    final Color chipBackgroundColor = useErrorColor 
        ? theme.colorScheme.errorContainer 
        : theme.colorScheme.secondaryContainer;
    final Color chipForegroundColor = useErrorColor 
        ? theme.colorScheme.onErrorContainer 
        : theme.colorScheme.onSecondaryContainer;
    final Color iconColor = useErrorColor
        ? theme.colorScheme.error
        : theme.colorScheme.primary; // Or theme.colorScheme.secondary

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0), // <<< Consistent bottom padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon(icon, size: 18, color: itemColor ?? AppColors.primaryDark),
              Icon(icon, size: 18, color: iconColor), // <<< Use determined icon color
              const SizedBox(width: 8),
              // Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), // <<< Use theme style
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0, // Horizontal spacing between chips
            runSpacing: 6.0, // Vertical spacing if chips wrap
            children: contentItems.map((item) { // Item can be String or Map
              String itemName;
              String? itemUrl;
              String itemType = 'text'; // Default

              // <<< Define helper function/variables for robust image check >>>
              bool isConsideredImage = false;
              String lowerCaseName = '';
              String lowerCaseUrl = '';
              String lowerCaseType = '';

              if (isDocumentList && item is Map<String, dynamic>) { // Use dynamic map check
                itemName = item['name']?.toString() ?? 'Unknown Document';
                itemUrl = item['url']?.toString();
                itemType = item['type']?.toString() ?? 'document'; // Assuming type is stored

                // Prepare lowercase versions for checking
                lowerCaseName = itemName.toLowerCase();
                lowerCaseUrl = itemUrl?.toLowerCase() ?? '';
                lowerCaseType = itemType.toLowerCase();

                // Check type and common extensions
                isConsideredImage = lowerCaseType == 'image' ||
                                   lowerCaseName.endsWith('.png') || lowerCaseName.endsWith('.jpg') || lowerCaseName.endsWith('.jpeg') || lowerCaseName.endsWith('.gif') || lowerCaseName.endsWith('.webp') ||
                                   lowerCaseUrl.contains('.png?') || lowerCaseUrl.contains('.jpg?') || lowerCaseUrl.contains('.jpeg?') || lowerCaseUrl.contains('.gif?') || lowerCaseUrl.contains('.webp?'); // Check before query params

                // <<< Log image details >>>
                if (isConsideredImage) {
                  AppLogger.d('[DEBUG Docs UI] Image found (by type/ext): Name=$itemName, URL=$itemUrl, Type=$itemType');
                } else if (itemUrl != null) {
                  AppLogger.d('[DEBUG Docs UI] Non-image document found: Name=$itemName, URL=$itemUrl, Type=$itemType');
                }
                // <<< End log >>>

              } else if (item is String) {
                itemName = item;
                // Not a document map, cannot be an image in this context
                isConsideredImage = false;
              } else {
                return const SizedBox.shrink(); // Skip invalid items
              }

              if (isDocumentList) {
                 // --- Document Item Handling ---
                 // Only render non-image documents as chips here
                 // if (itemType != 'image' && itemUrl != null) { // <<< OLD Check
                 if (!isConsideredImage && itemUrl != null) { // <<< NEW Check: Build chip if NOT an image
                   IconData docIcon = Icons.description_outlined;
                   // Use specific icon only for PDF among non-images
                   if (lowerCaseType == 'pdf' || lowerCaseName.endsWith('.pdf')) {
                       docIcon = Icons.picture_as_pdf_outlined;
                   }
                   // else if (itemType == 'image') docIcon = Icons.image_outlined; // Handled by GridView now

                   return ActionChip(
                       avatar: Icon(docIcon, size: 16, color: chipForegroundColor), // <<< Use themed color
                       label: Text(itemName, style: TextStyle(color: chipForegroundColor)), // <<< Use themed color
                       onPressed: () {
                         // TODO: Implement document view logic for non-images (using itemUrl)
                         AppLogger.d('Tapped on document: $itemName - URL: $itemUrl');
                         // Potentially open with url_launcher or a specific PDF viewer
                       },
                       backgroundColor: chipBackgroundColor, // <<< Use themed color
                       side: BorderSide.none, // <<< Remove border
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       labelPadding: const EdgeInsets.only(left: 4), // Space between icon and text
                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                   );
                 } else {
                    // If it's an image or URL is null, render nothing here (handled by GridView below)
                    return const SizedBox.shrink(); 
                 }
                 // --- End Document Handling ---
              } else {
                 // --- Non-Document Item (Medical history, allergies, etc.) --- 
                //  return Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                //     decoration: BoxDecoration(
                //       color: (itemColor ?? AppColors.primary).withAlpha(26),
                //       borderRadius: BorderRadius.circular(15),
                //       border: Border.all(color: (itemColor ?? AppColors.primary).withAlpha(77))
                //     ),
                //     child: Text(
                //       itemName,
                //       style: TextStyle(
                //         color: itemColor ?? AppColors.primary,
                //         fontSize: 13,
                //         fontWeight: FontWeight.w500,
                //       ),
                //     ),
                //  );
                // --- Use Chip for better consistency --- 
                 return Chip(
                    label: Text(itemName),
                    backgroundColor: chipBackgroundColor,
                    labelStyle: TextStyle(color: chipForegroundColor, fontSize: 13, fontWeight: FontWeight.w500),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                 );
                 // --- End Use Chip --- 
              }
            }).where((widget) => widget is! SizedBox || (widget is SizedBox && widget.height != 0)).toList(), // Filter out empty SizedBoxes
          ),

          // --- ADD: GridView for Images ---
          if (isDocumentList && documentItems != null)
            Builder( // Use Builder to get context for Navigator
              builder: (context) {
                // final imageItems = documentItems.where((item) => item['type'] == 'image' && item['url'] != null).toList(); // <<< OLD Filter
                // <<< NEW Filter using broader image detection >>>
                final imageItems = documentItems.where((item) {
                   final type = item['type']?.toString().toLowerCase();
                   final name = item['name']?.toString().toLowerCase() ?? '';
                   final url = item['url']?.toString().toLowerCase() ?? '';
                   return (type == 'image' ||
                           name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.gif') || name.endsWith('.webp') ||
                           url.contains('.png?') || url.contains('.jpg?') || url.contains('.jpeg?') || url.contains('.gif?') || url.contains('.webp?')) && 
                          item['url'] != null; // Ensure URL is not null
                }).toList();
                
                AppLogger.d("[DEBUG Docs UI] Filtered image items for GridView: ${imageItems.length}");

                if (imageItems.isEmpty) return const SizedBox.shrink();

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: imageItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                  ),
                  itemBuilder: (context, index) {
                    final imageItem = imageItems[index];
                    final imageUrl = imageItem['url'] as String; // Already checked for null

                    return GestureDetector(
                      onTap: () {
                        AppLogger.i("Tapping image grid item: $imageUrl");
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenImageViewer(imagePath: imageUrl),
                          ),
                        );
                      },
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container( // Add a background during loading
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              AppLogger.e("Error loading grid image: $imageUrl, Error: $error");
                              return Container( // Add a background for error
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          // --- END: GridView for Images ---
        ],
      ),
    );
  }

  // --- Info Sheet Implementation - REVISED TO MATCH MODEL ---
  void _showPatientInfoSheet(PatientOnboardingData data) {
    final age = data.age; 

     showModalBottomSheet(
        context: context,
        isScrollControlled: true, 
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        backgroundColor: AppColors.surface, 
        builder: (context) {
           return DraggableScrollableSheet(
             expand: false, initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.9, 
             builder: (_, scrollController) {
                 return Container(
                    child: ListView( 
                     controller: scrollController,
                     padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16), 
                      children: [
                         // Drag Handle
                          Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                         
                         // Header with Basic Info
                         Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 32, 
                                backgroundColor: AppColors.primary.withAlpha(51),
                                child: Text( // Always show initial
                                  data.name.isNotEmpty ? data.name[0].toUpperCase() : 'P',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                                    if (age != null || data.gender != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '${data.gender ?? ''}${data.gender != null && age != null ? ', ' : ''}${age != null ? '$age years old' : ''}', 
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                         const Divider(height: 24),
                         
                         // --- ADDED: Vitals & Location to Sheet --- 
                         Padding(
                           padding: const EdgeInsets.only(bottom: 12.0),
                           child: _buildVitalsLocationRow(data),
                         ),
                         // --- END: Vitals & Location to Sheet ---

                         // Detailed Sections
                         if (data.conditions.isNotEmpty)
                            _buildIntroSection(context, title: 'Conditions', icon: Icons.monitor_heart_outlined, items: data.conditions),
                         if (data.otherConditions != null && data.otherConditions!.isNotEmpty)
                           _buildIntroSection(context, title: 'Other Conditions', icon: Icons.help_outline_rounded, items: [data.otherConditions!]),
                         if (data.surgicalHistory != null && data.surgicalHistory!.toLowerCase() != 'none')
                           _buildIntroSection(context, title: 'Surgical History', icon: Icons.healing_outlined, items: [data.surgicalHistory!]),
                           if (data.medications != null && data.medications!.toLowerCase() != 'none')
                             _buildIntroSection(context, title: 'Current Medications', icon: Icons.medication_outlined, items: [data.medications!]),
                           if (data.allergies != null && data.allergies!.toLowerCase() != 'none')
                             _buildIntroSection(context, title: 'Reported Allergies', icon: Icons.warning_amber_rounded, items: [data.allergies!], useErrorColor: true), // <<< Use flag instead of itemColor
                           if (data.documents.isNotEmpty)
                             _buildIntroSection(context, title: 'Uploaded Documents', icon: Icons.attach_file_outlined, isDocumentList: true, documentItems: data.documents),
                           
                         const SizedBox(height: 20), 
                      ],
                   ),
                 );
              },
           );
         },
     );
  }
}

// --- Helper Widgets ---

// Date Header Widget
class _DateHeader extends StatelessWidget {
  final DateTime date;
  final String Function(DateTime) formatDate; // Function to format the date

  const _DateHeader({required this.date, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(38),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Text(
            formatDate(date), // Use the passed formatting function
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// Message Bubble Widget
// <<< Change to ConsumerStatefulWidget >>>
class _MessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  // <<< Change to ConsumerState >>>
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

// <<< Change to ConsumerState and add AutomaticKeepAliveClientMixin >>>
class _MessageBubbleState extends ConsumerState<_MessageBubble> with AutomaticKeepAliveClientMixin<_MessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;
  // <<< ADD Loading and Downloaded States >>>
  bool _isLoadingAudio = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  String? _localFilePath;

  // State for PDF thumbnail
  Uint8List? _pdfThumbnailBytes;
  bool _isLoadingThumbnail = false;
  bool _isPdf = false; // Flag to know if we should attempt loading

  // <<< Add wantKeepAlive getter >>>
  @override
  bool get wantKeepAlive => true; // Keep the state alive!

  @override
  void initState() {
    super.initState();
    // Pre-load duration for voice messages
    if (widget.message.type == MessageType.voice) {
      // Check if file exists locally first
      _checkIfVoiceFileExists();

      // <<< FIX: Try setting duration from metadata FIRST >>>
      final durationMs = widget.message.metadata?['duration_ms'];
      if (durationMs is int && durationMs > 0) {
          _totalDuration = Duration(milliseconds: durationMs);
          AppLogger.d("[DEBUG InitState] Set initial duration from metadata: $_totalDuration");
      } else {
           AppLogger.d("[DEBUG InitState] No valid duration in metadata.");
      }

      // Then, initialize player if a source exists locally (it might update duration again)
      if (_isDownloaded || widget.message.localFilePath != null) {
        _initAudioPlayer();
      } else {
         AppLogger.d("[DEBUG InitState] No local audio source for player init - will need download.");
      }
    }
    
    // Check and generate PDF thumbnail
    if (widget.message.type == MessageType.document) {
       // <<< FIX: Detect PDF from local path, mediaUrl, or filename >>>
       bool detectedPdf = false;
       if (widget.message.localFilePath != null && 
        widget.message.localFilePath!.toLowerCase().endsWith('.pdf')) {
           detectedPdf = true;
       } else if (widget.message.mediaUrl != null && 
                  widget.message.mediaUrl!.toLowerCase().contains('.pdf')) { // Check if URL contains .pdf
           // Basic check, Firebase URLs often have .pdf before query params
           detectedPdf = true; 
       } else if (widget.message.content.toLowerCase().endsWith('.pdf')) { // Fallback to filename
            detectedPdf = true;
       }

       if (detectedPdf) {
      _isPdf = true; 
           // Call thumbnail generation regardless of local/network for now
           // (We will adapt _generatePdfThumbnail next)
      _generatePdfThumbnail();
       }
    }
  }

  // Check if voice file exists in app documents directory
  Future<void> _checkIfVoiceFileExists() async {
    if (widget.message.type != MessageType.voice) return;
    
    // First check for an existing localFilePath
    if (widget.message.localFilePath != null) {
      final file = File(widget.message.localFilePath!);
      if (await file.exists()) {
        setState(() {
          _isDownloaded = true;
          _localFilePath = widget.message.localFilePath;
        });
        return;
      }
    }
    
    // If message has a mediaUrl, check if it's already cached
    if (widget.message.mediaUrl != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final filename = widget.message.mediaUrl!.split('/').last.split('?').first;
      final filepath = '${appDir.path}/voice_messages/$filename';
      
      final file = File(filepath);
      if (await file.exists()) {
        setState(() {
          _isDownloaded = true;
          _localFilePath = filepath;
        });
      }
    }
  }

  // Download voice message
  Future<void> _downloadVoiceMessage() async {
    if (widget.message.mediaUrl == null) {
      AppLogger.d("Cannot download voice message: No URL");
      return;
    }
    
    setState(() {
      _isDownloading = true;
    });
    
    try {
      // Create directory if it doesn't exist
      final appDir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${appDir.path}/voice_messages');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      
      // Extract filename from URL
      final filename = widget.message.mediaUrl!.split('/').last.split('?').first;
      final filepath = '${voiceDir.path}/$filename';
      
      // Download the file
      final response = await http.get(Uri.parse(widget.message.mediaUrl!));
      if (response.statusCode == 200) {
        final file = File(filepath);
        await file.writeAsBytes(response.bodyBytes);
        
        // <<< Call _initAudioPlayer BEFORE setState >>>
        // Initialize audio player immediately after download completes
        _localFilePath = filepath; // Set local path needed by _initAudioPlayer
        await _initAudioPlayer(); 
        
        // Now update the UI state
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
          // _localFilePath = filepath; // Already set above
        });
        
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e("Error downloading voice message: $e");
      setState(() {
        _isDownloading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download voice message'))
        );
      }
    }
  }

  Future<void> _initAudioPlayer() async {
    // Cancel any existing subscriptions before setting up new ones
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    
    // Determine audio source
    String? sourcePathToUse = _localFilePath ?? widget.message.localFilePath;
    if (sourcePathToUse == null && widget.message.mediaUrl != null && _isDownloaded) {
      // If file was downloaded but path not stored in state yet
      final appDir = await getApplicationDocumentsDirectory();
      final filename = widget.message.mediaUrl!.split('/').last.split('?').first;
      sourcePathToUse = '${appDir.path}/voice_messages/$filename';
    }
    
    if (sourcePathToUse == null) {
      AppLogger.d("Cannot initialize player: No audio source path available");
      return;
    }
    
    // Listen to states: playing, paused, stopped
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      // Add mounted check
      if (!mounted) return;
      AppLogger.d("[DEBUG AudioPlayer] State changed: $state");
      
      // Update playing state and immediately stop loading when state changes
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoadingAudio = false; // Always reset loading state on any state change
      });
      
      // Report stopped on relevant state changes
      if (state == PlayerState.stopped || state == PlayerState.paused || state == PlayerState.completed) {
        ref.read(chatPlaybackProvider).reportStopped(widget.message.id);
      }
    });

    // Listen to audio duration
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      AppLogger.d("[DEBUG AudioPlayer] Duration changed: $duration");
      setState(() {
        _totalDuration = duration;
        _isLoadingAudio = false; // Stop loading once we get duration
      });
    });

    // Listen to audio position - critical for slider movement
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      
      // Ensure loading state is off when we start getting position updates
      if (_isLoadingAudio) {
        setState(() {
          _isLoadingAudio = false;
          _currentPosition = position;
        });
      } else {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    
    // Listen for when audio completes
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (!mounted) return;
      AppLogger.d("[DEBUG AudioPlayer] Playback Complete");
      
      ref.read(chatPlaybackProvider).reportStopped(widget.message.id);
      setState(() {
        _currentPosition = Duration.zero; // Reset position
        _isPlaying = false;
        _isLoadingAudio = false; // Ensure loading stops on completion
      });
    });
    
    // Set up the audio source
    try {
      // For downloaded/local files, always use DeviceFileSource
      Source source = DeviceFileSource(sourcePathToUse);
      
      // Set source but don't play yet
      await _audioPlayer.setSource(source);
      
      // Try to get duration immediately after setting source
      Duration? duration = await _audioPlayer.getDuration();
      if (duration != null && mounted) {
        setState(() { 
          _totalDuration = duration;
        });
      } else if (widget.message.metadata?['duration_ms'] != null && mounted) {
        // Fallback to metadata if getDuration fails
        setState(() { 
          _totalDuration = Duration(milliseconds: widget.message.metadata!['duration_ms']); 
        });
      }
    } catch (e) {
      AppLogger.e("Error setting audio source or getting duration: $e");
      // Fallback to metadata if setting source fails
      if (widget.message.metadata?['duration_ms'] != null && mounted) {
        setState(() { 
          _totalDuration = Duration(milliseconds: widget.message.metadata!['duration_ms']); 
        });
      }
      
      // Reset loading state on error
      if (mounted) {
        setState(() {
          _isLoadingAudio = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Release all sources and dispose the player.
    // <<< REMOVE unsafe ref access during dispose >>>
    // final playbackService = ref.read(chatPlaybackProvider); 
    // if (playbackService.isPlaying(widget.message.id)) {
    //    playbackService.reportStopped(widget.message.id);
    // }
     _durationSubscription?.cancel();
     _positionSubscription?.cancel();
     _playerCompleteSubscription?.cancel();
     _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (!mounted) return;

    // If file is not downloaded yet, don't try to play
    if (!_isDownloaded && widget.message.localFilePath == null) {
      AppLogger.d("Cannot play: audio file not downloaded");
      return;
    }

    // Get playback service
    final playbackService = ref.read(chatPlaybackProvider);

    if (_isPlaying) {
      // Already playing - just pause
      await _audioPlayer.pause();
      playbackService.reportStopped(widget.message.id);
      // State update handled by onPlayerStateChanged listener
    } else {
      // --- Start Playback Logic ---
      setState(() {
        _isLoadingAudio = true; 
      });
      
      // Request exclusive playback
      playbackService.requestPlay(widget.message.id, () { 
        if (mounted) {
          _audioPlayer.pause(); 
        }
      });

      try {
        // Check if player has a source and is properly initialized
        // If not, re-initialize before attempting to play/resume
        if (_audioPlayer.source == null) {
          AppLogger.d("[DEBUG _togglePlayPause] Player source is null. Re-initializing...");
          await _initAudioPlayer(); // Re-initialize (sets source)
          // After init, source should be set. Now play directly.
          if (_audioPlayer.source != null) {
             await _audioPlayer.play(_audioPlayer.source!); // Play from the start
          } else {
            // If init still failed to set source, throw error
            throw Exception("Failed to initialize player source.");
          }
        } else {
          // Source exists, just resume playback
          await _audioPlayer.resume();
        }
        // Loading state will be turned off by onPlayerStateChanged/onPositionChanged listeners
      } catch (e) {
        AppLogger.e("Error playing/resuming audio: $e");
        if (mounted) {
          setState(() => _isLoadingAudio = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio message'))
        );
      }
      // --- End Playback Logic ---
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // <<< Call super.build(context) for AutomaticKeepAliveClientMixin >>>
    super.build(context); 
    
    // Get the current locale and check if it's Arabic for RTL
    final currentLocale = context.locale.languageCode;
    final isRtl = currentLocale == 'ar';
    
    // Adjust alignment based on RTL and sender
    final alignment = widget.isMe 
        ? (isRtl ? Alignment.centerLeft : Alignment.centerRight)
        : (isRtl ? Alignment.centerRight : Alignment.centerLeft);
    
    // Use theme colors instead of hardcoded AppColors
    final color = widget.isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor;
    final textColor = widget.isMe 
        ? Theme.of(context).colorScheme.onPrimary 
        : Theme.of(context).colorScheme.onSurface; // Use onSurface for text on card background
    final iconColor = widget.isMe ? Theme.of(context).colorScheme.onPrimary.withAlpha(179) : Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    
    // Adjust bubble radius based on text direction and sender
    final bubbleRadius = isRtl
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: widget.isMe ? Radius.zero : const Radius.circular(16),
            bottomRight: widget.isMe ? const Radius.circular(16) : Radius.zero,
          )
        : BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: widget.isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: widget.isMe ? Radius.zero : const Radius.circular(16),
          );

    Widget messageContent;
    switch (widget.message.type) {
      case MessageType.text:
        messageContent = Text(
          widget.message.content,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        );
        break;
      case MessageType.image:
        // --- Image Placeholder Implementation --- 
        const double placeholderSize = 150.0; // Define fixed size

        Widget imageContent = const SizedBox.shrink(); // Default empty
        Widget indicatorWidget = const SizedBox.shrink(); 

        if (widget.message.mediaUrl != null && widget.message.mediaUrl!.isNotEmpty) {
           // Network image available
           imageContent = Image.network(
              widget.message.mediaUrl!,
              width: placeholderSize,
              height: placeholderSize,
              fit: BoxFit.cover, // Cover the placeholder area
              // --- UPDATED loadingBuilder for Fade-In --- 
              loadingBuilder: (context, child, loadingProgress) {
                // Determine if loading is complete
                final isLoaded = loadingProgress == null;
                
                // Always return the placeholder structure
                return Container(
                  width: placeholderSize,
                  height: placeholderSize,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], // Placeholder background
                    borderRadius: bubbleRadius, // Match bubble radius
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Show loading indicator only when NOT loaded
                      if (!isLoaded)
                        CircularLoadingIndicator(
                          strokeWidth: 2.0,
                          color: Colors.white70,
                          showProgress: true,
                          value: loadingProgress?.expectedTotalBytes != null
                              ? loadingProgress!.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      // The actual image, faded in
                      AnimatedOpacity(
                        opacity: isLoaded ? 1.0 : 0.0, // Fade in when loaded
                        duration: const Duration(milliseconds: 300), // Adjust duration as needed
                        child: child, // The loaded image widget passed by Image.network
                      ),
                    ],
                  ),
                );
              },
              // --- END UPDATED loadingBuilder --- 
              errorBuilder: (context, error, stackTrace) {
                AppLogger.e("Error loading network image: $error");
                // Show error icon if network fails
                indicatorWidget = const Center(
                   child: Icon(Icons.error_outline, color: Colors.white70, size: 30)
                );
                return const SizedBox.shrink(); // Return empty while indicator is shown
              },
           );
        } else if (widget.message.localFilePath != null) {
           // Local file path available (uploading)
            File imageFile = File(widget.message.localFilePath!);
            if (imageFile.existsSync()) { // Check if file exists before trying to display
              imageContent = Image.file(
                imageFile,
                width: placeholderSize,
                height: placeholderSize,
                fit: BoxFit.cover,
                 errorBuilder: (context, error, stackTrace) {
                    AppLogger.e("Error loading local file image: $error");
                     indicatorWidget = const Center(
                        child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 30)
                     );
                    return const SizedBox.shrink(); // Return empty while indicator is shown
                 },
              );
              // Show upload indicator for local file
              indicatorWidget = Center(
                 child: Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     color: Colors.black.withAlpha(128),
                     shape: BoxShape.circle,
            ),
                   child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 24)
                 )
              );
            } else {
                AppLogger.d("Local image file not found at: ${widget.message.localFilePath}");
                indicatorWidget = const Center(
                   child: Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 30)
                );
            }
        } else {
          // Neither URL nor local path - show placeholder icon
          indicatorWidget = const Center(
             child: Icon(Icons.image_outlined, color: Colors.white70, size: 40)
          );
        }

        messageContent = GestureDetector(
                onTap: () {
            HapticUtils.lightTap(); // <-- Add haptics
            // Use URL if available, otherwise use local path
            final pathOrUrl = widget.message.mediaUrl ?? widget.message.localFilePath;
            if (pathOrUrl != null && pathOrUrl.isNotEmpty) {
              context.pushNamed(RouteNames.imageViewer, extra: pathOrUrl);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Image source not available.')),
                    );
                  }
                },
          child: Container(
            width: placeholderSize,
            height: placeholderSize,
            child: ClipRRect( // Clip everything to rounded corners
              borderRadius: bubbleRadius,
              child: Stack(
                fit: StackFit.expand, // Make stack children fill the container
                children: [
                  // Base Placeholder Background
                  Container(
                    color: Colors.grey[300], // Base color
                  ),
                  // The actual image (network or file)
                  imageContent, 
                  // Indicator (loading, upload, error, or initial icon)
                  indicatorWidget,
                ],
                ),
              ),
            ),
          );
        // --- End Image Placeholder Implementation ---
        break;
      case MessageType.document:
        // <<< Use same placeholder size as images >>>
        const double placeholderSize = 150.0; 
        
        if (_isPdf) {
          // --- PDF Preview Logic (with lazy generation & caching) ---
          Widget pdfPreviewContent;
          final cacheKey = widget.message.id; // Key for caching
          final cachedThumbnails = ref.watch(pdfThumbnailCacheProvider); // Watch the cache
          
          // <<< Check Cache First >>>
          if (cacheKey.isNotEmpty && cachedThumbnails.containsKey(cacheKey)) {
             AppLogger.d("[DEBUG Thumb Build] Using cached thumbnail for key: $cacheKey");
             pdfPreviewContent = Image.memory(
                cachedThumbnails[cacheKey]!,
                fit: BoxFit.cover,
                width: placeholderSize,
                height: placeholderSize,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white70)),
              );
          } 
          // <<< If not cached, proceed with generation/loading logic >>>
          else if (_pdfThumbnailBytes == null && !_isLoadingThumbnail) {
             AppLogger.d("[DEBUG Thumb Build] No cache. Triggering generation for key: $cacheKey");
             WidgetsBinding.instance.addPostFrameCallback((_) { 
                if (mounted) { 
                   _generatePdfThumbnail(); 
                } 
             });
             pdfPreviewContent = const Center(
               child: CircularLoadingIndicator(strokeWidth: 2.0, color: Colors.white70),
             );
          } 
          else if (_isLoadingThumbnail) {
             AppLogger.d("[DEBUG Thumb Build] Thumbnail is loading for key: $cacheKey");
             pdfPreviewContent = const Center(
              child: CircularLoadingIndicator(strokeWidth: 2.0, color: Colors.white70),
            );
          } else if (_pdfThumbnailBytes != null) {
             AppLogger.d("[DEBUG Thumb Build] Using generated (but not cached?) thumbnail for key: $cacheKey");
             pdfPreviewContent = Image.memory(
              _pdfThumbnailBytes!,
              fit: BoxFit.cover,
              width: placeholderSize,
              height: placeholderSize,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white70)),
            );
          } else {
             AppLogger.d("[DEBUG Thumb Build] Fallback icon for key: $cacheKey");
             pdfPreviewContent = Center(
              child: Icon(Icons.picture_as_pdf_outlined, size: 40, color: Colors.grey[600]),
            );
          }

          messageContent = GestureDetector(
            // <<< Restore original onTap with added logging >>>
            onTap: () {
              HapticUtils.lightTap(); // <-- Add haptics
              AppLogger.d("[DEBUG PDF Tap] onTap triggered.");
              final String? sourcePathOrUrl;
              final mediaUrl = widget.message.mediaUrl;
              final localPath = widget.message.localFilePath;
              AppLogger.d("[DEBUG PDF Tap] Media URL: $mediaUrl");
              AppLogger.d("[DEBUG PDF Tap] Local Path: $localPath");
              
              if (mediaUrl != null && mediaUrl.isNotEmpty) {
                AppLogger.d("[DEBUG PDF Tap] Using Media URL as source.");
                sourcePathOrUrl = mediaUrl;
              } else if (localPath != null && localPath.isNotEmpty) {
                AppLogger.d("[DEBUG PDF Tap] Using Local Path as source.");
                sourcePathOrUrl = localPath;
        } else {
                 AppLogger.d("[DEBUG PDF Tap] No valid source (URL or Path) found.");
                sourcePathOrUrl = null;
              }

              AppLogger.d("[DEBUG PDF Tap] Final sourcePathOrUrl: $sourcePathOrUrl");

              if(sourcePathOrUrl != null) {
                 AppLogger.d("[DEBUG PDF Tap] Attempting navigation to PDF viewer with: $sourcePathOrUrl");
                 context.pushNamed(
                   RouteNames.pdfViewer,
                   extra: sourcePathOrUrl, // Pass URL or Path
                 );
              } else {
                 AppLogger.d("[DEBUG PDF Tap] Navigation skipped because sourcePathOrUrl is null.");
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF source not available.')),
                 );
              }
            },
            // <<< Remove the simplified test logic >>>
            /* 
            onTap: () {
              AppLogger.d("[DEBUG PDF Tap] Inner GestureDetector Tapped!");
            }, 
            */
            child: Container(
              width: placeholderSize,
              height: placeholderSize,
              child: ClipRRect( 
                borderRadius: bubbleRadius, 
                child: Container( 
                  color: Colors.grey[300], 
                  child: pdfPreviewContent,
                ),
              ),
            ),
          );
        } else {
          // --- Non-PDF Document Logic (Keep existing icon + filename) ---
          Widget documentDisplay = Icon(Icons.insert_drive_file_outlined, color: textColor, size: 40);
          messageContent = Padding(
             padding: const EdgeInsets.all(4.0), // Keep padding for this row layout
             child: Row(
            mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  documentDisplay, 
              const SizedBox(width: 8),
                  Expanded( 
                child: Padding(
                      padding: const EdgeInsets.only(top: 4.0), 
                  child: Text(
                        widget.message.content, // Display filename
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14),
                        maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
              ),
              );
          // --- End Non-PDF Document Logic ---
        }
        break;
      case MessageType.voice:
        // Show appropriate content based on download state
        if (!_isDownloaded && widget.message.localFilePath == null && widget.message.mediaUrl != null) {
          // --- REDESIGNED Download State UI --- 
          messageContent = Row(
            mainAxisSize: MainAxisSize.min,
            // crossAxisAlignment: CrossAxisAlignment.start, // Default alignment
            children: [
              // Left side - Download button or loading indicator
              Container(
                width: 32, 
                height: 32,
                alignment: Alignment.center,
                child: _isDownloading
                  ? CircularLoadingIndicator(strokeWidth: 2, color: textColor)
                  : IconButton(
                      icon: const Icon(Icons.download_for_offline_outlined, size: 28), 
                      color: textColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Download Voice Message',
                      onPressed: () { // <-- Modify onPressed directly
                        HapticUtils.lightTap(); // <-- Add haptics
                        _downloadVoiceMessage();
                      },
                    ),
              ),
              const SizedBox(width: 8),
              // Right side - Now includes a disabled Slider
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.0), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // <<< REPLACE Waveform icon with disabled Slider >>>
                      SizedBox(
                        height: 30,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: textColor.withAlpha(128), // Faded thumb
                            overlayColor: Colors.transparent, // No overlay
                            activeTrackColor: textColor.withAlpha(77), // Faded track
                            inactiveTrackColor: textColor.withAlpha(77), // Faded track
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                            trackHeight: 2.0,
                          ),
                          child: Slider(
                            value: 0.0, // Always start at 0
                            min: 0.0,
                            max: (_totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1).toDouble(), 
                            onChanged: null, // Disable slider interaction
                          ),
                        ),
                      ),
                      // Duration display (Show 00:00 / Total Duration)
                      Text(
                        "00:00 / ${_formatDuration(_totalDuration)}",
                        style: TextStyle(color: iconColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          // --- END REDESIGNED Download State UI ---
        } else {
          // Show player when file is downloaded (Existing player UI)
          messageContent = Row(
            mainAxisSize: MainAxisSize.min,
            // crossAxisAlignment: CrossAxisAlignment.start, // Default alignment
            children: [
              Container( // Keep left button container as is
                width: 32, 
                height: 32,
                alignment: Alignment.center,
                child: _isLoadingAudio 
                  ? CircularLoadingIndicator(strokeWidth: 2, color: textColor)
                  : IconButton(
                      icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 32),
                      color: textColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _isLoadingAudio
                        ? null
                        : () { // <-- Modify onPressed directly
                            HapticUtils.lightTap(); // <-- Add haptics
                            _togglePlayPause();
                          },
                    ),
              ),
              const SizedBox(width: 8),
              // Right side - Column with slider and time display
              Expanded(
                // <<< ADD Padding to nudge content down >>>
                 child: Padding(
                   padding: const EdgeInsets.only(top: 2.0),
                   child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Slider (Active)
                      SizedBox(
                        height: 30,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: textColor.withAlpha(255),
                            overlayColor: textColor.withAlpha(38),
                            activeTrackColor: textColor.withAlpha(204),
                            inactiveTrackColor: textColor.withAlpha(102),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                            trackHeight: 2.0,
                          ),
                          child: Slider(
                            value: _currentPosition.inMilliseconds.toDouble().clamp(0.0, _totalDuration.inMilliseconds.toDouble()),
                            min: 0.0,
                            max: (_totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds : 1).toDouble(), 
                            onChanged: (_totalDuration > Duration.zero && !_isLoadingAudio)
                              ? (value) async {
                                  if (_isLoadingAudio) return;
                                  final position = Duration(milliseconds: value.toInt());
                                  await _audioPlayer.seek(position);
                                  if (mounted) {
                                    setState(() { _currentPosition = position; });
                                  } 
                                }
                              : null,
                          ),
                        ),
                      ),
                      // Time display (Current / Total)
                      Text(
                        "${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}",
                        style: TextStyle(color: iconColor, fontSize: 10),
                      ),
                    ],
                  ),
                 ),
              ),
            ],
          );
        }
        break;
      default:
        messageContent = Text('[Unsupported message type]', style: TextStyle(color: textColor));
    }

    // <<< Wrap the Align widget with GestureDetector >>>
    return GestureDetector(
      onLongPress: () {
        // <<< Show options menu >>>
        // Pass ref down from ConsumerState
        // <<< Add Light Tap Haptic when menu opens >>>
        HapticUtils.lightTap(); 
        _showMessageOptions(context, widget.message);
      },
      child: Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          // --- Restore consistent padding for all types ---
          padding: const EdgeInsets.symmetric(
            vertical: 6, // Consistent vertical padding
            horizontal: 12, // Consistent horizontal padding
        ),
          // --- END Restore Padding ---
        decoration: BoxDecoration(
            // --- Use original color logic, image background handled by inner placeholder ---
          color: color,
          borderRadius: bubbleRadius,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withAlpha(8),
              blurRadius: 3,
              offset: const Offset(0, 1),
            )
          ],
            // <<< Add subtle border for non-user messages >>>
            border: !widget.isMe 
                ? Border.all(color: Theme.of(context).dividerColor, width: 0.5) 
                : null,
        ),
          constraints: BoxConstraints( // Keep maxWidth constraint
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
              // --- Remove Padding wrapper around messageContent ---
              // Padding(
              //    padding: EdgeInsets.only(...),
              //    child: messageContent,
              // ),
              messageContent, // <<< Place messageContent directly
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
                // --- Align time/status based on sender ---
                mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  AppDateUtils.formatMessageTime(widget.message.createdAt),
                  style: TextStyle(color: iconColor, fontSize: 11),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 5),
                  Icon(
                    _getMessageStatusIcon(widget.message.status),
                    color: iconColor,
                    size: 14,
                  ),
                ],
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  IconData _getMessageStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
      case MessageStatus.sent:
        return Icons.done;
      case MessageStatus.delivered:
      case MessageStatus.read:
        return Icons.done_all;
      default:
        return Icons.error_outline;
    }
  }

  // <<< MOVE _showMessageOptions INSIDE the State class >>>
  void _showMessageOptions(BuildContext context, Message message) { // Ref is accessible via this.ref
    List<Widget> options = [];

    // Option: Save Image
    if (message.type == MessageType.image && (message.mediaUrl != null || message.localFilePath != null)) {
      options.add(
        ListTile(
          leading: Icon(Icons.save_alt, color: Theme.of(context).colorScheme.primary),
          title: Text('Save Image', style: Theme.of(context).textTheme.bodyMedium), // TODO: Localize
          onTap: () async {
            // <<< Add Light Tap Haptic >>>
            HapticUtils.lightTap();
            Navigator.pop(context); // Close the bottom sheet
            
            final bool hasPermission = await PermissionManager.requestPhotosPermission(context); 
            if (!hasPermission) {
              DialogUtils.showMessageDialog(context: context, title: 'Permission Denied', message: 'Storage permission is required to save images.');
              return;
            }

            Uint8List? imageBytes;
            String imageName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
            try {
               if (message.mediaUrl != null) {
                 final response = await http.get(Uri.parse(message.mediaUrl!));
                 if (response.statusCode == 200) {
                   imageBytes = response.bodyBytes;
                   imageName = message.mediaUrl!.split('/').last.split('?').first; 
                 } else {
                    throw Exception('Failed to download image: ${response.statusCode}');
                 }
               } else if (message.localFilePath != null) {
                 File imageFile = File(message.localFilePath!);
                 if (await imageFile.exists()) {
                   imageBytes = await imageFile.readAsBytes();
                   imageName = message.localFilePath!.split('/').last;
                 }
               }

               if (imageBytes != null) {
                 final result = await ImageGallerySaver.saveImage(imageBytes, name: imageName, isReturnImagePathOfIOS: true);
                 AppLogger.d("Image save result: $result");
                 // <<< Add Medium Tap Haptic on Success >>>
                 if (result['isSuccess'] ?? false) HapticUtils.mediumTap();
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(result['isSuccess'] ?? false ? 'Image saved successfully!' : 'Failed to save image.')) // TODO: Localize
                 );
               } else {
                 throw Exception('Image source not available');
               }
            } catch (e) {
               AppLogger.e("Error saving image: $e");
               ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error saving image. Please try again.')) // TODO: Localize
                );
            }
          },
        )
      );
    }

    // Option: Delete Message
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    // <<< Check sender AND time limit >>>
    final isSender = message.id.isNotEmpty && message.senderId == currentUserId;
    final messageTimestamp = message.createdAt; // Use createdAt from the model
    final bool withinTimeLimit = DateTime.now().difference(messageTimestamp).inMinutes < 5;
    
    if (isSender && withinTimeLimit) { // Only show if sender AND within 5 mins
        options.add(
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Delete for Everyone', 
                style: TextStyle(color: Theme.of(context).colorScheme.error)), // Changed text slightly
            onTap: () async {
              // <<< Add Light Tap Haptic >>>
              HapticUtils.lightTap();
               Navigator.pop(context); // Close sheet first
               final confirmed = await DialogUtils.showConfirmationDialog(
                 context: context, 
                 title: 'Delete Message?', 
                 message: 'Are you sure you want to permanently delete this message?', 
                 confirmText: 'Delete', 
                 confirmColor: Theme.of(context).colorScheme.error,
               );
               
               if (confirmed) {
                 // <<< Add Heavy Tap Haptic on Confirmation >>>
                 HapticUtils.heavyTap();
                 try {
                   // <<< Access ref directly >>>
                   final chatService = ref.read(chatServiceProvider);
                   await chatService.deleteMessage(message.chatId, message.id);
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Message deleted.')) // TODO: Localize
                   );
                 } catch (e) {
                    AppLogger.e("Error deleting message from UI action: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not delete message. Please try again.')) // TODO: Localize
                    );
                 }
               }
            },
          )
        );
    } else if (isSender && !withinTimeLimit) {
       // Optional: Add a disabled or different option if needed
       AppLogger.d("[DEBUG] Delete option hidden for message ${message.id} - Time limit exceeded.");
    }

    if (options.isNotEmpty) {
       showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).cardColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (BuildContext bc) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Wrap(
                  children: [
                     ...options,
                     Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor),
                     ListTile(
                        leading: Icon(Icons.cancel_outlined, color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153)),
                        title: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153))),
                        onTap: () {
                           // <<< Add Light Tap Haptic >>>
                           HapticUtils.lightTap();
                           Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
    }
  }
  // <<< END MOVE >>>

  // Restore the PDF thumbnail generation method that was accidentally removed
  Future<void> _generatePdfThumbnail() async {
    if (!mounted) return;
    setState(() {
      _isLoadingThumbnail = true;
    });

    Uint8List? finalImageBytes; // Use a different variable for the final PNG bytes
    PdfDocument? doc;
    try {
      // Determine source: network URL or local path
      if (widget.message.mediaUrl != null && widget.message.mediaUrl!.isNotEmpty) {
        // --- Network URL --- 
        AppLogger.d("[DEBUG Thumb] Generating PDF thumbnail from URL: ${widget.message.mediaUrl}");
        final url = Uri.parse(widget.message.mediaUrl!);
        final response = await http.get(url); // Download PDF data
        if (response.statusCode == 200) {
          final rawBytes = response.bodyBytes; // Keep downloaded bytes separate
          doc = await PdfDocument.openData(rawBytes);
        } else {
          AppLogger.e("Error downloading PDF for thumbnail: Status code ${response.statusCode}");
        }
      } else if (widget.message.localFilePath != null) {
        // --- Local File Path --- 
        AppLogger.d("[DEBUG Thumb] Generating PDF thumbnail from Path: ${widget.message.localFilePath}");
        doc = await PdfDocument.openFile(widget.message.localFilePath!);
      } else {
        AppLogger.d("[DEBUG Thumb] Cannot generate thumbnail: No valid source (URL or Path)");
      }
      
      // --- Render Page and Encode if Document Loaded --- 
      if (doc != null && doc.pageCount >= 1) {
        final page = await doc.getPage(1);
        final targetWidth = (page.width * 1.5).toInt(); 
        final targetHeight = (page.height * 1.5).toInt();
        final PdfPageImage pageImage = await page.render(width: targetWidth, height: targetHeight);
        
        AppLogger.d("[DEBUG Thumb] PDF page rendered. Size: ${pageImage.width}x${pageImage.height}");

        // Use Completer to handle async callback
        final Completer<Uint8List?> pngCompleter = Completer<Uint8List?>();

        final int width = pageImage.width; 
        final int height = pageImage.height;
        final Uint8List pixels = pageImage.pixels;
        final int rowBytes = width * 4; 

        // Call decodeImageFromPixels with the callback
        ui.decodeImageFromPixels(
          pixels, 
          width, 
          height, 
          ui.PixelFormat.rgba8888, 
          // Provide the callback function
          (ui.Image renderedImage) async { // Make callback async
             try {
                // Encode ui.Image to PNG ByteData inside the callback
                final ByteData? byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
                // Convert ByteData to Uint8List (final PNG bytes)
                if (byteData != null) {
                   final encodedBytes = byteData.buffer.asUint8List();
                   AppLogger.d("[DEBUG Thumb] Encoded thumbnail to PNG: ${encodedBytes.lengthInBytes} bytes");
                   // Complete the completer with the PNG bytes
                   if (!pngCompleter.isCompleted) pngCompleter.complete(encodedBytes);
                } else {
                   AppLogger.e("[DEBUG Thumb] Failed to encode rendered image to PNG.");
                   if (!pngCompleter.isCompleted) pngCompleter.complete(null); // Complete with null on failure
                }
            } catch (e) {
                 AppLogger.e("[DEBUG Thumb] Error during PNG encoding: $e");
                 if (!pngCompleter.isCompleted) pngCompleter.complete(null); // Complete with null on error
             }
          },
          rowBytes: rowBytes, 
        );

        // Wait for the completer
        finalImageBytes = await pngCompleter.future;

      } else {
         AppLogger.d("[DEBUG Thumb] Document was null or had no pages.");
      }

    } catch (e) {
      AppLogger.e("Error generating or encoding PDF thumbnail: $e");
      finalImageBytes = null; // Ensure bytes is null on error
    }
    
    // Update state with the *encoded* PNG bytes
    if (mounted) {
      // Store in cache if bytes were generated
      if (finalImageBytes != null) {
        final cacheKey = widget.message.id;
        if (cacheKey.isNotEmpty) { 
           ref.read(pdfThumbnailCacheProvider.notifier).update((state) {
             final newState = Map<String, Uint8List>.from(state);
             newState[cacheKey] = finalImageBytes!;
             return newState;
           });
           AppLogger.d("[DEBUG Thumb] Thumbnail cached for key: $cacheKey");
        }
      } 
      // Update local state AFTER attempting cache write
      setState(() {
        _pdfThumbnailBytes = finalImageBytes; 
        _isLoadingThumbnail = false;
      });
    }
  }
} 

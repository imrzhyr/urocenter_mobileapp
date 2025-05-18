import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User; // Hide FirebaseAuth's User
import '../../../providers/service_providers.dart';
import '../../../core/models/user_model.dart'; // Import our User model
import '../../../app/routes.dart';
import '../../../core/widgets/circular_loading_indicator.dart';
import '../../../core/constants/app_constants.dart'; // Import for onboarding steps
import '../../../core/theme/app_colors.dart'; // Import AppColors
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// A screen that checks the user's authentication and onboarding status
/// and redirects them accordingly.
class AuthCheckScreen extends ConsumerStatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  ConsumerState<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends ConsumerState<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Check if mounted before starting async operation
        _checkAuthAndOnboarding();
      }
    });
  }

  Future<void> _updateFcmToken(String userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Special handling for iOS to get APNS token first
      if (Platform.isIOS) {
        try {
          // Try to get APNS token specifically (iOS only)
          final apnsToken = await messaging.getAPNSToken();
          AppLogger.d("AuthCheckScreen: APNS token ${apnsToken != null ? 'retrieved' : 'not available yet'}: ${apnsToken ?? 'null'}");
          
          // If APNS token is not available, we can't get FCM token yet
          if (apnsToken == null) {
            AppLogger.w("AuthCheckScreen: APNS token not available yet, skipping FCM token update");
            return; // Exit early but don't throw an error
          }
        } catch (apnsError) {
          // Log but continue - getToken might still work
          AppLogger.w("AuthCheckScreen: Error getting APNS token: $apnsError");
        }
      }
      
      // Get the FCM token
      String? token = await messaging.getToken();
      
      if (token != null) {
         AppLogger.d("AuthCheckScreen: Retrieved FCM Token: $token");
         AppLogger.d("FCM TOKEN FOR TESTING: $token");
         // Get the service
         final userProfileService = ref.read(userProfileServiceProvider);
         // Prepare data to save (add token to an array)
         Map<String, dynamic> tokenData = {
            // Use FieldValue.arrayUnion to add the token only if it's not already present
            // This prevents duplicate tokens if this logic runs multiple times.
            'fcmTokens': FieldValue.arrayUnion([token]), 
            'profileLastUpdatedAt': FieldValue.serverTimestamp(), // Update timestamp
         };
         // Save/update the profile
         await userProfileService.saveUserProfile(userId: userId, data: tokenData);
         AppLogger.d("AuthCheckScreen: FCM Token saved/updated for user $userId");
      } else {
         AppLogger.w("AuthCheckScreen: FCM token not available yet (getToken returned null)");
         // Don't treat this as an error, just log a warning
      }
    } catch (e) {
       // Check for APNS token specific error and provide more helpful log
       if (e.toString().contains('apns-token-not-set')) {
         AppLogger.w("AuthCheckScreen: APNS token not set yet. This is normal during initial app setup on iOS.");
       } else {
         AppLogger.e("AuthCheckScreen: Error getting or saving FCM token: $e");
       }
       // Handle error silently, don't block navigation
    }
  }

  // <<< PASTE Permission Request Method Here >>>
  Future<void> _requestNotificationPermissions() async {
    // TODO: [APNS Configuration Required]
    // The app needs a paid Apple Developer account to enable Push Notifications capability
    // and generate/upload an APNS Auth Key (.p8) or Certificate (.p12) 
    // in Firebase Project Settings > Cloud Messaging > Apple app configuration.
    // Without this, `messaging.getToken()` will fail with `apns-token-not-set` 
    // even after permissions are granted, preventing FCM token retrieval and 
    // push notification delivery to iOS devices.
    // See: https://firebase.google.com/docs/cloud-messaging/ios/certs#configure_apns_with_fcm

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.getNotificationSettings();

    AppLogger.d('AuthCheckScreen: User notification settings status: ${settings.authorizationStatus}');

    // Request permission only if not yet determined
    if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
       AppLogger.d('AuthCheckScreen: Requesting notification permission...');
       settings = await messaging.requestPermission(
         alert: true,
         announcement: false,
         badge: true,
         carPlay: false,
         criticalAlert: false,
         provisional: false,
         sound: true,
       );
        AppLogger.d('AuthCheckScreen: User granted permission: ${settings.authorizationStatus}');
    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        AppLogger.d('AuthCheckScreen: Notification permission was previously denied.');
        // Optionally, guide the user to app settings if needed later
    } else {
        AppLogger.d('AuthCheckScreen: Notification permission status: ${settings.authorizationStatus}');
    }
     // No action needed if authorized or provisional
  }
  // <<< END Permission Request Method >>>

  Future<void> _checkAuthAndOnboarding() async {
    // Ensure the widget is still in the tree
    if (!mounted) return;

    // <<< CALL Permission Request FIRST >>>
    await _requestNotificationPermissions();
    // <<< END CALL Permission Request FIRST >>>
    
    // <<< ADD mounted check BEFORE accessing ref >>>
    if (!mounted) return;

    final userProfileService = ref.read(userProfileServiceProvider);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Should not happen if routing logic is correct, but handle defensively
      AppLogger.d("AuthCheckScreen: No user found, redirecting to welcome.");
      if (mounted) context.go(RouteNames.welcome);
      return;
    }

    // <<< START Admin Check >>>
    // Check if the logged-in user is the admin based on EMAIL
    const String adminEmail = 'alikamal22@yahoo.com'; // Define admin EMAIL
    if (currentUser.email == adminEmail) { // <<< Check EMAIL instead of phone >>>
      AppLogger.d("AuthCheckScreen: Admin user detected (by email), redirecting to admin dashboard.");
      if (mounted) context.goNamed(RouteNames.adminDashboard);
      return; // Skip regular user profile/onboarding check
    }
    // <<< END Admin Check >>>

    // --- Continue with existing logic for regular users ---
    try {
      // <<< CALL Token Update AFTER Permission Request >>>
      await _updateFcmToken(currentUser.uid);

      final profileMap = await userProfileService.getUserProfile(currentUser.uid);
      
      if (!mounted) return;

      if (profileMap != null) {
        final userProfile = User.fromMap(profileMap);
        
        if (userProfile.onboardingCompleted) {
          AppLogger.d("AuthCheckScreen: Onboarding complete, redirecting to dashboard.");
          context.goNamed(RouteNames.userDashboard);
        } else {
          // Handle potentially null onboardingStep
          final currentStep = userProfile.onboardingStep;
          final nextRoute = _getNextOnboardingRoute(currentStep);
          AppLogger.d("AuthCheckScreen: Onboarding incomplete (step: ${currentStep ?? 'null'}), redirecting to $nextRoute.");
          context.goNamed(nextRoute);
        }
      } else {
        // Logged in, but no profile found. Send to profile setup.
        AppLogger.d("AuthCheckScreen: User logged in but no profile found. Attempting to create initial profile.");
        
        // <<< Create Initial Profile >>>
        try {
          // Prepare minimal data from the authenticated user
          Map<String, dynamic> initialProfileData = {
            'uid': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(), // Record creation time
            // Include phone number if available from auth
            if (currentUser.phoneNumber != null && currentUser.phoneNumber!.isNotEmpty)
              'phoneNumber': currentUser.phoneNumber,
            // Include email if available from auth (e.g., Google/Email sign-in)
            if (currentUser.email != null && currentUser.email!.isNotEmpty)
              'email': currentUser.email,
            // Set initial onboarding step
            'onboardingStep': 'profile_setup', // Start onboarding
            'onboardingCompleted': false, 
          };
          
          await userProfileService.saveUserProfile(
            userId: currentUser.uid,
            data: initialProfileData,
          );
          AppLogger.d("AuthCheckScreen: Initial profile created successfully for ${currentUser.uid}");

        } catch (profileError) {
           AppLogger.e("AuthCheckScreen: Error creating initial profile: $profileError. Proceeding to profile setup anyway.");
           // Decide if you want to sign the user out here or still let them try profile setup
           // Example: Sign out on profile creation failure
           // await FirebaseAuth.instance.signOut();
           // if (mounted) context.goNamed(RouteNames.welcome);
           // return; 
        }
        // <<< End Create Initial Profile >>>
        
        // Always redirect to profile setup if profile was initially missing
        if (mounted) {
            AppLogger.d("AuthCheckScreen: Redirecting to profile setup.");
        context.goNamed(RouteNames.profileSetup);
        }
      }
    } catch (e) {
      AppLogger.e("AuthCheckScreen: Error fetching profile: $e. Redirecting to welcome.");
      // Handle error (e.g., network issue) by sending to a safe place
      // If we can't load the profile even though user is authenticated,
      // sign them out to break potential loops and ensure clean state.
      if (mounted) {
        try {
          AppLogger.e("AuthCheckScreen: Signing out due to profile load error.");
          await FirebaseAuth.instance.signOut();
        } catch (signOutError) {
          AppLogger.e("AuthCheckScreen: Error signing out: $signOutError");
          // Decide how to handle sign-out error, maybe still try to navigate?
        }
        // Optional: Show a generic error message before redirecting
        // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile. Please try again.')));
        // await Future.delayed(const Duration(milliseconds: 500)); // Delay might not be needed now
        if (mounted) context.goNamed(RouteNames.welcome); // Navigate by name
      }
    }
  }
  
  /// Determines the next route name based on the current onboarding step.
  String _getNextOnboardingRoute(String? currentStep) {
    // Handle null step explicitly - send to start
    if (currentStep == null) {
      AppLogger.w("Warning: Onboarding step is null. Defaulting to profile setup.");
      return RouteNames.profileSetup;
    }
    
    // Assumes AppConstants.onboardingSteps defines the sequence
    const steps = AppConstants.onboardingSteps;
    final currentIndex = steps.indexOf(currentStep);
    
    // Check if the current step is valid and not the last one
    if (currentIndex == -1) {
       // Current step not found in the defined list
       AppLogger.w("Warning: Onboarding step '$currentStep' not recognized. Defaulting to profile setup.");
       return RouteNames.profileSetup;
    } else if (currentIndex == steps.length - 1) {
       // If the current step IS the last defined step (e.g., 'verification'), 
       // but onboardingCompleted is still false, send the user back to THAT step.
       AppLogger.i("Info: Current step '$currentStep' is the last step, but onboarding not complete. Returning to this step.");
       // Assuming the last step 'verification' maps to RouteNames.onboardingVerification
       if (currentStep == 'verification') { // Make this more robust if step names change
           return RouteNames.onboardingVerification;
       } else {
           AppLogger.w("Warning: Unhandled last step '$currentStep'. Defaulting to profile setup.");
           return RouteNames.profileSetup;
       }
    } 
    // If it's a valid step and not the last one, proceed to the next step
    else {
        final nextStepIndex = currentIndex + 1;
        if (nextStepIndex < steps.length) {
            final nextStepName = steps[nextStepIndex];
            switch (nextStepName) {
                case 'medical_history': return RouteNames.medicalHistory;
                case 'document_upload': return RouteNames.documentUpload;
                case 'payment': return RouteNames.payment;
                case 'verification': return RouteNames.onboardingVerification;
                default:
                    AppLogger.w("Warning: Unknown next step '$nextStepName'. Defaulting to profile setup.");
                    return RouteNames.profileSetup;
            }
        } else {
             AppLogger.w("Warning: Calculated nextStepIndex is out of bounds. Defaulting to profile setup.");
             return RouteNames.profileSetup;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while checking status
    return const Scaffold(
      body: Center(
        child: const CircularLoadingIndicator(
          size: 40,
        ),
      ),
    );
  }
} 

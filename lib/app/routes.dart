import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:urocenter/core/utils/logger.dart';

import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/sign_in_screen.dart';
import '../features/auth/screens/sign_up_screen.dart';
import '../features/auth/screens/phone_verification_screen.dart';
import '../features/onboarding/screens/profile_setup_screen.dart';
import '../features/onboarding/screens/medical_history_screen.dart';
import '../features/onboarding/screens/document_upload_screen.dart';
import '../features/onboarding/screens/payment_screen.dart';
import '../features/onboarding/screens/verification_screen.dart' as onboarding;
import '../features/onboarding/widgets/onboarding_shell.dart';
import '../features/user/screens/user_dashboard.dart';
import '../features/user/screens/settings_screen.dart';
import '../features/admin/screens/admin_dashboard.dart';
import '../features/admin/screens/admin_users.dart';
import '../features/chat/screens/chat_screen.dart';
import '../core/utils/page_transitions.dart';
import '../features/user/screens/medical_history_view_screen.dart';
import '../features/user/screens/document_management_screen.dart';
import '../features/chat/screens/fullscreen_image_viewer.dart';
import '../features/chat/screens/pdf_viewer_screen.dart';
import '../features/chat/screens/patient_info_screen.dart';
import '../features/settings/screens/about_screen.dart';
import '../features/settings/screens/terms_screen.dart';
import '../features/settings/screens/privacy_policy_screen.dart';
import '../core/utils/go_router_refresh_stream.dart';
import '../features/auth/screens/auth_check_screen.dart';
import '../features/chat/screens/call_screen.dart';
import '../features/user/screens/notifications_screen.dart';
import '../features/help_support/screens/help_support_screen.dart';

/// Named routes for easier navigation
class RouteNames {
  /// Welcome screen
  static const String welcome = 'welcome';
  /// Sign in screen
  static const String signIn = 'sign-in';
  /// Sign up screen
  static const String signUp = 'sign-up';
  /// Email verification screen
  static const String verification = 'verification';
  
  /// Onboarding screens
  static const String onboarding = 'onboarding';
  static const String profileSetup = 'profileSetup';
  static const String medicalHistory = 'medicalHistory';
  static const String documentUpload = 'documentUpload';
  static const String payment = 'payment';
  static const String onboardingVerification = 'onboardingVerification';
  /// Add Call Screen Route
  static const String callScreen = 'callScreen';
  
  /// User dashboard screen
  static const String userDashboard = 'dashboard';
  /// User profile screen
  static const String userProfile = 'profile';
  /// User appointments screen
  static const String userAppointments = 'appointments';
  /// User chat screen
  static const String userChat = 'chat';
  /// Notifications screen
  static const String notifications = 'notifications';
  /// Settings screen
  static const String settings = 'settings';
  /// Help and support screen
  static const String helpSupport = 'help-support';
  /// About screen
  static const String about = 'about';
  /// Terms and conditions screen
  static const String terms = 'terms';
  /// Privacy Policy screen
  static const String privacyPolicy = 'privacyPolicy';
  /// User Medical History view screen
  static const String userMedicalHistory = 'userMedicalHistory';
  /// User Document Management screen
  static const String userDocuments = 'userDocuments';
  /// Fullscreen Image Viewer
  static const String imageViewer = 'imageViewer';
  /// PDF Viewer
  static const String pdfViewer = 'pdfViewer';
  /// Patient Info Screen
  static const String patientInfo = 'patientInfo';
  
  /// Admin dashboard screen
  static const String adminDashboard = 'admin';
  /// Admin users screen
  static const String adminUsers = 'users';
  /// Admin consultations screen
  static const String adminConsultations = 'consultations';
  /// Admin payments screen
  static const String adminPayments = 'payments';
  
  /// Define a base path for onboarding shell
  static const String onboardingBase = '/onboarding'; 

  /// Admin settings screen
  static const String adminSettings = 'adminSettings';
}

/// Provider for access to the router
final routerProvider = riverpod.Provider<GoRouter>((ref) {
  return _createRouter(ref);
});

/// Create the router configuration for provider usage
GoRouter _createRouter(riverpod.Ref<GoRouter> ref) {
  final protectedRoutes = [
    RouteNames.onboardingBase,
    '/dashboard',
    '/profile',
    '/appointments',
    '/chat',
    '/userMedicalHistory',
    '/userDocuments',
  ];
  
  final authRoutes = [
    '/',
    '/sign-in',
    '/sign-up',
    '/verification',
  ];

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (BuildContext context, GoRouterState state) {
      final currentUser = FirebaseAuth.instance.currentUser;
      final loggedIn = currentUser != null;
      final requestedLocation = state.matchedLocation;
      
      final isProtected = protectedRoutes.any((route) => requestedLocation.startsWith(route));
      final isAuthRoute = authRoutes.contains(requestedLocation);

      AppLogger.d('Router Redirect: loggedIn=$loggedIn, location=$requestedLocation, isProtected=$isProtected, isAuthRoute=$isAuthRoute');

      if (!loggedIn && isProtected) {
        AppLogger.d('Redirecting to / (not logged in, accessing protected route)');
        return '/'; 
      }

      if (loggedIn && isAuthRoute) {
        AppLogger.d('Redirecting to /auth-check (logged in, accessing auth route)');
        return '/auth-check'; 
      }

      AppLogger.d('No redirect needed.');
      return null; 
    },
    routes: <RouteBase>[
      // Add the AuthCheckScreen route
      GoRoute(
        path: '/auth-check',
        // No name needed as it's internal? Or add one if preferred: name: 'authCheck',
        pageBuilder: (context, state) => const NoTransitionPage( // No transition needed
            child: AuthCheckScreen(),
          ),
      ),
      
      // Auth routes
      GoRoute(
        path: '/',
        name: RouteNames.welcome,
        pageBuilder: (context, state) {
          final isBack = state.extra is bool && state.extra as bool;
          
          return PageTransitions.slideTransition(
            context: context,
            state: state,
            direction: isBack ? SlideDirection.fromLeft : SlideDirection.fromRight,
            child: const WelcomeScreen(),
          );
        },
      ),
      GoRoute(
        path: '/sign-in',
        name: RouteNames.signIn,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context,
          state: state,
          direction: SlideDirection.fromRight,
          child: const SignInScreen(),
        ),
      ),
      GoRoute(
        path: '/sign-up',
        name: RouteNames.signUp,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context,
          state: state,
          direction: SlideDirection.fromRight,
          child: const SignUpScreen(),
        ),
      ),
      GoRoute(
        path: '/image-viewer',
        name: RouteNames.imageViewer,
        pageBuilder: (context, state) {
          String? imagePathValue;
          if (state.extra is String) {
            imagePathValue = state.extra as String?;
          } else if (state.extra is Map) {
            imagePathValue = (state.extra as Map)['imagePath'] as String?;
          }
          
          return MaterialPage(
            key: state.pageKey,
            fullscreenDialog: true,
            child: FullscreenImageViewer(
              imagePath: imagePathValue ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: '/pdf-viewer',
        name: RouteNames.pdfViewer,
        pageBuilder: (context, state) {
          return PageTransitions.slideTransition(
            context: context,
            state: state,
            child: PdfViewerScreen(
              extraData: state.extra, 
            ),
          );
        },
      ),
      GoRoute(
        path: '/verification',
        name: RouteNames.verification,
        pageBuilder: (context, state) {
          String? phoneNumber;
          
          if (state.extra is Map) {
            final extraMap = state.extra as Map;
            phoneNumber = extraMap['phoneNumber'] as String?;
          } else if (state.extra is String) {
            phoneNumber = state.extra as String?;
            AppLogger.w("Warning: Navigating to verification with only phone number string. Verification ID might be missing.");
          }
          
          return PageTransitions.slideTransition(
            context: context,
            state: state,
            direction: SlideDirection.fromRight,
            child: PhoneVerificationScreen(
              phoneNumber: phoneNumber ?? '', 
            ),
          );
        },
      ),
      
      // --- Onboarding Shell Route --- 
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return OnboardingShell(child: child);
        },
        routes: <RouteBase>[
          // Nested onboarding routes - Removed transitions
          GoRoute(
            path: '${RouteNames.onboardingBase}/profile-setup',
            name: RouteNames.profileSetup,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfileSetupScreen(),
            ),
          ),
          GoRoute(
            path: '${RouteNames.onboardingBase}/medical-history',
            name: RouteNames.medicalHistory,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const MedicalHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '${RouteNames.onboardingBase}/document-upload',
            name: RouteNames.documentUpload,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DocumentUploadScreen(),
            ),
          ),
          GoRoute(
            path: '${RouteNames.onboardingBase}/payment',
            name: RouteNames.payment,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PaymentScreen(),
            ),
          ),
          GoRoute(
            path: '${RouteNames.onboardingBase}/verification',
            name: RouteNames.onboardingVerification,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const onboarding.OnboardingCompletionScreen(),
            ),
          ),
        ],
      ),
      
      // User routes
      GoRoute(
        path: '/dashboard',
        name: RouteNames.userDashboard,
        pageBuilder: (context, state) => PageTransitions.fadeTransition(
          context: context, 
          state: state, 
          child: const UserDashboard(),
        ),
      ),
      GoRoute(
        path: '/chat',
        name: RouteNames.userChat,
        pageBuilder: (context, state) {
          final doctorName = state.uri.queryParameters['doctorName'];
          final doctorTitle = state.uri.queryParameters['doctorTitle'];
          final isNewChat = state.uri.queryParameters['isNewChat'] == 'true';
          
          final extra = state.extra; 

          return PageTransitions.slideTransition(
            context: context,
            state: state,
            child: ChatScreen(
              doctorName: doctorName,
              doctorTitle: doctorTitle,
              isNewChat: isNewChat,
              extraData: extra, 
            ),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: RouteNames.settings,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
        routes: [
          // Nested routes for screens accessible from Settings
          GoRoute(
            path: 'about', // Relative path
            name: RouteNames.about,
            pageBuilder: (context, state) => PageTransitions.slideTransition(
              context: context,
              state: state,
              child: const AboutScreen(),
            ),
          ),
          GoRoute(
            path: 'terms', // Relative path
            name: RouteNames.terms,
            pageBuilder: (context, state) => PageTransitions.slideTransition(
              context: context,
              state: state,
              child: const TermsScreen(),
            ),
          ),
          GoRoute(
            path: 'privacy-policy', // Relative path
            name: RouteNames.privacyPolicy,
            pageBuilder: (context, state) => PageTransitions.slideTransition(
              context: context,
              state: state,
              child: const PrivacyPolicyScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/help-support',
        name: RouteNames.helpSupport,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context, 
          state: state, 
          child: const HelpSupportScreen(), 
        ),
      ),
      
      // Add notifications route
      GoRoute(
        path: '/notifications',
        name: RouteNames.notifications,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context,
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
      
      // --- Add routes for the new user screens ---
      GoRoute(
        path: '/medical-history-view',
        name: RouteNames.userMedicalHistory,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context, 
          state: state, 
          child: const MedicalHistoryViewScreen(),
        ),
      ),
      GoRoute(
        path: '/document-management',
        name: RouteNames.userDocuments,
        pageBuilder: (context, state) => PageTransitions.slideTransition(
          context: context, 
          state: state, 
          child: const DocumentManagementScreen(),
        ),
      ),
      
      // Admin routes - direct routes instead of shell route
      GoRoute(
        path: '/admin',
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboard(),
        routes: const [],
      ),
      GoRoute(
        path: '/admin/users',
        name: RouteNames.adminUsers,
        builder: (context, state) => const AdminUsers(),
      ),
      GoRoute(
        path: '/admin/consultations',
        name: RouteNames.adminConsultations,
        builder: (context, state) => const Center(
          child: Text('Consultations Screen Coming Soon'),
        ),
      ),
      GoRoute(
        path: '/admin/payments',
        name: RouteNames.adminPayments,
        builder: (context, state) => const Center(
          child: Text('Payments Screen Coming Soon'),
        ),
      ),
      // Add Call Screen Route
      GoRoute(
        path: '/call', // Define the path for the call screen
        name: RouteNames.callScreen,
        pageBuilder: (context, state) {
          // Pass the extra data from the pushNamed call to the CallScreen
          return PageTransitions.slideTransition(
            context: context,
            state: state,
            direction: SlideDirection.fromBottom, // Example transition
            child: CallScreen(
              extraData: state.extra as Map<String, dynamic>?,
            ),
          );
        },
      ),
      
      // Add Patient Info Screen Route
      GoRoute(
        path: '/patient-info',
        name: RouteNames.patientInfo,
        pageBuilder: (context, state) {
          return PageTransitions.slideTransition(
            context: context,
            state: state,
            child: PatientInfoScreen(
              data: state.extra as PatientOnboardingData,
            ),
          );
        },
      ),
    ],
    
    // Error page for unmatched routes
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: Text('errors.page_not_found'.tr())),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('errors.page_not_found_message'.tr()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.goNamed(RouteNames.welcome),
              child: Text('common.back_to_home'.tr()),
            ),
          ],
        ),
      ),
    ),
  );
}

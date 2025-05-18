import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../core/theme/theme.dart';
import 'routes.dart';
import '../core/services/call_service.dart';
import '../providers/theme_provider.dart';
import '../providers/in_app_notification_provider.dart';
import 'dart:ui' as ui;
import '../providers/service_providers.dart';
import '../core/utils/logger.dart';
import 'package:overlay_support/overlay_support.dart';
import '../main.dart';

/// The main app component that sets up routing and initial state
class UroApp extends ConsumerStatefulWidget {
  const UroApp({super.key});

  @override
  ConsumerState<UroApp> createState() => _UroAppState();
}

class _UroAppState extends ConsumerState<UroApp> {
  @override
  void initState() {
    super.initState();
    
    // Initialize the FCM handler after build with a post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Add a small delay before initializing FCM handler
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Initialize FCM handler
      try {
        final fcmHandler = ref.read(fcmHandlerProvider);
        await fcmHandler.initialize();
        AppLogger.d("[UroApp] FCM handler initialized successfully");
      } catch (error) {
        AppLogger.e("[UroApp] Error initializing FCM handler: $error");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final notificationNotifier = ref.read(inAppNotificationProvider.notifier);
    
    // Listen for incoming calls and navigate to call screen
    ref.listen<IncomingCall?>(incomingCallProvider, (previous, current) {
      if (current != null) {
        AppLogger.d("[UroApp] Received incoming call from: ${current.callerName}");
        
        // Create call parameters
        final callParams = {
          'callId': current.callId,
          'partnerName': current.callerName.isNotEmpty ? current.callerName : "Unknown Caller",
          'isCaller': false,
          'isIncoming': true,
        };
        
        // Navigate to call screen directly without showing notification overlay
        router.pushNamed(
          RouteNames.callScreen,
          extra: callParams,
        );
      }
    });
    
    ref.listen<AsyncValue<NotificationData?>>(globalIncomingMessagesProvider, (previous, next) {
      AppLogger.d("[UroApp Listener] Global message stream event received: hasValue=${next.hasValue}, hasError=${next.hasError}");
      
      if (next.hasValue && next.value != null) {
        final notificationData = next.value!;
        AppLogger.d("[UroApp Listener] Received potential notification: ${notificationData.chatId}");
        
        // <<< Get the currently viewed chat ID from the provider >>>
        final currentlyViewedChatId = ref.read(currentlyViewedChatIdProvider);
        AppLogger.d("[UroApp Listener] Currently viewed chat ID: $currentlyViewedChatId");

        // <<< Compare incoming chat ID with the currently viewed one >>>
        bool isOnTargetChatScreen = (currentlyViewedChatId == notificationData.chatId);
        
        // Log if suppressed
        if (isOnTargetChatScreen) {
          AppLogger.d("[UroApp Listener] Suppressing notification because target chat screen is active.");
        }

        // Only show if NOT on the *specific* target chat screen
        if (!isOnTargetChatScreen) {
          AppLogger.i("[UroApp Listener] Triggering overlay notification for chat: ${notificationData.chatId}");
          try {
            notificationNotifier.showNotification(notificationData); // Trigger overlay
            AppLogger.d("[UroApp Listener] Notification trigger function called successfully");
          } catch (e) {
            AppLogger.e("[UroApp Listener] Error showing notification: $e");
          }
        }
      } else if (next.hasError) {
        AppLogger.e("[UroApp Listener] Error in global message stream: ${next.error}", next.error, next.stackTrace);
      }
    });
    
    final currentLocale = context.locale;
    
    final ui.TextDirection textDirection = context.locale.languageCode == 'ar'
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
    
    AppLogger.d("[UroApp] Building app with OverlaySupport.global");
    
    // We MUST use OverlaySupport.global to enable in-app chat notifications
    return OverlaySupport.global(
      child: MaterialApp.router(
        title: 'UroCenter',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getLightTheme(currentLocale),
        darkTheme: AppTheme.getDarkTheme(currentLocale),
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        builder: (context, child) {
          return Directionality(
            textDirection: textDirection,
            child: ScrollConfiguration(
              behavior: NoSplashScrollBehavior(),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.0),
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom scroll behavior that removes splash and overscroll effects
class NoSplashScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Remove overscroll glow effect
    return child;
  }
  
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
  
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
} 
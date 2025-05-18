import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:urocenter/providers/theme_provider.dart';
import 'package:logger/logger.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:urocenter/providers/in_app_notification_provider.dart'; // Import the new provider
import 'package:urocenter/core/utils/custom_asset_loader.dart'; // Import custom asset loader

import 'firebase_options.dart';
import 'app/app.dart';
import 'core/providers/locale_provider.dart'; // Import locale provider
import 'core/services/payment/fib_payment_callback_handler.dart'; // Import payment callback handler

// Define the provider globally
final inAppNotificationProvider = 
    ChangeNotifierProvider<InAppNotificationProvider>((ref) => InAppNotificationProvider(ref));

// Platform-specific method channel for handling deep links
const MethodChannel _methodChannel = MethodChannel('com.urocenter.deeplinks');
final Logger _logger = Logger();

// --- Temporary placeholder for AudioPlayer initialization (if still needed) ---
// Future<void> configureAudioPlayer() async {
//    // Example: Set global options if required by audioplayers
//    // await AudioPlayer.global.setGlobalAudioContext(...);
//    AppLogger.d("Placeholder: AudioPlayer configuration check");
// }
// --- End placeholder ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize providers that need async setup (like SharedPreferences)
  final localeOverride = await initLocaleProvider();
  final themeOverride = await initThemeProvider();
  
  // Initialize payment callback handler
  try {
    final paymentHandler = FibPaymentCallbackHandler();
    await paymentHandler.initialize();
    _logger.d('FIB Payment callback handler initialized');
    
    // Set up method channel for receiving deep links from platform code
    _methodChannel.setMethodCallHandler((call) async {
      if (call.method == 'handleDeepLink') {
        final String? link = call.arguments as String?;
        if (link != null) {
          try {
            final uri = Uri.parse(link);
            if (uri.scheme == 'urocenter' && uri.path == '/payment/callback') {
              paymentHandler.handleCallback(uri);
            }
          } catch (e) {
            _logger.e('Error parsing deep link: $e');
          }
        }
      }
      return null;
    });
  } catch (e) {
    _logger.e('Error initializing FIB Payment callback handler: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
      path: 'assets/translations', 
      fallbackLocale: const Locale('en', 'US'),
      useOnlyLangCode: false,
      useFallbackTranslations: true,
      assetLoader: CustomAssetLoader(),
      child: ProviderScope( // ProviderScope now uses overrides
        overrides: [
          localeOverride,
          themeOverride,
        ],
        child: const UroApp(), 
      ),
    ),
  );
}


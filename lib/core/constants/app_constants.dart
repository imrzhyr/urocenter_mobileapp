/// Application-wide constants
class AppConstants {
  /// App name
  static const String appName = 'UroCenter';

  /// App version
  static const String appVersion = '1.0.0';
  
  /// Onboarding steps
  static const List<String> onboardingSteps = [
    'profile_setup',
    'medical_history',
    'document_upload',
    'payment',
    'verification',
  ];
  
  /// Supported languages
  static const List<LanguageModel> supportedLanguages = [
    LanguageModel(code: 'en', name: 'English', locale: 'en_US', nameKey: 'language.english'),
    LanguageModel(code: 'ar', name: 'العربية', locale: 'ar_SA', nameKey: 'language.arabic'),
  ];
  
  /// Default language code
  static const String defaultLanguageCode = 'en';
  
  /// Default locale
  static const String defaultLocale = 'en_US';
  
  /// Number of characters to show in chat preview
  static const int chatPreviewLength = 40;
  
  /// Password minimum length
  static const int passwordMinLength = 8;
  
  /// OTP length
  static const int otpLength = 6;
  
  /// OTP resend timeout in seconds
  static const int otpResendTimeoutSeconds = 60;
  
  /// Session expiration time in seconds (7 days)
  static const int sessionExpirationSeconds = 7 * 24 * 60 * 60; // 7 days
  
  /// App animation duration
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  /// Page transition duration
  static const Duration pageTransitionDuration = Duration(milliseconds: 400);
  
  /// Typing timeout duration
  static const Duration typingTimeout = Duration(seconds: 3);
  
  /// Maximum file size in bytes (10MB)
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  
  /// Maximum image dimensions
  static const int maxImageDimension = 1200;
  
  /// Maximum voice message duration in seconds
  static const int maxVoiceMessageDuration = 120; // 2 minutes
  
  /// Prefix for temporary message IDs
  static const String tempMessageIdPrefix = 'temp_';
}

/// Language model for supported languages
class LanguageModel {
  /// Language code (e.g., 'en', 'ar')
  final String code;
  
  /// Language name in native script (for fallback or display before localization loads)
  final String name;
  
  /// Language locale (e.g., 'en_US', 'ar_SA')
  final String locale;
  
  /// Translation key for the language name
  final String nameKey;
  
  /// Constructor
  const LanguageModel({
    required this.code,
    required this.name,
    required this.locale,
    required this.nameKey,
  });
} 
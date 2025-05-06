import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

/// Provider for managing app localization
class LocaleNotifier extends StateNotifier<Locale> {
  static const String _localeKey = 'app_locale';
  final SharedPreferences _prefs;

  LocaleNotifier(this._prefs) 
      : super(_getSavedLocale(_prefs) ?? 
              const Locale(AppConstants.defaultLanguageCode));

  /// Get the saved locale from shared preferences
  static Locale? _getSavedLocale(SharedPreferences prefs) {
    final String? savedLocaleCode = prefs.getString(_localeKey);
    if (savedLocaleCode == null) return null;
    
    // Find the corresponding locale model
    final localeModel = AppConstants.supportedLanguages.firstWhere(
      (lang) => lang.code == savedLocaleCode,
      orElse: () => AppConstants.supportedLanguages.first,
    );
    
    // Extract country code if available
    final localeParts = localeModel.locale.split('_');
    if (localeParts.length > 1) {
      return Locale(localeParts[0], localeParts[1]);
    }
    return Locale(localeParts[0]);
  }

  /// Set the app locale
  Future<void> setLocale(String languageCode) async {
    // Find the corresponding locale model
    final localeModel = AppConstants.supportedLanguages.firstWhere(
      (lang) => lang.code == languageCode,
      orElse: () => AppConstants.supportedLanguages.first,
    );
    
    // Save to preferences
    await _prefs.setString(_localeKey, languageCode);
    
    // Extract country code if available
    final localeParts = localeModel.locale.split('_');
    if (localeParts.length > 1) {
      state = Locale(localeParts[0], localeParts[1]);
    } else {
      state = Locale(localeParts[0]);
    }
  }

  /// Get the current language code
  String get languageCode => state.languageCode;
  
  /// Check if the current locale is RTL
  bool get isRtl => state.languageCode == 'ar';
}

/// Provider for locale state
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  throw UnimplementedError('Locale provider not initialized');
});

/// Provider initialization function
Future<Override> initLocaleProvider() async {
  final prefs = await SharedPreferences.getInstance();
  return localeProvider.overrideWith((ref) => LocaleNotifier(prefs));
} 
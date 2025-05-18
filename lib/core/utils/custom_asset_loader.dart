import 'dart:convert';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Custom asset loader for Easy Localization
/// Handles loading the translation files with the correct format (en-US.json and ar-SA.json)
class CustomAssetLoader extends AssetLoader {
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    AppLogger.d('[Custom Asset Loader] Original locale requested: ${locale.languageCode}${locale.countryCode != null ? "_${locale.countryCode}" : ""}');
    
    // If we have just languageCode (e.g. 'en'), append the default country code
    Locale effectiveLocale = locale;
    if (locale.countryCode == null) {
      if (locale.languageCode == 'en') {
        effectiveLocale = const Locale('en', 'US');
        AppLogger.d('[Custom Asset Loader] Using effective locale: en_US');
      } else if (locale.languageCode == 'ar') {
        effectiveLocale = const Locale('ar', 'SA');
        AppLogger.d('[Custom Asset Loader] Using effective locale: ar_SA');
      }
    }
    
    // Format the locale code with different potential patterns starting with most likely format
    final List<String> potentialLocales = [
      // First try direct supported formats 
      '${effectiveLocale.languageCode}-${effectiveLocale.countryCode}', // e.g., "en-US"
      '${effectiveLocale.languageCode}_${effectiveLocale.countryCode}', // e.g., "en_US"
      effectiveLocale.languageCode, // e.g., "en"
    ];
    
    Map<String, dynamic> result = {};
    bool loadedSuccessfully = false;
    
    // Try each potential locale format
    for (final localeCode in potentialLocales) {
      AppLogger.d('[Custom Asset Loader] Trying to load locale file: $localeCode.json');
      
      // Construct the file path
      String filePath = '$path/$localeCode.json';
      
      try {
        // Load the asset file
        final data = await rootBundle.loadString(filePath);
        
        // Parse the JSON data
        result = json.decode(data) as Map<String, dynamic>;
        loadedSuccessfully = true;
        AppLogger.d('[Custom Asset Loader] Successfully loaded: $filePath');
        break; // Exit the loop if we successfully loaded a file
      } catch (e) {
        AppLogger.d('[Custom Asset Loader] Failed to load: $filePath - $e');
        // Continue to the next format
      }
    }
    
    if (!loadedSuccessfully) {
      AppLogger.e('[Custom Asset Loader] Could not load any translation file for locale: ${effectiveLocale.languageCode}');
      // Return an empty map to avoid null errors
      return {};
    }
    
    return result;
  }
} 
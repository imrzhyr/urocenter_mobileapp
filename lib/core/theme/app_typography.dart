import 'package:flutter/material.dart';
// import 'app_colors.dart'; // Removed unused import

/// Defines the text styles used throughout the app
class AppTypography {
  // Base Text Style - accepts fontFamily
  static TextStyle _baseTextStyle(String fontFamily) => TextStyle(
    fontFamily: fontFamily,
    color: Colors.black, // Default color, will be overridden by theme
  );

  // Returns TextTheme - accepts fontFamily
  static TextTheme getTextTheme(String fontFamily) => TextTheme(
    displayLarge: _baseTextStyle(fontFamily).copyWith(fontSize: 57, fontWeight: FontWeight.w400),
    displayMedium: _baseTextStyle(fontFamily).copyWith(fontSize: 45, fontWeight: FontWeight.w400),
    displaySmall: _baseTextStyle(fontFamily).copyWith(fontSize: 36, fontWeight: FontWeight.w400),
    
    headlineLarge: _baseTextStyle(fontFamily).copyWith(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: _baseTextStyle(fontFamily).copyWith(fontSize: 28, fontWeight: FontWeight.w600),
    headlineSmall: _baseTextStyle(fontFamily).copyWith(fontSize: 24, fontWeight: FontWeight.w600),
    
    titleLarge: _baseTextStyle(fontFamily).copyWith(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: _baseTextStyle(fontFamily).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: _baseTextStyle(fontFamily).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    
    bodyLarge: _baseTextStyle(fontFamily).copyWith(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: _baseTextStyle(fontFamily).copyWith(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: _baseTextStyle(fontFamily).copyWith(fontSize: 12, fontWeight: FontWeight.w400),
    
    labelLarge: _baseTextStyle(fontFamily).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: _baseTextStyle(fontFamily).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: _baseTextStyle(fontFamily).copyWith(fontSize: 11, fontWeight: FontWeight.w500),
  );

  // Keep the static textTheme getter for cases where fontFamily is not needed or defaults
  // This might be deprecated later if all usages are updated.
  static final TextTheme textTheme = getTextTheme('Poppins'); // Default to Poppins
} 
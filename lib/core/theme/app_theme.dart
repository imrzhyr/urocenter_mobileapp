import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// App theme configuration
class AppTheme {
  static const String _arabicFontFamily = 'Noto Kufi Arabic';
  static const String _defaultFontFamily = 'Poppins';

  // Helper method to get font family based on locale
  static String _getFontFamily(Locale locale) {
    return locale.languageCode == 'ar' ? _arabicFontFamily : _defaultFontFamily;
  }

  // Light theme - now a method accepting locale
  static ThemeData getLightTheme(Locale locale) {
    final fontFamily = _getFontFamily(locale);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background, // Explicitly set light scaffold background
      
      // Remove ripple effect globally
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.accentLight,
        onSecondaryContainer: AppColors.accentDark,
        error: AppColors.error,
        surface: AppColors.card,
        onSurface: AppColors.textPrimary,
        background: AppColors.background, // Also set ColorScheme background
      ),
      fontFamily: fontFamily, // Use dynamic font family
      textTheme: AppTypography.getTextTheme(fontFamily), // Generate TextTheme with correct font
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.blue,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: const IconThemeData(color: AppColors.primary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      
      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily, // Apply font family
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      
      // Text Button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: TextStyle(
            fontFamily: fontFamily, // Apply font family
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      
      // Outlined Button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily, // Apply font family
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      
      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shadowColor: AppColors.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        clipBehavior: Clip.hardEdge,
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 179.0),
          fontSize: 16,
          fontWeight: FontWeight.normal,
          fontFamily: fontFamily, // Apply font family
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        errorStyle: TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.0,
          fontFamily: fontFamily, // Apply font family
        ),
        errorMaxLines: 2,
        isDense: true,
      ),
      
      // Dialog theme
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.card,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily, // Apply font family
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily, // Apply font family
          fontSize: 16,
          color: AppColors.textSecondary,
        ),
      ),
      
      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 77.0),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final baseStyle = TextStyle(fontFamily: fontFamily, fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return baseStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return baseStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          );
        }),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 32,
      ),
      
      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryLight;
          }
          return null;
        }),
      ),
      
      // Slider theme
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.primary,
        overlayColor: Color(0x1A3B82F6),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.divider,
      ),
      
      // Tooltip theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withValues(alpha: 230.0),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: Colors.white,
        ),
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Dark theme - now a method accepting locale
  static ThemeData getDarkTheme(Locale locale) {
    final fontFamily = _getFontFamily(locale);
    // Use the dedicated dark theme colors from AppColors
    const darkColorScheme = ColorScheme.dark(
      primary: AppColors.primaryDarkTheme, // Use lighter primary for dark
      onPrimary: AppColors.textPrimaryDark, // Text on primary
      primaryContainer: AppColors.primaryDark, 
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.accentDarkTheme, // Lighter accent for dark
      onSecondary: AppColors.textPrimaryDark, // Text on accent
      secondaryContainer: AppColors.accentDark,
      onSecondaryContainer: AppColors.accentLight,
      error: AppColors.errorDarkTheme, // Lighter error for dark
      onError: AppColors.textPrimaryDark, // Text on error
      surface: AppColors.cardDark, // Use dark card color for surface
      onSurface: AppColors.textPrimaryDark, // Use light text on dark surface
      background: AppColors.backgroundDark, // Use dark background
      onBackground: AppColors.textPrimaryDark, // Use light text on dark background
      surfaceVariant: AppColors.inputBackgroundDark, // Use for input fields etc.
      onSurfaceVariant: AppColors.textSecondaryDark, // Text on surfaceVariant
      outline: AppColors.dividerDark, // Border color
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark, // Ensure dark scaffold background is set
      
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      
      colorScheme: darkColorScheme, // Use the defined dark color scheme
      fontFamily: fontFamily,
      textTheme: AppTypography.getTextTheme(fontFamily).apply( // Apply dark text colors
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
        // Ensure all text styles use appropriate dark colors
      ).copyWith(
        // You might need explicit overrides here if .apply doesn't cover everything
        titleLarge: AppTypography.getTextTheme(fontFamily).titleLarge?.copyWith(color: AppColors.textPrimaryDark),
        titleMedium: AppTypography.getTextTheme(fontFamily).titleMedium?.copyWith(color: AppColors.textPrimaryDark),
        titleSmall: AppTypography.getTextTheme(fontFamily).titleSmall?.copyWith(color: AppColors.textSecondaryDark),
        bodyLarge: AppTypography.getTextTheme(fontFamily).bodyLarge?.copyWith(color: AppColors.textPrimaryDark),
        bodyMedium: AppTypography.getTextTheme(fontFamily).bodyMedium?.copyWith(color: AppColors.textSecondaryDark),
        bodySmall: AppTypography.getTextTheme(fontFamily).bodySmall?.copyWith(color: AppColors.textTertiaryDark),
        labelLarge: AppTypography.getTextTheme(fontFamily).labelLarge?.copyWith(color: AppColors.textPrimaryDark),
        // ... other text styles if needed
      ),
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark, // Dark background
        foregroundColor: AppColors.textPrimaryDark, // Light text
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.deepPurple.withValues(alpha: 102.0), // Changed to purple for dark mode
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
        actionsIconTheme: const IconThemeData(color: AppColors.primaryDarkTheme), // Use dark primary
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // Light icons on dark status bar
        ),
      ),
      
      // Elevated Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
         style: ElevatedButton.styleFrom(
           elevation: 0,
           backgroundColor: AppColors.primaryDarkTheme, // Use dark primary
           foregroundColor: AppColors.textPrimaryDark, // Text on dark primary
           minimumSize: const Size(double.infinity, 56),
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(12),
           ),
           textStyle: TextStyle(
             fontFamily: fontFamily,
             fontSize: 16,
             fontWeight: FontWeight.w600,
           ),
           padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
           splashFactory: NoSplash.splashFactory,
        ),
      ),

      // Text Button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDarkTheme, // Use dark primary
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      
      // Outlined Button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.primaryDarkTheme, width: 1.5), // Dark primary border
          foregroundColor: AppColors.primaryDarkTheme, // Dark primary text
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        clipBehavior: Clip.hardEdge,
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackgroundDark, 
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none, 
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDarkTheme, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorDarkTheme, width: 1),
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondaryDark.withValues(alpha: 179.0),
          fontSize: 16,
          fontWeight: FontWeight.normal,
          fontFamily: fontFamily,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        errorStyle: TextStyle(
          color: AppColors.errorDarkTheme,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.0,
          fontFamily: fontFamily,
        ),
        errorMaxLines: 2,
        isDense: true,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: AppColors.cardDark, // Dark dialog background
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark, // Light title text
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          color: AppColors.textSecondaryDark, // Light content text
        ),
      ),

      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.backgroundDark, // Dark background for nav bar
        indicatorColor: AppColors.primaryDarkTheme.withValues(alpha: 77.0), // Indicator color
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryDarkTheme); // Selected icon color
          }
          return const IconThemeData(color: AppColors.textSecondaryDark); // Unselected icon color
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final baseStyle = TextStyle(fontFamily: fontFamily, fontSize: 12);
          if (states.contains(WidgetState.selected)) {
            return baseStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDarkTheme, // Selected label color
            );
          }
          return baseStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryDark, // Unselected label color
          );
        }),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark, // Use dark divider color
        thickness: 1,
        space: 32,
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDarkTheme; // Use dark primary
          }
          return AppColors.textSecondaryDark; // Border color when unchecked
        }),
        checkColor: WidgetStateProperty.all(AppColors.backgroundDark), // Check mark color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: AppColors.textSecondaryDark), // Border color
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDarkTheme;
          }
          return AppColors.textSecondaryDark; // Thumb color when off
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryDarkTheme.withValues(alpha: 128.0);
          }
          return AppColors.dividerDark; // Track color when off
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent), // No outline
      ),
      
      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryDarkTheme,
        inactiveTrackColor: AppColors.dividerDark,
        thumbColor: AppColors.primaryDarkTheme,
        overlayColor: AppColors.primaryDarkTheme.withValues(alpha: 38.0),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryDarkTheme,
        linearTrackColor: AppColors.dividerDark,
      ),
      
      // Tooltip theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cardDark.withValues(alpha: 242.0), // Darker tooltip background
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.dividerDark)
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: AppColors.textPrimaryDark,
        ),
      ),
      
      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardDark, // Use dark card for snackbar
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: AppColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.dividerDark)
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }

  // Keep static getters for backward compatibility (defaulting to English locale)
  // These should eventually be removed or updated.
  static ThemeData get lightTheme => getLightTheme(const Locale('en'));
  static ThemeData get darkTheme => getDarkTheme(const Locale('en'));
} 
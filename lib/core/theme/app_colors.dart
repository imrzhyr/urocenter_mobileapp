import 'package:flutter/material.dart';

/// App color scheme based on a modern medical aesthetic with soothing colors
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF3B82F6); // Blue
  static const Color primaryLight = Color(0xFF93C5FD);
  static const Color primaryDark = Color(0xFF1E40AF);
  
  // Secondary accent colors
  static const Color accent = Color(0xFF10B981); // Teal green
  static const Color accentLight = Color(0xFF6EE7B7);
  static const Color accentDark = Color(0xFF047857);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  // UI colors
  static const Color background = Color(0xFFF6F7F8);
  static const Color surface = Color(0xFFF6F7F8); // Alias for background to fix errors
  static const Color surfaceVariant = Color(0xFFE5E7EB); // Added to fix errors
  static const Color surfaceContainerHighest = Color(0xFFE5E7EB); // Added to fix errors
  static const Color card = Colors.white;
  static const Color divider = Color(0xFFE5E7EB);
  static const Color inputBackground = Color(0xFFF3F4F6);
  static const Color inputBorder = Color(0xFFD1D5DB);
  
  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Gradient colors for dynamic backgrounds
  static const List<Color> primaryGradient = [
    Color(0xFF3B82F6),
    Color(0xFF2563EB),
  ];
  
  static const List<Color> accentGradient = [
    Color(0xFF10B981),
    Color(0xFF059669),
  ];
  
  // Subtle shadows
  static const Color shadowColor = Color(0x0F000000);

  // --- Dark Theme Colors ---
  static const Color backgroundDark = Color(0xFF0C111B);
  static const Color cardDark = Color(0xFF1F2937); // Gray-800
  static const Color inputBackgroundDark = Color(0xFF374151); // Gray-700
  static const Color dividerDark = Color(0xFF4B5563); // Gray-600
  
  static const Color textPrimaryDark = Color(0xFFF9FAFB); // Gray-50 (Almost White)
  static const Color textSecondaryDark = Color(0xFF9CA3AF); // Gray-400
  static const Color textTertiaryDark = Color(0xFF6B7280); // Gray-500
  static const Color textDisabledDark = Color(0xFF4B5563); // Gray-600

  // Dark theme variants for other colors (can keep some the same if contrast is ok)
  static const Color primaryDarkTheme = Color(0xFF60A5FA); // Blue-400 (lighter for contrast)
  static const Color accentDarkTheme = Color(0xFF34D399); // Emerald-400 (lighter for contrast)
  static const Color errorDarkTheme = Color(0xFFF87171); // Red-400 (lighter for contrast)
  static const Color successDarkTheme = Color(0xFF4ADE80); // Green-400 (lighter for contrast)
  static const Color warningDarkTheme = Color(0xFFFBBF24); // Amber-400 (lighter for contrast)
  static const Color infoDarkTheme = Color(0xFF38BDF8); // Sky-400 (lighter for contrast)
} 
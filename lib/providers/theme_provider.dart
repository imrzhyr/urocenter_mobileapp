import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app theme mode (light/dark)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeModeKey = 'app_theme_mode';
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) 
      : super(_getSavedThemeMode(_prefs) ?? ThemeMode.light); // Default to light

  /// Get the saved theme mode from shared preferences
  static ThemeMode? _getSavedThemeMode(SharedPreferences prefs) {
    final String? savedThemeMode = prefs.getString(_themeModeKey);
    if (savedThemeMode == null) return null;
    return savedThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  /// Set the app theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (state == themeMode) return; // No change

    state = themeMode;
    await _prefs.setString(_themeModeKey, themeMode == ThemeMode.dark ? 'dark' : 'light');
  }

  /// Toggle the current theme mode
  Future<void> toggleThemeMode() async {
    await setThemeMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
}

/// Provider for theme mode state
/// Needs initialization with SharedPreferences override.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  // This will be overridden in main.dart
  throw UnimplementedError('Theme provider not initialized'); 
});

/// Function to create the SharedPreferences override for the theme provider.
/// Call this in main.dart along with other initializations.
Future<Override> initThemeProvider() async {
  final prefs = await SharedPreferences.getInstance();
  return themeModeProvider.overrideWith((ref) => ThemeModeNotifier(prefs));
} 
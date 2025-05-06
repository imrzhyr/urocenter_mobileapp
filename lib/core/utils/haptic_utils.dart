import 'package:flutter/services.dart';
import 'package:urocenter/core/utils/logger.dart';

/// A utility class for triggering standardized haptic feedback patterns.
class HapticUtils {
  /// Private constructor to prevent instantiation.
  HapticUtils._();

  /// A light tap, suitable for general button presses, list item taps, etc.
  static Future<void> lightTap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      AppLogger.e("Haptic feedback (light) failed", e);
    }
  }

  /// A medium tap, suitable for confirming successful actions (save, send, complete).
  static Future<void> mediumTap() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      AppLogger.e("Haptic feedback (medium) failed", e);
    }
  }

  /// A heavy tap, suitable for warnings or destructive actions (use sparingly).
  static Future<void> heavyTap() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      AppLogger.e("Haptic feedback (heavy) failed", e);
    }
  }

  /// Feedback designed for selection changes (like picker wheels or tabs).
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      AppLogger.e("Haptic feedback (selection) failed", e);
    }
  }

  // Add more specific methods if needed, e.g.:
  // static Future<void> success() => mediumTap();
  // static Future<void> warning() => heavyTap();
  // static Future<void> error() => heavyTap(); // Or maybe a specific pattern if available
} 
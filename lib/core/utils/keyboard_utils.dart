import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Utilities for handling keyboard and scrolling behavior in chat screens
class KeyboardUtils {
  /// Scrolls to the bottom of a ScrollController when the keyboard appears
  /// 
  /// Use this in a TextField's onTap callback or when keyboard visibility changes
  static void scrollToBottomOnKeyboardOpen(ScrollController scrollController) {
    // Delay slightly to allow keyboard to fully appear
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        // Jump directly to the bottom without animation
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }
  
  /// Sets up a listener to respond to keyboard visibility changes
  /// 
  /// Call this in initState to keep messages visible when keyboard appears or disappears
  static void setupKeyboardListeners(
    BuildContext context, 
    ScrollController scrollController,
    VoidCallback onKeyboardVisible,
    VoidCallback onKeyboardHidden,
  ) {
    // Initial keyboard state check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
      if (keyboardVisible) {
        onKeyboardVisible();
      } else {
        onKeyboardHidden();
      }
    });
    
    // Note: For more advanced keyboard detection, consider using the 
    // flutter_keyboard_visibility package (requires additional dependency)
  }
} 
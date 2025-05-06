import 'package:flutter/material.dart';

/// A SafeArea widget that doesn't add any background color,
/// allowing content underneath to be visible through the safe area padding.
class TransparentSafeArea extends StatelessWidget {
  /// The child widget to be wrapped with safe area padding.
  final Widget child;
  
  /// Whether to maintain the bottom padding.
  final bool bottom;
  
  /// Whether to maintain the top padding.
  final bool top;
  
  /// Whether to maintain the left padding.
  final bool left;
  
  /// Whether to maintain the right padding.
  final bool right;
  
  /// Creates a transparent SafeArea widget.
  const TransparentSafeArea({
    super.key,
    required this.child,
    this.bottom = true,
    this.top = true,
    this.left = true,
    this.right = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      // Set minimum to zero to avoid any default padding
      minimum: EdgeInsets.zero,
      // The important part: make the SafeArea transparent
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: !left,
        removeTop: !top,
        removeRight: !right,
        removeBottom: !bottom,
        child: child,
      ),
    );
  }
} 
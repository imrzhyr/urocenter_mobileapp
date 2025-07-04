import 'package:flutter/material.dart';

/// A standardized circular loading indicator used across the app
/// This matches the style used in the sign-in/AnimatedButton for consistency
class CircularLoadingIndicator extends StatelessWidget {
  /// The size of the circular indicator
  final double size;
  
  /// The stroke width of the circular indicator
  final double strokeWidth;
  
  /// The color of the indicator (defaults to primary color if not specified)
  final Color? color;
  
  /// Whether to show a value if one is available
  final bool showProgress;
  
  /// The progress value between 0.0 and 1.0 if known
  final double? value;

  const CircularLoadingIndicator({
    super.key,
    this.size = 24.0,
    this.strokeWidth = 2.0,
    this.color,
    this.showProgress = false,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    
    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
        value: showProgress ? value : null,
      ),
    );
  }
} 
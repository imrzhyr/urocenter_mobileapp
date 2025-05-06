import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'circular_loading_indicator.dart';

/// A custom animated loading indicator
class AnimatedLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final bool showBackground;

  const AnimatedLoader({
    super.key,
    this.size = 40,
    this.color,
    this.strokeWidth = 3.5,
    this.showBackground = true,
  });

  @override
  State<AnimatedLoader> createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<AnimatedLoader> {
  @override
  Widget build(BuildContext context) {
    // Use theme primary color
    final Color color = widget.color ?? Theme.of(context).colorScheme.primary;

    // For consistency, we're using CircularLoadingIndicator
    return CircularLoadingIndicator(
      size: widget.size,
      color: color,
      strokeWidth: widget.strokeWidth,
    );
  }
} 
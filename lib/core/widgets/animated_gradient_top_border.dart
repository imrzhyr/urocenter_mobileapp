import 'package:flutter/material.dart';
import '../theme/theme.dart'; // Assuming theme file exists

class AnimatedGradientTopBorder extends StatefulWidget {
  final double height;
  final Duration duration;

  const AnimatedGradientTopBorder({
    super.key,
    this.height = 3.0, // Subtle height for the border
    this.duration = const Duration(seconds: 1), // Speed of one animation cycle
  });

  @override
  State<AnimatedGradientTopBorder> createState() => _AnimatedGradientTopBorderState();
}

class _AnimatedGradientTopBorderState extends State<AnimatedGradientTopBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true); // Repeat back and forth

    // Simple animation just oscillating between 0.0 and 1.0
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedBuilder to rebuild the gradient on animation ticks
    final theme = Theme.of(context); // Get theme data
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Define the three base colors using the theme
        final Color color1 = theme.colorScheme.primary;
        final Color color2 = theme.colorScheme.primaryContainer; // Use primaryContainer instead
        final Color color3 = theme.colorScheme.primary; 
        
        final double animValue = _animation.value; // 0.0 to 1.0

        // Interpolate between the three colors in sequence
        // Phase 1: Color1 -> Color2
        final Color interpolatedA = Color.lerp(color1, color2, animValue) ?? color1;
        // Phase 2: Color2 -> Color3 (which is now Color1)
        final Color interpolatedB = Color.lerp(color2, color3, animValue) ?? color2;
        // Phase 3: Color3 (Color1) -> Color1 (Stays Color1)
        final Color interpolatedC = Color.lerp(color3, color1, animValue) ?? color3;

        // We can arrange these in the gradient based on the animation value 
        // to make it feel like a wave or pulse passing through the colors.
        // Example: Use a mix based on the animation value

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              // Create a sequence using the interpolated colors
              colors: [
                 // colorA, // Starts blue, moves to light blue
                 // colorB, // Starts light blue, moves to purple
                 // colorC, // Starts purple, moves to blue
                 // colorA, // Repeat first color for smoother loop
                 interpolatedA,
                 interpolatedB,
                 interpolatedC,
                 interpolatedA, // Repeat first color
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
} 
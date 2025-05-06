import 'dart:math';
import 'dart:ui' as ui; // For ui.Gradient and BlendMode
import 'package:flutter/material.dart';
import 'package:urocenter/core/theme/app_colors.dart'; // Assuming AppColors path

class AnimatedGradientCardBackground extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const AnimatedGradientCardBackground({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)), // Default matching card
  });

  @override
  State<AnimatedGradientCardBackground> createState() =>
      _AnimatedGradientCardBackgroundState();
}

class _AnimatedGradientCardBackgroundState
    extends State<AnimatedGradientCardBackground>
    with TickerProviderStateMixin { // Use TickerProviderStateMixin for multiple controllers

  late List<AnimationController> _controllers;
  late List<Animation<double>> _animationsX;
  late List<Animation<double>> _animationsY;
  late List<Animation<double>> _animationsRadius;

  @override
  void initState() {
    super.initState();

    // Only initialize controllers and animations here
    // Color count will be determined in build based on theme
    const int estimatedOrbCount = 5; // Estimate count for init

    _controllers = List.generate(estimatedOrbCount, (index) {
      final duration = Duration(milliseconds: 8000 + Random().nextInt(4000)); // Slower: 8s - 12s
      return AnimationController(
        vsync: this,
        duration: duration,
      )..repeat(reverse: true); // Loop back and forth
    });

    _animationsX = _controllers.map((controller) {
      final startOffset = -0.2 + Random().nextDouble() * 0.4; 
      final endOffset = 0.8 + Random().nextDouble() * 0.4; 
      final tween = (Random().nextBool())
          ? Tween<double>(begin: startOffset, end: endOffset)
          : Tween<double>(begin: endOffset, end: startOffset);
      return tween.animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutSine), // Smoother curve
      );
    }).toList();

    _animationsY = _controllers.map((controller) {
       final startOffset = -0.2 + Random().nextDouble() * 0.4;
       final endOffset = 0.8 + Random().nextDouble() * 0.4; 
       final tween = (Random().nextBool())
           ? Tween<double>(begin: startOffset, end: endOffset)
           : Tween<double>(begin: endOffset, end: startOffset);
      return tween.animate(
         CurvedAnimation(parent: controller, curve: Curves.easeInOutSine), // Smoother curve
      );
    }).toList();
    
     _animationsRadius = _controllers.map((controller) {
       final startRadiusFactor = 0.4 + Random().nextDouble() * 0.6; // Slightly larger base: 0.4 to 1.0
       final endRadiusFactor = 0.4 + Random().nextDouble() * 0.6; 
       // Ensure start and end are sufficiently different to avoid static look
       final clampedEnd = (endRadiusFactor - startRadiusFactor).abs() < 0.3 
                           ? startRadiusFactor + (Random().nextBool() ? 0.5 : -0.5) 
                           : endRadiusFactor;
       final finalEnd = clampedEnd.clamp(0.4, 1.0); // Clamp within new range
       return Tween<double>(begin: startRadiusFactor, end: finalEnd).animate(
         CurvedAnimation(parent: controller, curve: Curves.easeInOutSine), // Smoother curve
       );
     }).toList();

    // Add listener to rebuild when animations change
    for (var controller in _controllers) {
      controller.addListener(() {
        if (mounted) { // Check if widget is still in the tree
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // --- Define Orb Colors based on Theme ---
    final List<Color> orbColors = isDarkMode
      ? [ // Dark Mode Orbs
          theme.colorScheme.primary.withAlpha(153),       // Primary (adjust opacity)
          theme.colorScheme.secondary.withAlpha(128),    // Secondary (adjust opacity)
          AppColors.primaryDark.withAlpha(179),        // A darker variant for depth
          const Color(0xFF6D28D9).withAlpha(153), // Dark Purple (example)
          const Color(0xFF7C3AED).withAlpha(128), // Lighter Dark Purple (example)
        ]
      : [ // Light Mode Orbs (Original or adjusted)
          AppColors.primary.withAlpha(153),      
          Colors.lightBlueAccent.withAlpha(128), 
          AppColors.primaryDark.withAlpha(179),   
          Colors.purple.withAlpha(153),         
          Colors.purpleAccent.withAlpha(128),   
        ];
        
    // --- Define Base Gradient based on Theme ---
    final List<Color> baseGradient = isDarkMode 
      ? [ // Dark Mode Gradient
        AppColors.primaryDark.withAlpha(204),
        theme.colorScheme.surface.withAlpha(242), // Blend into dark background
      ]
      : AppColors.primaryGradient; // Light Mode Gradient

    // Ensure animation lists match orb color count (in case it changes dynamically)
    // This is a basic way; more robust would involve recreating controllers if count changes.
    final int orbCount = orbColors.length;
    final currentAnimationsX = _animationsX.take(orbCount).toList();
    final currentAnimationsY = _animationsY.take(orbCount).toList();
    final currentAnimationsRadius = _animationsRadius.take(orbCount).toList();

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          // --- Layer 1: Base Background Gradient (Theme Aware) ---
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // colors: AppColors.primaryGradient, // Use theme-aware gradient
                  colors: baseGradient, 
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // Adjust stops if needed for dark mode gradient
                  stops: isDarkMode ? [0.0, 0.8] : null, 
                ),
              ),
            ),
          ),
          // --- Layer 2: Animated Orbs (Theme Aware Colors) ---
          Positioned.fill(
            child: CustomPaint(
              painter: _GradientPainter(
                animationsX: currentAnimationsX, // Use sized lists
                animationsY: currentAnimationsY,
                animationsRadius: currentAnimationsRadius,
                // colors: _orbColors, // Use theme-aware colors
                colors: orbColors,
              ),
              child: Container(), 
            ),
          ),
          // --- Layer 3: Original Child Content ---
          widget.child, 
        ],
      ),
    );
  }
}

class _GradientPainter extends CustomPainter {
  final List<Animation<double>> animationsX;
  final List<Animation<double>> animationsY;
  final List<Animation<double>> animationsRadius;
  final List<Color> colors;

  _GradientPainter({
    required this.animationsX,
    required this.animationsY,
    required this.animationsRadius,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(); // For potential future use (e.g., jitter)

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(animationsX[i].value * size.width, animationsY[i].value * size.height), // Center of the orb
          size.width * animationsRadius[i].value, // Radius based on animation and size
          [
            colors[i], // Inner color (orb color)
            colors[i].withAlpha(0), // Outer color (transparent)
          ],
           [0.0, 1.0], // Stops: Center is orb color, edge is transparent
           TileMode.clamp, // Prevent repeating gradient outside the circle
        );
        
      // Draw the gradient circle
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) {
    // Repaint if any animation values have changed
    // A simple check for inequality works because Animation objects change identity
    // or you could compare the .value of each animation if needed for performance.
    return animationsX != oldDelegate.animationsX ||
           animationsY != oldDelegate.animationsY ||
           animationsRadius != oldDelegate.animationsRadius;
  }
} 
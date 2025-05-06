import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Provides smooth transitions between onboarding pages
class AnimatedTransitions {
  /// Slide transition from right to left (next page)
  static Route<dynamic> slideForward(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = const Offset(1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.easeInOutCubic;
        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Slide transition from left to right (previous page)
  static Route<dynamic> slideBackward(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = const Offset(-1.0, 0.0);
        var end = Offset.zero;
        var curve = Curves.easeInOutCubic;
        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Fade transition with scale effect
  static Route<dynamic> fadeScale(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var curve = Curves.easeOutBack;
        var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
        
        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(fadeAnimation),
            child: child,
          ),
        );
      },
    );
  }

  /// Specialized transition for the onboarding flow
  static Route<dynamic> onboardingTransition(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
        );
        
        var slideAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
        );
        
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.15),
              end: Offset.zero,
            ).animate(slideAnimation),
            child: child,
          ),
        );
      },
    );
  }

  /// Creates a 3D perspective transition effect
  /// The incoming page appears to rotate slightly in 3D space while fading in
  /// When isExit is true, the animation is reversed for exit transitions
  static Widget perspectiveTransition({
    required Animation<double> animation,
    required Widget child,
    bool isExit = false,
  }) {
    // For perspective effect we need to use Transform
    final perspectiveTween = Tween<double>(
      begin: isExit ? 0.0 : 0.005, 
      end: isExit ? 0.005 : 0.0,
    );
    
    // For rotation effect
    final rotateTween = Tween<double>(
      begin: isExit ? 0.0 : 0.1,
      end: isExit ? 0.1 : 0.0,
    );
    
    // For shifting the transform origin slightly off-center
    final offsetTween = Tween<double>(
      begin: isExit ? 0.0 : 30.0,
      end: isExit ? 30.0 : 0.0,
    );
    
    // For fading effect
    final fadeTween = Tween<double>(
      begin: isExit ? 1.0 : 0.0,
      end: isExit ? 0.0 : 1.0,
    );
    
    // For slight scaling
    final scaleTween = Tween<double>(
      begin: isExit ? 1.0 : 0.93,
      end: isExit ? 0.93 : 1.0,
    );
    
    // Custom curved animation
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final perspectiveValue = perspectiveTween.evaluate(curvedAnimation);
        final rotateValue = rotateTween.evaluate(curvedAnimation);
        final offsetValue = offsetTween.evaluate(curvedAnimation);
        final fadeValue = fadeTween.evaluate(curvedAnimation);
        final scaleValue = scaleTween.evaluate(curvedAnimation);
        
        return Opacity(
          opacity: fadeValue,
          child: Transform(
            alignment: isExit ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, perspectiveValue) // perspective
              ..rotateY(isExit ? -rotateValue : rotateValue) // y-axis rotation
              ..translate(isExit ? -offsetValue : offsetValue) // slight offset
              ..scale(scaleValue), // subtle scaling
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Creates a 3D cube rotation effect between screens
  /// The page appears to be on the face of a rotating cube
  /// Direction determines if the cube rotates to the right (next page) or left (previous page)
  static Widget cubeRotation({
    required Animation<double> animation,
    required Widget child,
    bool isForward = true, // true for next page, false for previous page
  }) {
    // For the rotation angle around Y axis
    final rotationTween = Tween<double>(
      begin: isForward ? math.pi / 2.0 : -math.pi / 2.0,
      end: 0.0,
    );
    
    // For z-translation to create a cube effect
    final zTween = Tween<double>(
      begin: 100.0,
      end: 0.0,
    );
    
    // For perspective
    const perspective = 0.003;
    
    // For slight movement during transition
    final xOffsetTween = Tween<double>(
      begin: isForward ? 50.0 : -50.0,
      end: 0.0,
    );
    
    // For opacity
    final opacityTween = Tween<double>(
      begin: 0.3,
      end: 1.0,
    );
    
    // Create a curved animation for smoother effect
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final rotationValue = rotationTween.evaluate(curvedAnimation);
        final zValue = zTween.evaluate(curvedAnimation);
        final xOffsetValue = xOffsetTween.evaluate(curvedAnimation);
        final opacityValue = opacityTween.evaluate(curvedAnimation);
        
        return Opacity(
          opacity: opacityValue,
          child: Transform(
            alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, perspective) // add perspective
              ..setEntry(3, 0, 0.001) // slight skew for more realism
              ..translate(xOffsetValue, 0.0, zValue) // translate in 3D space
              ..rotateY(rotationValue), // rotate around Y axis
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Creates a shutter/blinds effect transition
  /// The screen splits into multiple horizontal slices that rotate in sequence
  static Widget shutterEffect({
    required Animation<double> animation,
    required Widget child,
    int slices = 5, // Number of horizontal slices
    bool isForward = true, // Direction of animation
  }) {
    // Create a curved animation for smoother effect
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOut,
    );
    
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        // Overall progress of the animation
        final progress = curvedAnimation.value;
        
        return ClipRect(
          child: Stack(
            children: List.generate(slices, (index) {
              // Calculate the height of each slice
              final sliceHeight = 1.0 / slices;
              
              // Calculate the delay for each slice (staggered effect)
              final delay = 0.1 * index;
              final sliceProgress = math.min(1.0, math.max(0.0, (progress - delay) * (1.0 + delay)));
              
              // Calculate the rotation angle for each slice
              final rotationAngle = isForward ? 
                  (1.0 - sliceProgress) * math.pi * 0.5 : 
                  (1.0 - sliceProgress) * -math.pi * 0.5;
              
              // Top position of the slice
              final top = index * sliceHeight;
              
              return Positioned.fill(
                top: top,
                bottom: 1.0 - top - sliceHeight,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: sliceHeight,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // add slight perspective
                        ..rotateX(rotationAngle), // rotate around X axis for horizontal blinds
                      child: Opacity(
                        opacity: sliceProgress,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
      child: child,
    );
  }

  /// Creates a 3D card flip transition effect
  /// The current page flips like a card to reveal the next page
  /// Direction determines if the flip is horizontal or vertical
  static Widget cardFlip({
    required Animation<double> animation,
    required Widget child,
    Widget? secondChild,
    FlipDirection direction = FlipDirection.horizontal,
    double depth = 0.001, // Controls how pronounced the 3D effect is
  }) {
    // Create a curved animation for smoother effect
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );
    
    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, _) {
        final isFirstHalf = curvedAnimation.value < 0.5;
        final value = isFirstHalf ? curvedAnimation.value * 2 : (curvedAnimation.value - 0.5) * 2;
        
        // Calculate the rotation based on direction
        final rotationValue = (isFirstHalf ? value : value - 1) * math.pi;
        
        // Set up the rotation transform based on flip direction
        final transform = Matrix4.identity()
          ..setEntry(3, 2, depth); // add perspective
        
        if (direction == FlipDirection.horizontal) {
          transform.rotateY(rotationValue);
        } else {
          transform.rotateX(rotationValue);
        }
        
        // Apply slight scaling to enhance the 3D effect
        final scale = 0.9 + (0.1 * math.sin((value * 2 - 1).abs() * math.pi));
        transform.scale(scale);
        
        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: isFirstHalf 
              ? (curvedAnimation.value > 0.25 ? const SizedBox() : child)
              : (curvedAnimation.value < 0.75 ? const SizedBox() : (secondChild ?? child)),
        );
      },
      child: child,
    );
  }
}

/// Enum to specify the direction of card flip
enum FlipDirection {
  horizontal,
  vertical,
}
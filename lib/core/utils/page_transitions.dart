import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Helper class for consistent page transitions across the app
class PageTransitions {
  /// Create a standard slide transition for page navigation
  static CustomTransitionPage<void> slideTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Define the beginning offset based on direction
        final Offset begin = _getBeginOffset(direction);
        const Offset end = Offset.zero;
        
        // Create standard tween and curve
        final tween = Tween(begin: begin, end: end);
        final curveTween = CurveTween(curve: Curves.easeInOut);

        return SlideTransition(
          position: animation.drive(curveTween).drive(tween),
          child: child,
        );
      },
    );
  }

  /// Create a back navigation transition with a swipe effect
  /// This is used when navigating back to a previous screen
  static Page<dynamic> backSwipeTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // For the back transition, we create a more natural swipe effect
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        
        // Secondary animation represents the outgoing page
        // We'll use it to create a parallax effect
        final secondaryCurvedAnim = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeInOut,
        );
        
        // Main slide animation
        final slideAnimation = Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(curvedAnimation);
        
        // Slight scale effect for the new page coming in
        final scaleAnimation = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).animate(curvedAnimation);
        
        // Subtle secondary page movement to create parallax effect
        final secondarySlideAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.2, 0.0),
        ).animate(secondaryCurvedAnim);
        
        // Apply the transformations
        return SlideTransition(
          position: secondarySlideAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// Create a fade transition
  static CustomTransitionPage<void> fadeTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
  
  /// Create a scale transition
  static CustomTransitionPage<void> scaleTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: animation,
          child: child,
        );
      },
    );
  }
  
  /// Create a combined slide and fade transition
  static CustomTransitionPage<void> slideFadeTransition({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      barrierColor: Colors.transparent, // Prevent black background
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Define the beginning offset based on direction
        final Offset begin = _getBeginOffset(direction);
        const Offset end = Offset.zero;
        
        // Create smoother animations with better curves
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        
        // Tween for slide animation
        final slideTween = Tween(begin: begin, end: end);
        
        // Fade animation that starts sooner than the slide
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ));
        
        // Subtle scale animation for depth
        final scaleAnimation = Tween<double>(
          begin: 0.98,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideTween.animate(curvedAnimation),
            child: ScaleTransition(
              scale: scaleAnimation,
              child: child,
            ),
          ),
        );
      },
    );
  }
  
  /// Helper method to get the beginning offset based on direction
  static Offset _getBeginOffset(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.fromRight:
        return const Offset(1.0, 0.0);
      case SlideDirection.fromLeft:
        return const Offset(-1.0, 0.0);
      case SlideDirection.fromTop:
        return const Offset(0.0, -1.0);
      case SlideDirection.fromBottom:
        return const Offset(0.0, 1.0);
    }
  }
}

/// Slide direction for transitions
enum SlideDirection {
  fromRight,
  fromLeft,
  fromTop,
  fromBottom,
} 
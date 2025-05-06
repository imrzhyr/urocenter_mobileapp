import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// This provider is now defined in routes.dart, so we don't need to redefine it here
// We'll keep the back transition helper though

// Configure custom back button behavior
CustomTransitionPage<void> buildBackTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(-1.0, 0.0); // Slide from left when going back
      const end = Offset.zero;
      
      final tween = Tween(begin: begin, end: end);
      final curveTween = CurveTween(curve: Curves.easeInOut);

      return SlideTransition(
        position: animation.drive(curveTween).drive(tween),
        child: child,
      );
    },
  );
} 
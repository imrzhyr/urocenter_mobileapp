import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/circular_loading_indicator.dart';

/// Navigation utilities for route handling
class NavigationUtils {
  /// Navigate to a route
  static void navigateTo(BuildContext context, String routeName, {Map<String, String>? params, Object? extra}) {
    context.goNamed(
      routeName,
      pathParameters: params ?? {},
      extra: extra,
    );
  }
  
  /// Navigate to a route and replace the current route
  static void replaceTo(BuildContext context, String routeName, {Map<String, String>? params, Object? extra}) {
    context.goNamed(
      routeName,
      pathParameters: params ?? {},
      extra: extra,
    );
  }
  
  /// Push a new route onto the navigation stack
  static void pushTo(BuildContext context, String routeName, {Map<String, String>? params, Object? extra}) {
    context.pushNamed(
      routeName,
      pathParameters: params ?? {},
      extra: extra,
    );
  }
  
  /// Pop the current route
  static void pop(BuildContext context, [dynamic result]) {
    if (context.canPop()) {
      context.pop(result);
    }
  }
  
  /// Safely navigate back, with fallback routes
  /// 
  /// This method tries to go back using different approaches to ensure
  /// that navigation never fails with "Nothing to pop" errors
  static void safeGoBack(
    BuildContext context, {
    String? previousRouteName,
    String fallbackRouteName = 'welcome',
  }) {
    try {
      // First try Navigator.pop if possible
      if (context.canPop()) {
        context.pop();
        return;
      }
      
      // If pop isn't available, try going to the previous route if specified
      if (previousRouteName != null) {
        context.goNamed(previousRouteName);
        return;
      }
      
      // Use the fallback route as last resort
      context.goNamed(fallbackRouteName);
    } catch (e) {
      // If everything fails, ensure we at least go somewhere valid
      try {
        context.goNamed(fallbackRouteName);
      } catch (_) {
        // If even that fails, try to go to the root route
        context.go('/');
      }
    }
  }
  
  /// Pop until a specific route
  static void popUntil(BuildContext context, String routeName) {
    while (context.canPop() && GoRouterState.of(context).name != routeName) {
      context.pop();
    }
  }
  
  /// Pop and push a new route
  static void popAndPushTo(BuildContext context, String routeName, {Map<String, String>? params, Object? extra}) {
    if (context.canPop()) {
      context.pop();
    }
    pushTo(context, routeName, params: params, extra: extra);
  }
  
  /// Show a bottom sheet
  static Future<T?> showAppBottomSheet<T>(
    BuildContext context, 
    Widget child, {
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: elevation,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: shape ?? const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: child,
      ),
    );
  }
  
  /// Show a dialog
  static Future<T?> showAppDialog<T>(
    BuildContext context, 
    Widget child, {
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      builder: (context) => child,
    );
  }
  
  /// Show a loading dialog
  static Future<void> showLoadingDialog(BuildContext context, {String? message}) async {
    await showAppDialog(
      context,
      AlertDialog(
        content: Row(
          children: [
            const CircularLoadingIndicator(),
            const SizedBox(width: 20),
            Text(message ?? 'Loading...'),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }
  
  /// Hide the loading dialog
  static void hideLoadingDialog(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    }
  }
  
  /// Show a snackbar
  static void showSnackBar(BuildContext context, String message, {Duration? duration, Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
        backgroundColor: backgroundColor,
      ),
    );
  }
  
  /// Create a custom page route with transition
  static PageRoute<T> createRoute<T>(
    Widget page, {
    RouteSettings? settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: transitionDuration,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }
} 
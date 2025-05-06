import 'dart:async';
import 'package:flutter/material.dart';

/// Converts a [Stream] into a [Listenable] that notifies listeners
/// whenever the stream emits a new value.
///
/// Used with GoRouter's `refreshListenable` to trigger route redirection
/// based on stream events (e.g., authentication state changes).
class GoRouterRefreshStream extends ChangeNotifier {
  /// Creates a [GoRouterRefreshStream] that listens to the given [stream].
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners(); // Initial notification
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
} 
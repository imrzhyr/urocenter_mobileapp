import 'dart:async';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

/// A service to handle deep link callbacks from FIB payment
class FibPaymentCallbackHandler {
  static final FibPaymentCallbackHandler _instance = FibPaymentCallbackHandler._internal();
  factory FibPaymentCallbackHandler() => _instance;
  FibPaymentCallbackHandler._internal();

  static const MethodChannel _channel = MethodChannel('com.urocenter.fib_payment_callback');
  final Logger _logger = Logger();
  final List<Function(Map<String, dynamic>)> _callbackListeners = [];

  /// Initialize the payment callback handler
  /// Should be called early in the app lifecycle
  Future<void> initialize() async {
    try {
      _logger.d('Initializing FIB payment callback handler');
      
      // Set up method channel listener for callback messages
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'handlePaymentCallback') {
          if (call.arguments is Map) {
            final params = Map<String, dynamic>.from(call.arguments);
            _notifyListeners(params);
          }
        }
        return null;
      });
      
      // Tell native side we're ready to receive callbacks
      await _channel.invokeMethod('initializeCallbackHandler');
      
    } catch (e) {
      _logger.e('Failed to initialize payment callback handler: $e');
    }
  }

  /// Add a listener to receive payment callbacks
  void addListener(Function(Map<String, dynamic>) listener) {
    _callbackListeners.add(listener);
  }

  /// Remove a previously added listener
  void removeListener(Function(Map<String, dynamic>) listener) {
    _callbackListeners.remove(listener);
  }

  /// Manually handle a payment callback (e.g., from a URI handler in main app)
  void handleCallback(Uri uri) {
    _logger.d('Received payment callback: $uri');
    
    if (uri.scheme != 'urocenter') return;
    if (uri.path != '/payment/callback') return;
    
    final params = <String, dynamic>{};
    uri.queryParameters.forEach((key, value) {
      params[key] = value;
    });
    
    if (params.containsKey('paymentId')) {
      _notifyListeners(params);
    }
  }
  
  /// Notify all listeners of a payment callback
  void _notifyListeners(Map<String, dynamic> params) {
    _logger.d('Notifying listeners of payment callback: $params');
    
    for (final listener in _callbackListeners) {
      try {
        listener(params);
      } catch (e) {
        _logger.e('Error in payment callback listener: $e');
      }
    }
  }
} 
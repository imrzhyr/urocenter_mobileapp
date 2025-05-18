import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// A utility class for standardized logging throughout the app.
/// Uses the logger package internally but provides a simplified interface.
class AppLogger {
  /// Private constructor to prevent instantiation
  AppLogger._();

  /// The shared logger instance with custom configuration
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // Only show logs in debug mode
    level: kDebugMode ? Level.info : Level.error,
  );

  /// Log a debug message, used for development-time information
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log an info message, used for general information
  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log a warning message, used for potential issues
  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log a call-related warning without triggering system alerts
  static void callWarning(String message, [dynamic error, StackTrace? stackTrace]) {
    // Skip visual alerts for call-related messages, but still log them
    if (kDebugMode) {
      print('[CALL WARNING] $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('Stack trace: $stackTrace');
    }
  }

  /// Log an error message, used for actual errors
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log a wtf message, used for exceptional failures
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
} 
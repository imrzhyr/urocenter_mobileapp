import 'package:logger/logger.dart';
import 'logger.dart';

/// Error handler utility
class ErrorHandler {
  /// Handle error and return user-friendly message
  static String handleError(dynamic error) {
    AppLogger.e('An error occurred', error);
    
    if (error is FormatException) {
      return 'Invalid format: ${error.message}';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  
  /// Log error to analytics service (placeholder for future implementation)
  static void logErrorToAnalytics(dynamic error, StackTrace? stackTrace) {
    // TODO: Implement error logging to analytics service
    AppLogger.e('Error logged to analytics', error, stackTrace);
  }
} 
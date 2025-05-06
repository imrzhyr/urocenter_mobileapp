// import 'package:flutter/material.dart'; // Removed unused import
import 'package:flutter/services.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Enum representing the possible payment status types
enum PaymentStatusType {
  pending,
  completed,
  failed,
  canceled,
  unknown
}

/// Service class for handling FIB Payment integration
class FibPaymentService {
  static const MethodChannel _channel = MethodChannel('com.urocenter.fib_payment');
  
  /// Initiates a payment process with FIB
  /// 
  /// [amount] - Payment amount
  /// [currencyCode] - Currency code (e.g., 'IQD')
  /// [description] - Description of the payment
  /// [redirectUri] - Optional URI for redirecting back to app
  /// 
  /// Returns a payment ID if successful, null otherwise
  Future<String?> initiatePayment({
    required double amount,
    required String currencyCode,
    required String description,
    String? redirectUri,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'amount': amount,
        'currencyCode': currencyCode,
        'description': description,
        'redirectUri': redirectUri,
      };
      
      final String? paymentId = await _channel.invokeMethod('initiatePayment', params);
      return paymentId;
    } catch (e) {
      AppLogger.e('Error initiating FIB payment: $e');
      return null;
    }
  }
  
  /// Checks the status of a payment
  /// 
  /// [paymentId] - The ID of the payment to check
  /// 
  /// Returns the payment status
  Future<PaymentStatusType?> checkPaymentStatus(String paymentId) async {
    try {
      final String? statusString = await _channel.invokeMethod(
        'checkPaymentStatus', 
        {'paymentId': paymentId}
      );
      
      // Convert status string to enum
      if (statusString == null) return null;
      
      switch (statusString.toLowerCase()) {
        case 'pending':
          return PaymentStatusType.pending;
        case 'completed':
          return PaymentStatusType.completed;
        case 'failed':
          return PaymentStatusType.failed;
        case 'canceled':
          return PaymentStatusType.canceled;
        default:
          return PaymentStatusType.unknown;
      }
    } catch (e) {
      AppLogger.e('Error checking payment status: $e');
      return null;
    }
  }
  
  /// Cancels an ongoing payment
  /// 
  /// [paymentId] - The ID of the payment to cancel
  /// 
  /// Returns whether cancellation was successful
  Future<bool> cancelPayment(String paymentId) async {
    try {
      return await _channel.invokeMethod('cancelPayment', {'paymentId': paymentId}) ?? false;
    } catch (e) {
      AppLogger.e('Error canceling payment: $e');
      return false;
    }
  }
} 

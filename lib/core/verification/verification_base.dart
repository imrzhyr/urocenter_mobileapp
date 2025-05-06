import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/theme.dart';
// import '../widgets/widgets.dart'; // Removed unused import
import '../utils/utils.dart';

/// Base verification state and logic to be shared across different verification screens
abstract class VerificationBase<T extends StatefulWidget> extends State<T> {
  bool isLoading = false;
  bool isVerified = false;
  Timer? resendTimer;
  int remainingSeconds = 60;
  
  @override
  void dispose() {
    cancelTimer();
    super.dispose();
  }
  
  /// Cancel timer safely
  void cancelTimer() {
    if (resendTimer != null) {
      resendTimer!.cancel();
      resendTimer = null;
    }
  }
  
  /// Start resend timer with a duration of 60 seconds
  void startResendTimer() {
    remainingSeconds = 60;
    cancelTimer();
    
    if (!mounted) return;
    
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }
  
  /// Show an error message to the user
  void showError(String message) {
    if (!mounted) return;
    
    NavigationUtils.showSnackBar(
      context,
      message,
      backgroundColor: AppColors.error,
    );
  }
  
  /// Show a success message to the user
  void showSuccess(String message) {
    if (!mounted) return;
    
    NavigationUtils.showSnackBar(
      context,
      message,
      backgroundColor: AppColors.success,
    );
  }
  
  /// Set loading state with setState
  void setLoading(bool loading) {
    if (!mounted) return;
    setState(() => isLoading = loading);
  }
  
  /// Set verified state with setState
  void setVerified(bool verified) {
    if (!mounted) return;
    setState(() => isVerified = verified);
  }

  /// Navigate safely after verification is complete
  void navigateAfterVerification(String routeName, {Object? extra});
}

/// Interface for classes that need verification navigation
abstract class VerificationAware {
  /// Navigate after verification is complete
  void navigateAfterVerification(String routeName, {Object? extra});
} 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'dart:async'; // Import dart:async for Timer
import 'package:easy_localization/easy_localization.dart'; // Added import
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../../../core/constants/constants.dart';
import '../../../core/animations/animations.dart';
import '../../../providers/service_providers.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Phone verification screen for user authentication
class PhoneVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  
  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _pinEntryAnimation;
  String? _verificationId;
  int? _resendToken;
  bool _hasError = false;
  
  // <<< Add Test Credentials Constants >>>
  static const String _testVerificationId = 'test-verification-id';
  static const String _testSmsCode = '123455'; // Matches SignInScreen
  
  // --- State Properties ---
  bool isLoading = false;
  bool isVerified = false;
  Timer? _resendTimer;
  int remainingSeconds = AppConstants.otpResendTimeoutSeconds;
  bool canResend = false; // Add canResend state variable
  // --- End State Properties ---
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _pinEntryAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
       startResendTimer();
       _sendOtp();
    });
  }
  
  @override
  void dispose() {
    _otpController.dispose();
    _animationController.dispose();
    _resendTimer?.cancel(); // Cancel timer in dispose
    super.dispose();
  }
  
  // --- State Management and Timer Methods ---
  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        isLoading = loading;
      });
    }
  }

  void setVerified(bool verified) {
    if (mounted) {
      setState(() {
        isVerified = verified;
      });
    }
  }

  void cancelTimer() {
    _resendTimer?.cancel();
  }

  void startResendTimer() {
    setState(() {
      canResend = false; // Set canResend here
      remainingSeconds = AppConstants.otpResendTimeoutSeconds;
    });
    cancelTimer(); // Cancel any existing timer
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (remainingSeconds > 0) {
            remainingSeconds--;
          } else {
            timer.cancel();
            // Set canResend to true when timer finishes
            if (mounted) {
              setState(() {
                canResend = true;
              });
            }
          }
        });
      } else {
        timer.cancel(); // Ensure timer is cancelled if widget is disposed
      }
    });
  }
  
  // --- UI Feedback Methods (using ScaffoldMessenger) ---
  void showError(String message) {
    if (mounted) {
      final theme = Theme.of(context); // Get theme
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: theme.colorScheme.error, 
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void showSuccess(String message) {
    if (mounted) {
       final theme = Theme.of(context); // Get theme
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: theme.colorScheme.secondary, // Or a dedicated success color if defined
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // --- End Integrated Methods ---
  
  Future<void> _sendOtp() async {
    if (isLoading || !mounted) return;
    setLoading(true);
    _hasError = false;
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onCodeAutoRetrievalTimeout,
      );
    } catch (e) {
      AppLogger.e('Error sending OTP: $e');
      if (mounted) {
        _hasError = true;
        showError(ErrorHandler.handleError(e));
        setLoading(false);
        _animateErrorState();
      }
    }
  }

  void _onVerificationCompleted(PhoneAuthCredential credential) async {
    if (!mounted) return;
    AppLogger.d('Auto-verification completed!');
    try {
      setLoading(true);
      final authService = ref.read(authServiceProvider);
      await authService.signInWithPhoneCredential(credential);
      
      await _animationController.reverse();
      if (mounted) {
         cancelTimer();
         context.goNamed(RouteNames.profileSetup);
      }
    } catch (e) {
      AppLogger.e('Error in auto-verification: $e');
      if (mounted) {
        _hasError = true;
        setLoading(false);
        showError(ErrorHandler.handleError(e));
        _animateErrorState();
      }
    }
  }

  void _onVerificationFailed(FirebaseAuthException e) {
    if (!mounted) return;
    AppLogger.e('Verification failed: ${e.message}');
    setLoading(false);
    _hasError = true;
    showError(ErrorHandler.handleError(e));
    _animateErrorState();
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    if (!mounted) return;
    
    AppLogger.d('OTP sent to ${widget.phoneNumber}');
    _verificationId = verificationId;
    _resendToken = resendToken;
    
    setLoading(false);
    showSuccess('auth.verification_code_sent'.tr());
  }

  void _onCodeAutoRetrievalTimeout(String verificationId) {
    if (!mounted) return;
    
    AppLogger.d('Auto-retrieval timeout');
    _verificationId = verificationId;
  }
  
  void _animateErrorState() {
    // Shake animation for errors
    _animationController
      ..reset()
      ..forward();
  }
  
  Future<void> _verifyOtp() async {
    if (isLoading || !mounted) return;
    
    final otp = _otpController.text.trim();
    if (otp.length != AppConstants.otpLength) {
      _hasError = true;
      showError('errors.invalid_verification_code'.tr());
      _animateErrorState();
      return;
    }
    
    if (_verificationId == null) {
      _hasError = true;
      showError('errors.verification_id_missing'.tr());
      _animateErrorState();
      return;
    }
    
    setLoading(true);
    _hasError = false;
    
    try {
      final authService = ref.read(authServiceProvider);
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await authService.signInWithPhoneCredential(credential);
      
      if (mounted) {
        // Cancel timer before navigating
        cancelTimer();
        
        // Animate out before navigation
        await _animationController.reverse();
        context.goNamed(RouteNames.profileSetup);
      }
    } catch (e) {
      // Show error message
      AppLogger.e('Verification error: $e');
      if (mounted) {
        _hasError = true;
        String errorMessageKey = 'auth.verification_failed'; // Default key
        if (e is FirebaseAuthException) {
          if (e.code == 'invalid-verification-code') {
            errorMessageKey = 'errors.invalid_verification_code';
          } else if (e.code == 'session-expired') {
            errorMessageKey = 'errors.session_expired';
          }
        }
        
        showError(errorMessageKey.tr());
        _animateErrorState();
      }
    } finally {
      if (mounted) {
        setLoading(false);
      }
    }
  }
  
  Future<void> _resendOtp() async {
    if (remainingSeconds > 0 || isLoading || !mounted) return;
    
    try {
      await _sendOtp();
      startResendTimer();
    } catch (e) {
      // Error is already handled in _sendOtp
    }
  }

  /// Handle back navigation safely
  void _handleBack() {
    cancelTimer();
    
    // Slide out animation before navigating
    _animationController.reverse().then((_) {
      try {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.goNamed(RouteNames.signUp);
        }
      } catch (e) {
        // Fallback
        context.goNamed(RouteNames.signUp);
      }
    });
  }
  
  void navigateAfterVerification(String routeName, {Object? extra}) {
    cancelTimer();
    context.goNamed(routeName, extra: extra);
  }

  void _handleOtpChange(String value) {
    // Auto-submit when all digits are entered
    if (value.length == AppConstants.otpLength && mounted) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.appBarTheme.iconTheme?.color),
          onPressed: _handleBack,
        ),
      ),
      persistentFooterButton: PulseButton(
        text: 'auth.verify_button'.tr(),
        onPressed: _verifyOtp,
        isLoading: isLoading,
        icon: Icons.check_circle_outline,
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Add shake animation for errors
          final dx = _hasError ? math.sin(_animationController.value * 4 * 3.14159) * 10 : 0.0;
          
          return Transform.translate(
            offset: Offset(dx, 0),
            child: child,
          );
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with animated fade in
                AnimatedContent(
                  entryType: AnimationEntryType.fadeSlideDown,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    'auth.verification'.tr(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                AnimatedContent(
                  entryType: AnimationEntryType.fadeSlideDown,
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 100),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: 'auth.verification_intro'.tr(),
                        ),
                        TextSpan(
                          text: widget.phoneNumber,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // OTP Field with scale animation
                FadeTransition(
                  opacity: _pinEntryAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(_pinEntryAnimation),
                    child: PinCodeTextField(
                      appContext: context,
                      length: AppConstants.otpLength,
                      controller: _otpController,
                      onCompleted: (_) => _verifyOtp(),
                      onChanged: _handleOtpChange,
                      keyboardType: TextInputType.number,
                      animationType: AnimationType.fade,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(12.0),
                        fieldHeight: 50,
                        fieldWidth: 45,
                        activeFillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceContainerHighest,
                        inactiveFillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceContainerHighest,
                        selectedFillColor: theme.inputDecorationTheme.fillColor ?? theme.colorScheme.surfaceContainerHighest,
                        activeColor: theme.colorScheme.primary,
                        inactiveColor: theme.inputDecorationTheme.enabledBorder?.borderSide.color ?? theme.colorScheme.outline,
                        selectedColor: theme.colorScheme.primary,
                        borderWidth: 1,
                      ),
                      animationDuration: const Duration(milliseconds: 300),
                      enableActiveFill: true,
                      cursorColor: theme.colorScheme.primary,
                      autoFocus: true, // Optional: auto-focus on the field
                      beforeTextPaste: (text) {
                        // Allow pasting
                        return true;
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Resend button with delayed animation
                AnimatedContent(
                  entryType: AnimationEntryType.fadeIn,
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 400),
                  child: TextButton(
                    onPressed: canResend ? _resendOtp : null, // Enable only when canResend is true
                    style: TextButton.styleFrom(
                      foregroundColor: canResend ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      padding: EdgeInsets.zero, // Remove default padding
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Minimize tap area
                    ),
                    child: Text(
                      canResend
                          ? 'auth.resend_code'.tr()
                          : 'auth.resend_in_seconds'.tr(namedArgs: {'seconds': remainingSeconds.toString()}),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                
                // Security note
                const SizedBox(height: 48),
                AnimatedContent(
                  entryType: AnimationEntryType.fadeSlideUp,
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 600),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(isDark ? 0.4 : 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: theme.colorScheme.primary,
                          size: 22
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'auth.verification_code_private'.tr(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 

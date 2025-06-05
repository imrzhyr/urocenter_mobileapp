import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/theme.dart';
import '../../providers/service_providers.dart';
import 'package:urocenter/core/utils/logger.dart';
import '../utils/haptic_utils.dart';

class GoogleSignInButton extends ConsumerStatefulWidget {
  final Function(bool) onSignInStarted;
  final Function(UserCredential) onSignInSuccess;
  final Function(dynamic) onSignInError;
  
  const GoogleSignInButton({
    super.key,
    required this.onSignInStarted,
    required this.onSignInSuccess,
    required this.onSignInError,
  });

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    HapticUtils.lightTap();
    setState(() => _isLoading = true);
    widget.onSignInStarted(true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();
      
      if (userCredential != null) {
        widget.onSignInSuccess(userCredential);
      } else {
        AppLogger.d("Google Sign in cancelled by user.");
      }
    } catch (e) {
      widget.onSignInError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSignInStarted(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/google_logo.png',
                  height: 22.0,
                  width: 22.0,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'auth.continue_with_google'.tr(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 

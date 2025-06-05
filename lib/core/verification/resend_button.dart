import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../utils/haptic_utils.dart';

/// A reusable button for resending verification codes with a timer
class ResendButton extends StatelessWidget {
  final int remainingSeconds;
  final VoidCallback onResend;

  const ResendButton({
    super.key,
    required this.remainingSeconds,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Didn\'t receive the code?', 
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: remainingSeconds == 0 
            ? () {
                HapticUtils.lightTap();
                onResend();
              } 
            : null,
          child: Text(
            remainingSeconds == 0 
              ? 'Resend Code' 
              : 'Resend in $remainingSeconds s',
            style: TextStyle(
              color: remainingSeconds == 0 
                ? AppColors.primary 
                : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
} 
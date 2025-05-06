import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../theme/theme.dart';
import '../constants/constants.dart';

/// A reusable OTP input field widget for verification screens
class OtpField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onCompleted;
  final Function(String) onChanged;

  const OtpField({
    super.key,
    required this.controller,
    required this.onCompleted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: AppConstants.otpLength,
      controller: controller,
      keyboardType: TextInputType.number,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(12),
        fieldHeight: 56,
        fieldWidth: 45,
        activeFillColor: AppColors.inputBackground,
        inactiveFillColor: AppColors.inputBackground,
        selectedFillColor: AppColors.inputBackground,
        activeColor: AppColors.primary,
        inactiveColor: AppColors.inputBorder,
        selectedColor: AppColors.primary,
      ),
      cursorColor: AppColors.primary,
      enableActiveFill: true,
      animationType: AnimationType.scale,
      animationDuration: const Duration(milliseconds: 300),
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      onChanged: onChanged,
      onCompleted: onCompleted,
    );
  }
} 
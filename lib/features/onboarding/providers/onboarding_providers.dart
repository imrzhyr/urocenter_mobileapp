import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// State class for the persistent onboarding button
@immutable
class OnboardingButtonState {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const OnboardingButtonState({
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  // Optional: Method to copy state with changes
  OnboardingButtonState copyWith({
    String? text,
    VoidCallback? onPressed,
    bool? isLoading,
  }) {
    return OnboardingButtonState(
      text: text ?? this.text,
      onPressed: onPressed ?? this.onPressed,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Riverpod provider
final onboardingButtonProvider = StateProvider<OnboardingButtonState>((ref) {
  // Default initial state (can be adjusted)
  return const OnboardingButtonState(text: 'Continue', onPressed: null, isLoading: false);
}); 
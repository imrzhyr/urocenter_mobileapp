import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

/// A widget that shows the progress of the onboarding flow.
class OnboardingProgress extends StatelessWidget {
  /// The current step in the onboarding flow (0-indexed).
  final int currentStep;
  
  /// The total number of steps in the onboarding flow.
  final int totalSteps;
  
  /// Creates an [OnboardingProgress] widget.
  const OnboardingProgress({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  }) : assert(currentStep >= 0 && currentStep < totalSteps, 
             'Current step must be between 0 and totalSteps - 1');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator text
          Text(
            'Step ${currentStep + 1} of $totalSteps',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Progress bar
          Row(
            children: List.generate(totalSteps, (index) {
              // Determine if this step is completed, current, or upcoming
              final bool isCompleted = index < currentStep;
              final bool isCurrent = index == currentStep;
              
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: index < totalSteps - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: isCompleted 
                      ? AppColors.primary 
                      : (isCurrent ? AppColors.primaryLight : AppColors.divider),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
} 
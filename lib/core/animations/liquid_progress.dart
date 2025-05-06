import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// A modern, liquid-style progress indicator for onboarding flows
class LiquidProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final double height;
  final double indicatorSize;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Duration animationDuration;
  final bool showLabels;

  const LiquidProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.height = 6.0,
    this.indicatorSize = 16.0,
    this.backgroundColor,
    this.foregroundColor,
    this.animationDuration = const Duration(milliseconds: 600),
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? AppColors.divider.withValues(alpha: 128.0);
    final fgColor = foregroundColor ?? AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Background track
            Container(
              height: height,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
            
            // Animated foreground progress
            AnimatedContainer(
              duration: animationDuration,
              curve: Curves.easeOutCubic,
              height: height,
              width: MediaQuery.of(context).size.width * (currentStep / totalSteps),
              decoration: BoxDecoration(
                color: fgColor,
                borderRadius: BorderRadius.circular(height),
                boxShadow: [
                  BoxShadow(
                    color: fgColor.withValues(alpha: 128.0),
                    blurRadius: 6.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            
            // Step indicators
            ...List.generate(totalSteps, (index) {
              final stepPosition = (MediaQuery.of(context).size.width / totalSteps) * (index + 0.5);
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep - 1;
              
              return Positioned(
                left: stepPosition - (indicatorSize / 2),
                child: AnimatedContainer(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  height: indicatorSize,
                  width: indicatorSize,
                  decoration: BoxDecoration(
                    color: isCompleted ? fgColor : isCurrent ? fgColor : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted || isCurrent ? fgColor : bgColor,
                      width: 2.0,
                    ),
                    boxShadow: isCurrent ? [
                      BoxShadow(
                        color: fgColor.withValues(alpha: 153.0),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                      ),
                    ] : null,
                  ),
                  child: isCompleted ? const Icon(
                    Icons.check,
                    size: 10.0,
                    color: Colors.white,
                  ) : null,
                ),
              );
            }),
          ],
        ),
        
        // Optional step labels
        if (showLabels)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(totalSteps, (index) {
                final isCompleted = index < currentStep;
                final isCurrent = index == currentStep - 1;
                
                return Text(
                  'Step ${index + 1}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCompleted || isCurrent ? fgColor : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A reusable empty state widget with consistent styling.
///
/// Used to display empty states across the app with a consistent look and feel.
/// Features include:
/// - Customizable icon
/// - Primary message
/// - Secondary suggestion message
/// - Optional action button
class EmptyStateStyle2 extends StatelessWidget {
  /// The icon to display
  final IconData icon;
  
  /// The primary message to display
  final String message;
  
  /// The secondary suggestion message
  final String suggestion;
  
  /// Optional button text (if null, no button is shown)
  final String? buttonText;
  
  /// Optional button icon (if null, no icon is shown on the button)
  final IconData? buttonIcon;
  
  /// Callback when the button is pressed
  final VoidCallback? onButtonPressed;
  
  const EmptyStateStyle2({
    super.key,
    required this.icon,
    required this.message,
    required this.suggestion,
    this.buttonText,
    this.buttonIcon,
    this.onButtonPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message.tr(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: buttonIcon != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(buttonIcon),
                          const SizedBox(width: 8),
                          Text(buttonText!.tr()),
                        ],
                      )
                    : Text(buttonText!.tr()),
              ),
            ]
          ],
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';

/// A reusable empty state widget that shows an icon, title and message
class EmptyState extends StatelessWidget {
  /// The icon to display
  final IconData icon;
  
  /// The title text
  final String title;
  
  /// The message text
  final String message;
  
  /// Optional action button
  final Widget? actionButton;
  
  /// Constructor
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 128.0),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
} 
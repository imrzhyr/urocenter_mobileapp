import 'package:flutter/material.dart';

/// A reusable metric card component for displaying simple metrics with icons.
///
/// This component is used to display key metrics with an icon, value, and title.
class MetricCardStyle2 extends StatelessWidget {
  /// The title/label of the metric
  final String title;
  
  /// The value to display
  final String value;
  
  /// The icon to display
  final IconData icon;
  
  /// The color of the icon
  final Color color;
  
  /// Optional box shadow
  final bool showShadow;
  
  /// Optional padding
  final EdgeInsetsGeometry padding;
  
  /// Optional callback when tapped
  final VoidCallback? onTap;
  
  const MetricCardStyle2({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.showShadow = true,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: showShadow ? [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDarkMode ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    
    return content;
  }
} 
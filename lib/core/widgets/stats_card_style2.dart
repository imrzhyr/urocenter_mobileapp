import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_utils.dart';

/// A reusable stats card component for displaying metric data with change indicators.
///
/// Features:
/// - Title and metric value display
/// - Change indicator with percentage
/// - Customizable icon with background
/// - Responsive width support
class StatsCardStyle2 extends StatelessWidget {
  /// Title of the stat
  final String title;
  
  /// Value to display (formatted as needed)
  final String value;
  
  /// Percentage change (positive or negative)
  final double change;
  
  /// Icon to display
  final IconData icon;
  
  /// Color for the icon
  final Color iconColor;
  
  /// Fixed width for the card (optional)
  final double? width;
  
  /// Custom comparison text (defaults to "vs previous")
  final String? comparisonText;
  
  /// Card elevation
  final double elevation;
  
  /// Optional callback when card is tapped
  final VoidCallback? onTap;
  
  const StatsCardStyle2({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    required this.iconColor,
    this.width,
    this.comparisonText,
    this.elevation = 0,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final isPositive = change > 0;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    Color changeColor = isPositive 
        ? (isDarkMode ? AppColors.successDarkTheme : AppColors.success)
        : (isDarkMode ? AppColors.errorDarkTheme : AppColors.error);
    
    if (change == 0) {
      changeColor = isDarkMode 
          ? theme.colorScheme.onSurfaceVariant 
          : theme.colorScheme.onSurfaceVariant;
    }
    
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isDarkMode ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: changeColor,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${change.abs().toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: changeColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              comparisonText ?? 'vs previous',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
    
    final container = Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: elevation > 0 ? [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: elevation,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: cardContent,
    );
    
    // If there's an onTap callback, wrap in InkWell
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticUtils.lightTap();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(16),
          child: container,
        ),
      );
    }
    
    return container;
  }
} 
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A reusable badge component to display status information.
///
/// Used consistently across the app to display various statuses like
/// active, completed, urgent, etc.
class StatusBadgeStyle2 extends StatelessWidget {
  /// The text to display in the badge
  final String text;
  
  /// The color of the badge
  final Color color;
  
  /// Optional icon to display before the text
  final IconData? icon;
  
  /// Size of the text
  final double? fontSize;
  
  /// Optional custom padding
  final EdgeInsetsGeometry? padding;
  
  const StatusBadgeStyle2({
    super.key,
    required this.text,
    required this.color,
    this.icon,
    this.fontSize,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: fontSize ?? 11,
            ),
          ),
        ],
      ),
    );
  }
} 
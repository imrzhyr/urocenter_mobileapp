import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_utils.dart';

/// A simple circular button with an icon, background, and tap feedback.
class CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double iconSize;

  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = Colors.grey,
    this.iconColor = Colors.white,
    this.size = 56.0,
    this.iconSize = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      elevation: 2.0, // Add some default elevation
      clipBehavior: Clip.antiAlias, // Ensure ripple stays within bounds
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed != null ? () {
          HapticUtils.lightTap();
          onPressed!();
        } : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }
} 
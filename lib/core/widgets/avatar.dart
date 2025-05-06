import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/string_utils.dart';

/// A customizable avatar widget that can display either an image or initials
class Avatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;
  final Widget? child;

  const Avatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40.0,
    this.backgroundColor,
    this.textColor,
    this.border,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final defaultBackgroundColor = backgroundColor ?? AppColors.primary;
    final defaultTextColor = textColor ?? Colors.white;
    
    if (child != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: defaultBackgroundColor,
        child: child,
      );
    }
    
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
          image: DecorationImage(
            image: NetworkImage(imageUrl!),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              // Fallback to initials on error
            },
          ),
        ),
      );
    }
    
    // Display initials if no image or if image loading fails
    final initials = StringUtils.getInitials(name ?? '');
    
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: defaultBackgroundColor,
      child: Text(
        initials,
        style: TextStyle(
          color: defaultTextColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';

/// A reusable user avatar component with consistent styling.
///
/// Can display either a network image or a text avatar with the first letter
/// of the user's name.
class UserAvatarStyle2 extends StatelessWidget {
  /// The user's name
  final String name;
  
  /// Optional image URL
  final String? imageUrl;
  
  /// Whether the user/context is marked as urgent
  final bool isUrgent;
  
  /// Radius of the avatar
  final double radius;
  
  /// Optional background color (used when no urgency is specified)
  final Color? backgroundColor;
  
  /// Optional text color
  final Color? textColor;
  
  const UserAvatarStyle2({
    super.key,
    required this.name,
    this.imageUrl,
    this.isUrgent = false,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // If image URL is provided and valid, show image avatar
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // If image loading fails, fall back to text avatar
          return;
        },
        child: null,
      );
    }
    
    // Otherwise show text avatar
    final Color bgColor = backgroundColor ?? (isUrgent
        ? theme.colorScheme.error.withOpacity(isDarkMode ? 0.8 : 0.1)
        : theme.colorScheme.primary.withOpacity(isDarkMode ? 0.5 : 0.1));
        
    final Color txtColor = textColor ?? (isUrgent
        ? theme.colorScheme.error
        : theme.colorScheme.primary);
    
    return CircleAvatar(
      backgroundColor: bgColor,
      radius: radius,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: TextStyle(
          color: txtColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_utils.dart';
import 'status_badge_style2.dart';
import 'user_avatar_style2.dart';

/// A reusable component for displaying user information in a list.
///
/// Can be used for showing users in admin screens, recent users lists,
/// or user selection interfaces.
class UserListItemStyle2 extends StatelessWidget {
  /// User's name
  final String name;
  
  /// User's avatar image URL (optional)
  final String? imageUrl;
  
  /// Primary subtitle (can be email, phone, etc.)
  final String? subtitle;
  
  /// Secondary subtitle (optional)
  final String? secondarySubtitle;
  
  /// Status label
  final String statusLabel;
  
  /// Status color
  final Color statusColor;
  
  /// Callback when the item is tapped
  final VoidCallback? onTap;
  
  /// Optional join date string
  final String? joinDateString;
  
  /// Optional trailing widget
  final Widget? trailing;
  
  /// Optional leading widget (if not provided, uses UserAvatarStyle2 with name)
  final Widget? leading;
  
  /// Whether to show a border
  final bool showBorder;
  
  const UserListItemStyle2({
    super.key,
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.secondarySubtitle,
    required this.statusLabel,
    required this.statusColor,
    this.onTap,
    this.joinDateString,
    this.trailing,
    this.leading,
    this.showBorder = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Determine what contact information to display first (email or phone)
    final String? primaryContact = subtitle != null && subtitle!.isNotEmpty 
        ? subtitle  // This is usually email
        : secondarySubtitle != null && secondarySubtitle!.isNotEmpty
            ? secondarySubtitle  // This is usually phone
            : null;
    
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12), // Match chat list margin
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: showBorder ? BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ) : BorderSide.none,
        ),
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap != null 
              ? () {
                  HapticUtils.lightTap();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12), // Match chat list padding
            child: Row(
              children: [
                // Avatar
                leading ?? UserAvatarStyle2(
                  name: name,
                  imageUrl: imageUrl,
                  radius: 24, // Match chat list avatar radius
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Name and status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          trailing ?? StatusBadgeStyle2(
                            text: statusLabel,
                            color: statusColor,
                          ),
                        ],
                      ),
                      
                      // Second row: Primary contact info (email or phone)
                      if (primaryContact != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          primaryContact,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // Third row: Always show join date if available
                      if (joinDateString != null && joinDateString!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          joinDateString!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// Factory constructor for creating a user list item with default status styles
  factory UserListItemStyle2.withDefaultStatus({
    required String name,
    required bool isPaid,
    required bool isOnboarded,
    String? imageUrl,
    String? subtitle,
    String? secondarySubtitle,
    VoidCallback? onTap,
    String? joinDateString,
    Widget? trailing,
    Widget? leading,
    bool showBorder = true,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    String statusLabel;
    Color statusColor;
    
    if (isPaid) {
      statusLabel = "Paid";
      statusColor = isDarkMode ? AppColors.successDarkTheme : AppColors.success;
    } else if (isOnboarded) {
      statusLabel = "Active";
      statusColor = isDarkMode ? AppColors.warningDarkTheme : AppColors.warning;
    } else {
      statusLabel = "New";
      statusColor = isDarkMode ? AppColors.primaryDarkTheme : theme.colorScheme.primary;
    }
    
    return UserListItemStyle2(
      name: name,
      imageUrl: imageUrl,
      subtitle: subtitle,
      secondarySubtitle: secondarySubtitle,
      statusLabel: statusLabel,
      statusColor: statusColor,
      onTap: onTap,
      joinDateString: joinDateString,
      trailing: trailing,
      leading: leading,
      showBorder: showBorder,
    );
  }
} 
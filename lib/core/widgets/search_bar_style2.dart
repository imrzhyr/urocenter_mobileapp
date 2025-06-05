import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';
import '../utils/haptic_utils.dart';

/// A reusable search bar component with enhanced styling.
///
/// Features include:
/// - Customizable hint text
/// - Clear button for text
/// - Optional filter button
/// - Enhanced visibility in both light and dark modes
class SearchBarStyle2 extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController? controller;
  
  /// Called when the text changes
  final Function(String)? onChanged;
  
  /// Hint text to display when empty
  final String hintText;
  
  /// Whether to show the filter button
  final bool showFilter;
  
  /// Whether filters are currently expanded/active
  final bool filtersActive;
  
  /// Called when the filter button is pressed
  final VoidCallback? onFilterToggle;

  const SearchBarStyle2({
    super.key,
    this.controller,
    this.onChanged,
    this.hintText = 'Search',
    this.showFilter = false,
    this.filtersActive = false,
    this.onFilterToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.inputBackgroundDark : AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.transparent : AppColors.searchBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText.tr(),
          hintStyle: TextStyle(
            color: isDarkMode 
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller != null && controller!.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    HapticUtils.lightTap();
                    controller?.clear();
                    onChanged?.call('');
                  },
                ),
              if (showFilter)
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: filtersActive 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    HapticUtils.lightTap();
                    onFilterToggle?.call();
                  },
                ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../app/routes.dart';
import '../utils/haptic_utils.dart';
import '../theme/app_colors.dart';
import 'search_bar_style2.dart';

/// A reusable app bar style used across the admin screens.
/// 
/// This app bar includes a title on the left and notification/settings buttons on the right.
/// It can also include a search bar and filter functionality.
class AppBarStyle2 extends StatefulWidget implements PreferredSizeWidget {
  /// The title displayed on the left side of the app bar
  final String title;
  
  /// Whether to show the search bar
  final bool showSearch;
  
  /// Whether to show filter options
  final bool showFilters;
  
  /// Whether filters are currently expanded
  final bool filtersExpanded;
  
  /// The search controller to use
  final TextEditingController? searchController;
  
  /// Callback when search text changes
  final Function(String)? onSearchChanged;
  
  /// Callback when the filter toggle button is pressed
  final VoidCallback? onFilterToggle;
  
  /// Filter options to display
  final List<FilterOption>? filterOptions;
  
  /// Currently selected filter
  final String? selectedFilter;
  
  /// Callback when a filter is selected
  final Function(String)? onFilterSelected;
  
  /// The height for the filter container when expanded
  final double filterHeight;
  
  /// Hint text for the search field
  final String searchHint;
  
  /// Whether to show a back button (typically for secondary screens)
  final bool showBackButton;
  
  /// Whether to show the notification and settings buttons
  final bool showActionButtons;
  
  /// Custom callback for when the back button is pressed
  final VoidCallback? onBackPressed;
  
  const AppBarStyle2({
    super.key,
    required this.title,
    this.showSearch = true,
    this.showFilters = true,
    this.filtersExpanded = false,
    this.searchController,
    this.onSearchChanged,
    this.onFilterToggle,
    this.filterOptions,
    this.selectedFilter,
    this.onFilterSelected,
    this.filterHeight = 60,
    this.searchHint = "Search",
    this.showBackButton = false,
    this.showActionButtons = true,
    this.onBackPressed,
  });

  @override
  State<AppBarStyle2> createState() => _AppBarStyle2State();

  @override
  Size get preferredSize {
    double totalHeight = 0;

    // Account for top padding inside SafeArea's child Padding widget
    totalHeight += 12.0; // const EdgeInsets.fromLTRB(16, 12, 16, 4) -> top

    // Title and actions row
    totalHeight += 40.0; // SizedBox(height: 40)

    // Search bar section
    if (this.showSearch) {
      totalHeight += 8.0; // const SizedBox(height: 8) - as per user's build method
      // Estimate for SearchBarStyle2:
      // TextField contentPadding vertical: 16+16=32. Font/line height ~20. Total ~52.
      totalHeight += 58.0; // Estimated height of SearchBarStyle2
    }

    // Filter chips section
    if (this.showFilters && this.filtersExpanded) {
      totalHeight += this.filterHeight; // Default is 60.0, from widget property
    }

    // Account for bottom padding inside SafeArea's child Padding widget
    totalHeight += 4.0; // const EdgeInsets.fromLTRB(16, 12, 16, 4) -> bottom
    
    // Add a small buffer for rounding errors (0.5px)
    totalHeight += 0.5;
    
    return Size.fromHeight(totalHeight);
  }
}

class _AppBarStyle2State extends State<AppBarStyle2> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _wasExpanded = false;

  @override
  void initState() {
    super.initState();
    _wasExpanded = widget.filtersExpanded;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.filtersExpanded ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(AppBarStyle2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the expanded state changed, animate accordingly
    if (widget.filtersExpanded != _wasExpanded) {
      if (widget.filtersExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      _wasExpanded = widget.filtersExpanded;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ClipRect(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and actions row
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button + Title
                      Expanded(
                        child: Row(
                          children: [
                            if (widget.showBackButton) ...[
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back_ios,
                                  color: theme.colorScheme.onBackground,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  HapticUtils.lightTap();
                                  if (widget.onBackPressed != null) {
                                    widget.onBackPressed!();
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Text(
                                widget.title.tr(),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onBackground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Action buttons (notifications, settings)
                      if (widget.showActionButtons)
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: theme.colorScheme.onBackground,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                // Navigate to notifications screen
                                HapticUtils.lightTap();
                                context.pushNamed(RouteNames.notifications);
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.settings_outlined,
                                color: theme.colorScheme.onBackground,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                // Navigate to settings screen
                                HapticUtils.lightTap();
                                context.pushNamed(RouteNames.settings);
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                // Search bar
                if (widget.showSearch) ...[
                  const SizedBox(height: 8),
                  SearchBarStyle2(
                    controller: widget.searchController,
                    onChanged: widget.onSearchChanged,
                    hintText: widget.searchHint,
                    showFilter: widget.showFilters,
                    filtersActive: widget.filtersExpanded,
                    onFilterToggle: widget.onFilterToggle,
                  ),
                ],
                
                // Filter chips
                if (widget.showFilters)
                  SizeTransition(
                    sizeFactor: _animationController.drive(CurveTween(curve: Curves.easeInOut)),
                    child: FadeTransition(
                      opacity: _animationController.drive(CurveTween(curve: Curves.easeInOut)),
                      child: Container(
                        height: widget.filterHeight,
                        margin: const EdgeInsets.only(top: 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: widget.filterOptions?.map((option) => _buildFilterChip(option)).toList() ?? [],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilterChip(FilterOption option) {
    final isSelected = option.value == widget.selectedFilter;
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(option.label.tr()),
        onSelected: (selected) {
          HapticUtils.selection();
          widget.onFilterSelected?.call(option.value);
        },
        backgroundColor: theme.colorScheme.surfaceVariant,
        selectedColor: theme.colorScheme.primaryContainer,
        checkmarkColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected 
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Data class for filter options
class FilterOption {
  final String value;
  final String label;
  
  const FilterOption({
    required this.value,
    required this.label,
  });
} 
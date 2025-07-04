import 'package:flutter/material.dart';
import '../utils/haptic_utils.dart';
import 'animated_gradient_top_border.dart';

/// A reusable navigation bar component that preserves the original design
/// with an animated gradient border at the top.
class NavigationBarStyle2 extends StatelessWidget {
  /// The currently selected index
  final int selectedIndex;
  
  /// The navigation items to display
  final List<NavigationItem> items;
  
  /// Callback when an item is selected
  final Function(int) onItemSelected;
  
  /// Height of the gradient border
  final double borderHeight;
  
  /// Duration of the gradient animation
  final Duration animationDuration;
  
  /// Background color of the navigation bar
  final Color? backgroundColor;
  
  /// Indicator color for selected items
  final Color? indicatorColor;

  const NavigationBarStyle2({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    this.borderHeight = 3.0,
    this.animationDuration = const Duration(seconds: 2),
    this.backgroundColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Standard Navigation Bar
        NavigationBar(
          elevation: 0,
          backgroundColor: backgroundColor ?? theme.colorScheme.surface,
          onDestinationSelected: (index) {
            HapticUtils.lightTap();
            onItemSelected(index);
          },
          selectedIndex: selectedIndex,
          indicatorColor: indicatorColor ?? theme.colorScheme.primaryContainer,
          destinations: items.map((item) => NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon ?? item.icon),
            label: item.label,
          )).toList(),
        ),
        
        // Animated gradient border at the top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedGradientTopBorder(
            height: borderHeight,
            duration: animationDuration,
          ),
        ),
      ],
    );
  }
}

/// Data class for navigation items
class NavigationItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String? routeName;
  
  const NavigationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.routeName,
  });
} 
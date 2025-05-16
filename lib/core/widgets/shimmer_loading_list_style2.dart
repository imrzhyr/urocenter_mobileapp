import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';

/// A reusable shimmer loading list component.
///
/// Displays a list of shimmer loading placeholders with consistent styling
/// and animations across the app.
class ShimmerLoadingListStyle2 extends StatelessWidget {
  /// Number of items to display
  final int itemCount;
  
  /// Height of each item
  final double itemHeight;
  
  /// Padding around the list
  final EdgeInsetsGeometry padding;
  
  /// Shape of each item
  final ShapeBorder? itemShape;
  
  /// Base color for the shimmer effect
  final Color? baseColor;
  
  /// Highlight color for the shimmer effect
  final Color? highlightColor;
  
  const ShimmerLoadingListStyle2({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 90,
    this.padding = const EdgeInsets.all(16),
    this.itemShape,
    this.baseColor,
    this.highlightColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Default colors based on theme
    final defaultBaseColor = isDarkMode 
        ? const Color(0xFF303030) 
        : Colors.grey.shade300;
    final defaultHighlightColor = isDarkMode 
        ? const Color(0xFF3E3E3E) 
        : Colors.grey.shade100;
    
    return Shimmer.fromColors(
      baseColor: baseColor ?? defaultBaseColor,
      highlightColor: highlightColor ?? defaultHighlightColor,
      child: AnimationLimiter(
        child: ListView.builder(
          padding: padding,
          itemCount: itemCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 300),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      height: itemHeight,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: itemShape != null 
                            ? null 
                            : BorderRadius.circular(12),
                        shape: itemShape != null 
                            ? BoxShape.rectangle 
                            : BoxShape.rectangle,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// A reusable animated list component with staggered animations.
///
/// This component provides a consistent way to display lists with animations
/// across the app.
class AnimatedItemListStyle2<T> extends StatelessWidget {
  /// The items to display in the list
  final List<T> items;
  
  /// Builder function to create a widget for each item
  final Widget Function(BuildContext, T, int) itemBuilder;
  
  /// Builder function for empty state
  final Widget Function()? emptyBuilder;
  
  /// Padding around the list
  final EdgeInsetsGeometry padding;
  
  /// Duration of the animation
  final Duration animationDuration;
  
  /// Vertical offset for the slide animation
  final double verticalOffset;
  
  /// Optional physics for the list
  final ScrollPhysics? physics;
  
  /// Optional controller for the list
  final ScrollController? controller;
  
  /// Whether to shrink wrap the list
  final bool shrinkWrap;
  
  const AnimatedItemListStyle2({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyBuilder,
    this.padding = const EdgeInsets.all(16),
    this.animationDuration = const Duration(milliseconds: 300),
    this.verticalOffset = 50.0,
    this.physics,
    this.controller,
    this.shrinkWrap = false,
  });
  
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyBuilder != null) {
      return emptyBuilder!();
    }
    
    return AnimationLimiter(
      child: ListView.builder(
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: padding,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: animationDuration,
            child: SlideAnimation(
              verticalOffset: verticalOffset,
              child: FadeInAnimation(
                child: itemBuilder(context, items[index], index),
              ),
            ),
          );
        },
      ),
    );
  }
} 
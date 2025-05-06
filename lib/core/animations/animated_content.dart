import 'package:flutter/material.dart';

/// Animated content loading for UI components
class AnimatedContent extends StatelessWidget {
  /// The child widget to animate
  final Widget child;
  
  /// The animation entry type
  final AnimationEntryType entryType;
  
  /// Duration of the entry animation
  final Duration duration;
  
  /// Delay before starting the animation
  final Duration delay;
  
  /// Distance for slide animations
  final double slideDistance;

  const AnimatedContent({
    super.key,
    required this.child,
    this.entryType = AnimationEntryType.fadeIn,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.slideDistance = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        switch (entryType) {
          case AnimationEntryType.fadeIn:
            return Opacity(
              opacity: value,
              child: child,
            );
            
          case AnimationEntryType.fadeSlideUp:
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, slideDistance * (1.0 - value)),
                child: child,
              ),
            );
            
          case AnimationEntryType.fadeSlideDown:
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -slideDistance * (1.0 - value)),
                child: child,
              ),
            );
            
          case AnimationEntryType.fadeSlideLeft:
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(slideDistance * (1.0 - value), 0),
                child: child,
              ),
            );
            
          case AnimationEntryType.fadeSlideRight:
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(-slideDistance * (1.0 - value), 0),
                child: child,
              ),
            );
            
          case AnimationEntryType.zoomIn:
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: child,
              ),
            );
            
          case AnimationEntryType.zoomOut:
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 1.2 - (0.2 * value),
                child: child,
              ),
            );
            
          case AnimationEntryType.bounce:
            // Custom curve for bounce effect
            const bounceCurve = ElasticOutCurve(0.6);
            final bounceValue = bounceCurve.transform(value);
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: bounceValue,
                child: child,
              ),
            );
        }
      },
      child: child,
    );
  }
  
  /// Factory constructor for creating staggered content
  static Widget staggered({
    required List<Widget> children,
    AnimationEntryType entryType = AnimationEntryType.fadeSlideUp,
    Duration duration = const Duration(milliseconds: 600),
    Duration staggerDuration = const Duration(milliseconds: 100),
    double slideDistance = 30.0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(children.length, (index) {
        return AnimatedContent(
          delay: Duration(milliseconds: index * staggerDuration.inMilliseconds),
          duration: duration,
          entryType: entryType, 
          slideDistance: slideDistance,
          child: children[index],
        );
      }),
    );
  }
}

/// A layout builder that animates child widgets in a staggered sequence
class StaggeredAnimatedList extends StatelessWidget {
  final List<Widget> children;
  final AnimationEntryType entryType;
  final Duration duration;
  final Duration staggerDelay;
  final double slideDistance;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final bool staggerFromBottom;

  const StaggeredAnimatedList({
    super.key,
    required this.children,
    this.entryType = AnimationEntryType.fadeSlideUp,
    this.duration = const Duration(milliseconds: 600),
    this.staggerDelay = const Duration(milliseconds: 100),
    this.slideDistance = 30.0,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.staggerFromBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: List.generate(children.length, (index) {
        // Calculate index based on stagger direction
        final staggerIndex = staggerFromBottom ? (children.length - 1 - index) : index;
        
        return AnimatedContent(
          delay: Duration(milliseconds: staggerIndex * staggerDelay.inMilliseconds),
          duration: duration,
          entryType: entryType,
          slideDistance: slideDistance,
          child: children[index],
        );
      }),
    );
  }
}

/// Enum for different types of animations
enum AnimationEntryType {
  fadeIn,
  fadeSlideUp,
  fadeSlideDown, 
  fadeSlideLeft,
  fadeSlideRight,
  zoomIn,
  zoomOut,
  bounce
} 
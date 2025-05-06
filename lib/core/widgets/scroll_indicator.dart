import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// A widget that indicates there is more content to scroll down to.
/// 
/// This widget provides a visual cue that helps users understand
/// they can scroll for additional content below the current view.
class ScrollIndicator extends StatefulWidget {
  /// The controller to watch for scroll position updates.
  final ScrollController? controller;
  
  /// Whether to show the indicator.
  final bool isVisible;
  
  /// The position of the indicator from the bottom.
  final double bottomPosition;
  
  /// Creates a scroll indicator widget.
  const ScrollIndicator({
    super.key,
    this.controller,
    this.isVisible = true,
    this.bottomPosition = 20.0,
  });

  @override
  State<ScrollIndicator> createState() => _ScrollIndicatorState();
}

class _ScrollIndicatorState extends State<ScrollIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _opacityAnimation;
  bool _showIndicator = true;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Bounce animation for the indicator
    _bounceAnimation = Tween<double>(begin: 0, end: 3)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_animationController);
    
    // Opacity animation for fading in/out
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0)
      .animate(CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ));
    
    // Start bounce animation and repeat it
    _animationController.repeat(reverse: true);
    
    if (widget.controller != null) {
      widget.controller!.addListener(_checkScrollPosition);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    if (widget.controller != null) {
      widget.controller!.removeListener(_checkScrollPosition);
    }
    super.dispose();
  }
  
  void _checkScrollPosition() {
    if (widget.controller == null) return;
    
    // Start fade-out animation when user scrolls past threshold
    if (widget.controller!.offset > 100 && _showIndicator) {
      setState(() => _showIndicator = false);
      _animationController.forward(from: 0.0).then((_) {
        // Animation is done, no need to continue showing
      });
    } else if (widget.controller!.offset <= 100 && !_showIndicator) {
      // Fade back in if we scroll back to top
      setState(() => _showIndicator = true);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      bottom: widget.bottomPosition,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // If we're animating out, use the opacity animation
          // Otherwise just show the indicator with bounce effect
          final opacityValue = !_showIndicator 
              ? _opacityAnimation.value 
              : 1.0;
          
          // Hide completely when fully faded out
          if (!_showIndicator && opacityValue == 0) {
            return const SizedBox.shrink();
          }
          
          return Opacity(
            opacity: opacityValue,
            child: Transform.translate(
              offset: Offset(0, _bounceAnimation.value),
              child: child,
            ),
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 26.0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Scroll for more',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
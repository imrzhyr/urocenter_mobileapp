import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../utils/haptic_utils.dart';

/// An animated button that provides visual feedback on press
class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isDisabled;
  final bool isLoading;
  final Widget? icon;

  const AnimatedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isOutlined = false,
    this.isDisabled = false,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (!widget.isDisabled && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(_) {
    if (!widget.isDisabled && !widget.isLoading) {
      _controller.reverse();
      HapticUtils.lightTap();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (!widget.isDisabled && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme data
    final colorScheme = theme.colorScheme; // Get color scheme
    final bool isDisabledOrLoading = widget.isDisabled || widget.isLoading;

    // Determine theme-based colors
    final Color effectiveBackgroundColor = widget.isOutlined 
        ? Colors.transparent 
        : isDisabledOrLoading
          ? colorScheme.onSurface.withAlpha(31) 
          : colorScheme.primary;

    final Color effectiveForegroundColor = widget.isOutlined
        ? isDisabledOrLoading
          ? colorScheme.onSurface.withAlpha(97) 
          : colorScheme.primary
        : isDisabledOrLoading
          ? colorScheme.onSurface.withAlpha(97) 
          : colorScheme.onPrimary;
          
    final Color effectiveBorderColor = widget.isOutlined
        ? isDisabledOrLoading
          ? colorScheme.outline.withAlpha(31) 
          : colorScheme.primary
        : Colors.transparent; // No border if not outlined

    final Color effectiveShadowColor = widget.isOutlined || isDisabledOrLoading
        ? Colors.transparent // No shadow if outlined or disabled
        : colorScheme.shadow.withAlpha(38); 
        
    final Color effectiveSplashColor = widget.isOutlined
        ? colorScheme.primary.withAlpha(31)
        : colorScheme.onPrimary.withAlpha(31);
        
    final Color effectiveProgressIndicatorColor = widget.isOutlined
        ? colorScheme.primary
        : colorScheme.onPrimary;

    // Clone icon with theme color if provided
    final Widget? themedIcon = widget.icon != null
        ? IconTheme.merge(
            data: IconThemeData(color: effectiveForegroundColor, size: 20), // Use determined foreground color
            child: widget.icon!,
          )
        : null;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: effectiveBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: widget.isOutlined 
              ? Border.all(
                  color: effectiveBorderColor,
                  width: 1.5,
                )
              : null,
            boxShadow: [
                  BoxShadow(
                    color: effectiveShadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ]
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Button content
              AnimatedOpacity(
                opacity: widget.isLoading ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (themedIcon != null) ...[
                      themedIcon,
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: effectiveForegroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Loading indicator
              if (widget.isLoading)
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      effectiveProgressIndicatorColor,
                    ),
                  ),
                ),
                
              // Ripple effect
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: effectiveSplashColor,
                  highlightColor: Colors.transparent,
                  onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
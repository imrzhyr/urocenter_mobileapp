import 'package:flutter/material.dart';
// import '../theme/theme.dart'; // Removed unused import

/// An animated pulsing button that provides visual feedback on hover and press
class PulseButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final IconData? icon;
  final double height;
  final double? width;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final double elevation;

  const PulseButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.icon,
    this.height = 56.0,
    this.width,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.textColor,
    this.elevation = 2.0,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    
    // Start a gentle pulsing animation if not disabled
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update animation state based on button state
    if (widget.onPressed == null || widget.isLoading) {
      _animationController.stop();
    } else if (!_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHoverChange(bool isHovered) {
    if (_isHovered != isHovered) {
      setState(() {
        _isHovered = isHovered;
      });
    }
  }

  void _handlePressChange(bool isPressed) {
    if (_isPressed != isPressed) {
      setState(() {
        _isPressed = isPressed;
      });
      
      if (isPressed) {
        _animationController.stop();
        _animationController.animateTo(1.0, duration: const Duration(milliseconds: 150));
      } else if (widget.onPressed != null && !widget.isLoading) {
        _animationController.repeat(reverse: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDisabled = widget.onPressed == null || widget.isLoading;
    
    // Determine base background and text colors using theme
    final Color baseBgColor = widget.backgroundColor ?? 
        (widget.isPrimary ? colorScheme.primary : Colors.transparent);
    final Color baseTxtColor = widget.textColor ?? 
        (widget.isPrimary ? colorScheme.onPrimary : colorScheme.primary);
    
    // Calculate effective colors based on state
    final effectiveBgColor = isDisabled 
        ? (widget.isPrimary 
            // Disabled fill color (e.g., onSurface @ 12%)
            ? colorScheme.onSurface.withAlpha(31) 
            : baseBgColor) // Keep transparent if secondary and disabled
        : _isHovered 
            ? (widget.isPrimary 
                // Hovered primary: Slightly darker/lighter primary or primaryContainer
                ? colorScheme.primaryContainer.withAlpha(200) // Example: Darken primary slightly
                // Hovered secondary: Subtle background like surfaceContainerHighest
                : colorScheme.surfaceContainerHighest.withAlpha(77)) 
            : baseBgColor;
        
    final effectiveTxtColor = isDisabled
        // Disabled text color (e.g., onSurface @ 38%)
        ? colorScheme.onSurface.withAlpha(97)
        : baseTxtColor;
        
    final effectiveBorderColor = !widget.isPrimary 
        ? isDisabled
            // Disabled outline color (e.g., outline @ 30%)
            ? colorScheme.outline.withAlpha(77)
            : _isHovered || _isPressed 
                ? colorScheme.primary // Use primary for border when hovered/pressed
                : colorScheme.outline // Default outline color
        : null;
        
    final effectiveElevation = _isPressed 
        ? 0.5 
        : _isHovered 
            ? widget.elevation * 1.5 
            : widget.elevation;
            
    final effectiveShadowColor = widget.isPrimary && !isDisabled
        // Use theme shadow color with alpha
        ? colorScheme.shadow.withAlpha(77)
        : Colors.transparent;
    
    return MouseRegion(
      onEnter: (_) => _handleHoverChange(true),
      onExit: (_) => _handleHoverChange(false),
      child: GestureDetector(
        onTapDown: (_) => _handlePressChange(true),
        onTapUp: (_) {
          _handlePressChange(false);
          widget.onPressed?.call();
        },
        onTapCancel: () => _handlePressChange(false),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final scale = _isPressed 
                ? _scaleAnimation.value 
                : (_isHovered ? 1.02 : 1.0);
            
            return Transform.scale(
              scale: scale,
              child: Container(
                width: widget.width ?? double.infinity,
                height: widget.height,
                decoration: BoxDecoration(
                  color: effectiveBgColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: effectiveBorderColor != null 
                      ? Border.all(
                          color: effectiveBorderColor, 
                          width: 1.5, // Consistent width
                        ) 
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveShadowColor,
                      blurRadius: effectiveElevation * 4,
                      spreadRadius: effectiveElevation,
                      offset: const Offset(0, 2),
                    ),
                  ] ,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Button content with icon if provided
                    AnimatedOpacity(
                      opacity: widget.isLoading ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: effectiveTxtColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: effectiveTxtColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Loading indicator
                    if (widget.isLoading)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(effectiveTxtColor),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 
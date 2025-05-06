import 'package:flutter/material.dart';
import 'scroll_indicator.dart';

/// A widget that wraps scrollable content and shows an indicator
/// when there's more content below the viewport.
class ScrollableContent extends StatefulWidget {
  /// The child widget that will be scrollable.
  final Widget child;
  
  /// Padding around the scrollable content.
  final EdgeInsetsGeometry padding;
  
  /// Whether to show the scroll indicator.
  final bool showIndicator;
  
  /// Additional padding at the bottom to ensure content isn't hidden
  /// behind the scroll indicator.
  final double bottomSpace;
  
  /// Creates a scrollable content widget with a scroll indicator.
  const ScrollableContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
    this.showIndicator = true,
    this.bottomSpace = 40.0,
  });

  @override
  State<ScrollableContent> createState() => _ScrollableContentState();
}

class _ScrollableContentState extends State<ScrollableContent> {
  final ScrollController _scrollController = ScrollController();
  bool _showIndicator = false;
  
  @override
  void initState() {
    super.initState();
    // We need to wait for the layout to be rendered before we can
    // determine if the content is scrollable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfContentIsScrollable();
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _checkIfContentIsScrollable() {
    if (!mounted || !_scrollController.hasClients) return;
    
    setState(() {
      // If the max scroll extent is greater than a small tolerance (e.g., 1.0),
      // it means there's significant content out of view.
      _showIndicator = _scrollController.position.maxScrollExtent > 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate effective padding conditionally
    final EdgeInsets resolvedPadding = widget.padding.resolve(Directionality.of(context));
    final EdgeInsets effectivePadding = _showIndicator 
        ? resolvedPadding.copyWith(bottom: resolvedPadding.bottom + widget.bottomSpace)
        : resolvedPadding; // Use original padding if no scroll indicator
        
    return Stack(
      children: [
        // The scrollable content
        GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: _scrollController,
            // Use the effective padding that includes bottomSpace
            padding: effectivePadding, 
            physics: const AlwaysScrollableScrollPhysics(), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The main content - SizedBox is no longer needed here
                widget.child,
              ],
            ),
          ),
        ),
        
        // The scroll indicator (visibility still based on _showIndicator)
        if (widget.showIndicator)
          ScrollIndicator(
            controller: _scrollController,
            isVisible: _showIndicator,
          ),
      ],
    );
  }
} 
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/widgets/circular_loading_indicator.dart';
import 'package:urocenter/core/utils/logger.dart';

// --- Convert to StatefulWidget ---
class FullscreenImageViewer extends StatefulWidget {
  final String imagePath;

  const FullscreenImageViewer({super.key, required this.imagePath});

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  // --- State for Drag-to-Dismiss ---
  double _verticalDragOffset = 0.0;
  bool _isDragging = false; 
  // Minimum drag distance (pixels) to trigger dismiss
  static const double _dismissThreshold = 100.0; 
  // --- End State ---

  @override
  Widget build(BuildContext context) {
    // Determine if the path is a network URL or a local file
    final bool isNetworkImage = 
        widget.imagePath.startsWith('http://') || widget.imagePath.startsWith('https://');

    // Choose the appropriate Image widget
    Widget imageWidget;
    if (isNetworkImage) {
      imageWidget = Image.network(
        widget.imagePath,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularLoadingIndicator(
              color: Colors.white
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          AppLogger.e("Error loading fullscreen network image: $error");
          return const Center(
            child: Text(
              'Could not load image.',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );
    } else {
      // Assume it's a local file path
      File imageFile = File(widget.imagePath);
      imageWidget = Image.file(
         imageFile,
         fit: BoxFit.contain,
         errorBuilder: (context, error, stackTrace) {
            AppLogger.e("Error loading fullscreen local file image: $error");
             // Check if file exists before showing generic error
            if (!imageFile.existsSync()) {
              return const Center(
                child: Text(
                  'Image file not found.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            } else {
               return const Center(
                child: Text(
                  'Could not load image file.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
         },
      );
    }

    // --- Calculate background opacity based on drag ---
    // Dim background as user drags down
    double backgroundOpacity = 1.0 - (_verticalDragOffset.abs() / (_dismissThreshold * 2)).clamp(0.0, 0.6);
    // --- End Opacity Calculation ---

    return Scaffold(
      // Use animated opacity for background dimming
      backgroundColor: Colors.black.withValues(alpha: backgroundOpacity * 255),
      appBar: AppBar(
        // Animate app bar opacity as well
        backgroundColor: Colors.black.withValues(alpha: 0.7 * backgroundOpacity * 255),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
         // --- Add Drag Handlers ---
         onVerticalDragStart: (details) {
           setState(() {
             _isDragging = true;
             _verticalDragOffset = 0.0; // Reset offset
           });
         },
         onVerticalDragUpdate: (details) {
           setState(() {
             // Allow dragging down only
             _verticalDragOffset += details.delta.dy;
             // Optional: Clamp negative drag to prevent dragging up beyond original position
             if (_verticalDragOffset < 0) _verticalDragOffset = 0;
           });
         },
         onVerticalDragEnd: (details) {
           final flingVelocity = details.primaryVelocity ?? 0;
           setState(() {
              _isDragging = false;
           });

           // Check if drag distance OR velocity exceeds threshold
           if (_verticalDragOffset > _dismissThreshold || flingVelocity > 1000) { 
              Navigator.of(context).pop();
           } else {
             // Animate back to original position if not dismissed
             setState(() {
                _verticalDragOffset = 0.0;
             });
           }
         },
         // --- End Drag Handlers ---
        child: Center(
          // --- Animate Position based on Drag Offset ---
          child: AnimatedContainer(
            duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200), // Animate back if not dismissed
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _verticalDragOffset, 0),
            child: InteractiveViewer( 
          minScale: 0.5,
          maxScale: 4.0,
              // Disable pan/zoom while user is doing the dismiss drag
              // interactionEndFrictionCoefficient: _isDragging ? 0.1 : 0.000135, // Adjust friction if needed
              scaleEnabled: !_isDragging, // Disable zoom during dismiss drag
              panEnabled: !_isDragging, // Disable pan during dismiss drag
              child: imageWidget,
            ),
          ),
          // --- End Animated Position ---
        ),
      ),
    );
  }
} 

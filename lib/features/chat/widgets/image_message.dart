import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/models/message_model.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/widgets/circular_loading_indicator.dart';

/// A widget that displays an image message in a chat bubble
class ImageMessage extends StatelessWidget {
  final Message message;
  final BorderRadius borderRadius;

  const ImageMessage({
    super.key,
    required this.message,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    const double placeholderSize = 150.0;
    
    Widget imageContent = const SizedBox.shrink();
    Widget indicatorWidget = const SizedBox.shrink();
    
    if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) {
      // Network image available
      imageContent = Image.network(
        message.mediaUrl!,
        width: placeholderSize,
        height: placeholderSize,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          final isLoaded = loadingProgress == null;
          
          return Container(
            width: placeholderSize,
            height: placeholderSize,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: borderRadius,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isLoaded)
                  CircularLoadingIndicator(
                    strokeWidth: 2.0,
                    color: Colors.white70,
                    showProgress: true,
                    value: loadingProgress?.expectedTotalBytes != null
                        ? loadingProgress!.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                AnimatedOpacity(
                  opacity: isLoaded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: child,
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          AppLogger.e("Error loading network image: $error");
          indicatorWidget = const Center(
            child: Icon(Icons.error_outline, color: Colors.white70, size: 30)
          );
          return const SizedBox.shrink();
        },
      );
    } else if (message.localFilePath != null) {
      // Local file path available (uploading)
      File imageFile = File(message.localFilePath!);
      if (imageFile.existsSync()) {
        imageContent = Image.file(
          imageFile,
          width: placeholderSize,
          height: placeholderSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.e("Error loading local file image: $error");
            indicatorWidget = const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 30)
            );
            return const SizedBox.shrink();
          },
        );
        
        indicatorWidget = Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(128),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 24)
          )
        );
      } else {
        AppLogger.d("Local image file not found at: ${message.localFilePath}");
        indicatorWidget = const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 30)
        );
      }
    } else {
      // Neither URL nor local path - show placeholder icon
      indicatorWidget = const Center(
        child: Icon(Icons.image_outlined, color: Colors.white70, size: 40)
      );
    }
    
    return GestureDetector(
      onTap: () {
        HapticUtils.lightTap();
        final pathOrUrl = message.mediaUrl ?? message.localFilePath;
        if (pathOrUrl != null && pathOrUrl.isNotEmpty) {
          context.pushNamed(RouteNames.imageViewer, extra: pathOrUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image source not available.')),
          );
        }
      },
      child: Container(
        width: placeholderSize,
        height: placeholderSize,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.grey[300]),
              imageContent,
              indicatorWidget,
            ],
          ),
        ),
      ),
    );
  }
} 
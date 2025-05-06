import 'package:flutter/material.dart';
import 'dart:io';
import '../../../core/theme/theme.dart';
import '../../../core/utils/utils.dart';
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Types of documents that can be uploaded
enum DocumentType {
  image,
  file,
}

/// Model representing an uploaded document during onboarding
class UploadedDocument {
  final String name;
  final int size;
  final String? downloadUrl;
  final DateTime dateUploaded;
  final DocumentType type;

  UploadedDocument({
    required this.name,
    required this.size,
    this.downloadUrl,
    required this.dateUploaded,
    required this.type,
  });
}

/// Widget displaying an uploaded document with options to view or delete it
class UploadDocumentTile extends StatelessWidget {
  final UploadedDocument document;
  final VoidCallback onDelete;
  final VoidCallback? onView;

  const UploadDocumentTile({
    super.key,
    required this.document,
    required this.onDelete,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail/Icon Area
          SizedBox(
            width: 44, // Define thumbnail width
            height: 44, // Define thumbnail height
            child: ClipRRect( // Clip the image to rounded corners
              borderRadius: BorderRadius.circular(8),
              child: document.type == DocumentType.image &&
                   document.downloadUrl != null &&
                   document.downloadUrl!.isNotEmpty
                // Display Image Thumbnail from Network URL
                ? Image.network(
                    document.downloadUrl!,
                      fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      );
                    },
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback icon if image fails to load
                      AppLogger.e("Error loading onboarding image preview: $error");
                        return Container(
                          color: AppColors.primary.withValues(alpha: 26.0),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        );
                      },
                    )
                  // Display File Icon
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 26.0),
                        // borderRadius is handled by ClipRRect
                      ),
                      child: const Icon(
                        Icons.insert_drive_file,
                        color: AppColors.accent,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Document info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${StringUtils.formatFileSize(document.size)} • ${AppDateUtils.formatDate(document.dateUploaded)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View button
              IconButton(
                onPressed: () {
                  HapticUtils.lightTap();
                  if (onView != null) {
                    onView!();
                  } else {
                    // Default view action
                  if (document.type == DocumentType.image) {
                    _viewImage(context, document);
                  } else {
                    NavigationUtils.showSnackBar(
                      context,
                      'File viewing not implemented yet',
                      backgroundColor: AppColors.info,
                    );
                    }
                  }
                },
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'View',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
              const SizedBox(width: 12),
              
              // Delete button
              IconButton(
                onPressed: () {
                  HapticUtils.lightTap();
                  onDelete();
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewImage(BuildContext context, UploadedDocument document) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(
                document.name,
                style: const TextStyle(fontSize: 16),
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  HapticUtils.lightTap();
                  Navigator.pop(context);
                },
              ),
              centerTitle: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: document.downloadUrl != null && document.downloadUrl!.isNotEmpty
                    ? Image.network(
                        document.downloadUrl!,
                  fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                           if (loadingProgress == null) return child;
                           return const Center(child: CircularProgressIndicator());
                        },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text('Error loading image'),
                    );
                  },
                      )
                    : const Center( // Fallback if URL is missing
                        child: Text('Image URL not available'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

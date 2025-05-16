import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:io';
import '../../../core/models/message_model.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/permission_manager.dart';
import '../../../providers/service_providers.dart';

/// Utility class for handling message options and actions
class MessageOptions {
  /// Shows a bottom sheet with options for a message
  static void showMessageOptions(BuildContext context, Message message, WidgetRef ref) {
    List<Widget> options = [];
    
    // Option: Save Image
    if (message.type == MessageType.image && (message.mediaUrl != null || message.localFilePath != null)) {
      options.add(
        ListTile(
          leading: Icon(Icons.save_alt, color: Theme.of(context).colorScheme.primary),
          title: Text('Save Image', style: Theme.of(context).textTheme.bodyMedium),
          onTap: () async {
            HapticUtils.lightTap();
            Navigator.pop(context);
            await _saveImage(context, message);
          },
        )
      );
    }
    
    // Option: Delete Message
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isSender = message.id.isNotEmpty && message.senderId == currentUserId;
    final messageTimestamp = message.createdAt;
    final bool withinTimeLimit = DateTime.now().difference(messageTimestamp).inMinutes < 5;
    
    if (isSender && withinTimeLimit) {
      options.add(
        ListTile(
          leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
          title: Text('Delete for Everyone', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          onTap: () async {
            HapticUtils.lightTap();
            Navigator.pop(context);
            await _deleteMessage(context, message, ref);
          },
        )
      );
    }
    
    if (options.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext bc) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Wrap(
                children: [
                  ...options,
                  Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor),
                  ListTile(
                    leading: Icon(Icons.cancel_outlined, color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153)),
                    title: Text('Cancel', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(153))),
                    onTap: () {
                      HapticUtils.lightTap();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
  
  /// Saves an image message to the device gallery
  static Future<void> _saveImage(BuildContext context, Message message) async {
    final bool hasPermission = await PermissionManager.requestPhotosPermission(context);
    if (!hasPermission) {
      DialogUtils.showMessageDialog(
        context: context,
        title: 'Permission Denied',
        message: 'Storage permission is required to save images.'
      );
      return;
    }
    
    Uint8List? imageBytes;
    String imageName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    try {
      if (message.mediaUrl != null) {
        final response = await http.get(Uri.parse(message.mediaUrl!));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
          imageName = message.mediaUrl!.split('/').last.split('?').first;
        } else {
          throw Exception('Failed to download image: ${response.statusCode}');
        }
      } else if (message.localFilePath != null) {
        File imageFile = File(message.localFilePath!);
        if (await imageFile.exists()) {
          imageBytes = await imageFile.readAsBytes();
          imageName = message.localFilePath!.split('/').last;
        }
      }
      
      if (imageBytes != null) {
        final result = await ImageGallerySaver.saveImage(imageBytes, name: imageName, isReturnImagePathOfIOS: true);
        if (result['isSuccess'] ?? false) HapticUtils.mediumTap();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['isSuccess'] ?? false ? 'Image saved successfully!' : 'Failed to save image.'))
          );
        }
      } else {
        throw Exception('Image source not available');
      }
    } catch (e) {
      AppLogger.e("Error saving image: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving image. Please try again.'))
        );
      }
    }
  }
  
  /// Deletes a message after confirmation
  static Future<void> _deleteMessage(BuildContext context, Message message, WidgetRef ref) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Delete Message?',
      message: 'Are you sure you want to permanently delete this message?',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    
    if (confirmed) {
      HapticUtils.heavyTap();
      try {
        final chatService = ref.read(chatServiceProvider);
        await chatService.deleteMessage(message.chatId, message.id);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted.'))
          );
        }
      } catch (e) {
        AppLogger.e("Error deleting message: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete message. Please try again.'))
          );
        }
      }
    }
  }
} 
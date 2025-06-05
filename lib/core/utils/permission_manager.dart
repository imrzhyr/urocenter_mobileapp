import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'haptic_utils.dart';

/// Utility class to handle app permissions
class PermissionManager {
  
  /// Initialize and request critical permissions early in the app lifecycle
  static Future<void> initializePermissions() async {
    if (Platform.isIOS) {
      // On iOS, we pre-check permissions to understand their initial state.
      // The actual request should happen when the feature is first used.
      final micStatus = await Permission.microphone.status;
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      
      AppLogger.d('Initial permission status check - Microphone: $micStatus, Camera: $cameraStatus, Photos: $photosStatus');
      
      // Removed the .request() calls from here. 
      // Requests will be handled by image_picker, flutter_sound, or specific calls 
      // like requestMicrophonePermission when the features are accessed.
    }

    // --- Removed Notification Permission Request --- 
    // Notification permission should be requested when the feature needing it is used.
  }
  
  /// Reset iOS permissions
  static Future<void> resetIOSPermissions(BuildContext context) async {
    if (Platform.isIOS) {
      // This will open iOS settings where the user can reset permissions
      await openAppSettings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'permissions.ios_reset_instruction'.tr(),
            style: const TextStyle(fontSize: 14),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
  
  /// Request microphone permission with fallback for permanently denied state
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    final status = await Permission.microphone.status;
    
    if (status.isPermanentlyDenied) {
      // Show dialog explaining how to fix it in settings
      if (context.mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('permissions.microphone_required_title'.tr()),
            content: Text('permissions.microphone_required_message'.tr()),
            actions: [
              TextButton(
                onPressed: () {
                  HapticUtils.lightTap();
                  Navigator.pop(context, false);
                },
                child: Text('permissions.not_now'.tr()),
              ),
              TextButton(
                onPressed: () {
                  HapticUtils.mediumTap();
                  Navigator.pop(context, true);
                },
                child: Text('permissions.open_settings'.tr()),
              ),
            ],
          ),
        );
        
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    }
    
    if (status.isGranted) {
      return true;
    }
    
    // Request permission normally
    final result = await Permission.microphone.request();
    return result.isGranted;
  }
  
  /// Request photos (write/add) permission with fallback for permanently denied state
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    // Use Permission.photos for iOS 14+ (add/write access)
    // For older iOS or Android, Storage permission might be involved, 
    // but permission_handler often abstracts this. Let's stick with .photos for now.
    const permission = Permission.photos; 
    final status = await permission.status;
    
    if (status.isPermanentlyDenied) {
      // Show dialog explaining how to fix it in settings
      if (context.mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('permissions.photos_required_title'.tr()),
            content: Text('permissions.photos_required_message'.tr()),
            actions: [
              TextButton(
                onPressed: () {
                  HapticUtils.lightTap();
                  Navigator.pop(context, false);
                },
                child: Text('permissions.not_now'.tr()),
              ),
              TextButton(
                onPressed: () {
                  HapticUtils.mediumTap();
                  Navigator.pop(context, true);
                },
                child: Text('permissions.open_settings'.tr()),
              ),
            ],
          ),
        );
        
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    }
    
    if (status.isGranted || status.isLimited) { // Consider limited access as granted for saving
      return true;
    }
    
    // Request permission normally
    final result = await permission.request();
    return result.isGranted || result.isLimited; // Allow limited access too
  }
} 

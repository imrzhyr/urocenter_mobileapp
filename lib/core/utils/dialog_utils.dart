import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'haptic_utils.dart';

/// Utility class for displaying dialogs with consistent styling
class DialogUtils {
  /// Shows a confirmation dialog with buttons spaced apart (cancel on left, confirm on right)
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'common.cancel',
    String confirmText = 'common.confirm',
    Color? confirmColor,
    bool barrierDismissible = true,
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        title: Text(title, style: theme.dialogTheme.titleTextStyle),
        content: Text(message, style: theme.dialogTheme.contentTextStyle),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  HapticUtils.lightTap();
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  cancelText.tr(),
                  style: theme.textButtonTheme.style?.textStyle?.resolve({})?.copyWith(
                     color: colorScheme.onSurfaceVariant
                  ) ?? TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticUtils.mediumTap();
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  confirmText.tr(),
                  style: theme.textButtonTheme.style?.textStyle?.resolve({})?.copyWith(
                     color: confirmColor ?? colorScheme.primary,
                     fontWeight: FontWeight.bold,
                  ) ?? TextStyle(
                    color: confirmColor ?? colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ), 
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Shows a simple message dialog with a single OK button
  static Future<void> showMessageDialog({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'common.ok',
  }) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: theme.dialogTheme.titleTextStyle),
        content: Text(message, style: theme.dialogTheme.contentTextStyle),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                HapticUtils.lightTap();
                Navigator.of(context).pop();
              },
              child: Text(
                buttonText.tr(),
                style: theme.textButtonTheme.style?.textStyle?.resolve({})?.copyWith(
                     color: colorScheme.primary,
                     fontWeight: FontWeight.bold,
                   ) ?? TextStyle(
                     color: colorScheme.primary,
                     fontWeight: FontWeight.bold,
                  ), 
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
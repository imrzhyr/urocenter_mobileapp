import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/constants.dart';
import '../providers/locale_provider.dart';
import '../theme/theme.dart';
import '../utils/haptic_utils.dart';

/// A widget for selecting the app language
class LanguageSelector extends ConsumerWidget {
  /// Whether to show minimal version (button opening a modal)
  final bool isMinimal;
  
  /// Constructor
  const LanguageSelector({
    super.key,
    this.isMinimal = false,
  });

  // --- Method to show the modal bottom sheet --- 
  void showLanguagePicker(BuildContext context) {
    HapticUtils.lightTap(); // Haptic for opening the picker
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0), // Add padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    'settings.select_language'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Map languages to ListTiles
                ...AppConstants.supportedLanguages.map((language) {
                  final currentLocale = context.locale;
                  final localeParts = language.locale.split('_');
                  final itemLocale = localeParts.length > 1
                      ? Locale(localeParts[0], localeParts[1])
                      : Locale(localeParts[0]);
                  final isSelected = currentLocale == itemLocale;
                  
                  return ListTile(
                    leading: _buildFlagIcon(language.code, ctx),
                    title: Text(language.nameKey.tr()),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      HapticUtils.selection();
                      context.setLocale(itemLocale);
                      Navigator.pop(ctx); // Close the bottom sheet
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // --- Helper to build flag icon --- 
  Widget _buildFlagIcon(String languageCode, BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 30,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor, width: 0.5),
        ),
        child: Image.asset(
          'assets/images/flags/$languageCode.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: theme.colorScheme.surfaceVariant,
              child: Center(
                child: Text(
                  languageCode.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = context.locale;
    final currentLangCode = currentLocale.languageCode;
    
    if (isMinimal) {
      // --- Minimal Version: Button opens Modal --- 
      return GestureDetector(
        onTap: () => showLanguagePicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 26.0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFlagIcon(currentLangCode, context),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
    } else {
      // --- Full Version: Horizontal Row (Original Logic) --- 
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 13.0),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.language,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'settings.language'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            // Language options
            ...AppConstants.supportedLanguages.map((language) {
              final isSelected = currentLangCode == language.code;
              final localeParts = language.locale.split('_');
              final itemLocale = localeParts.length > 1
                  ? Locale(localeParts[0], localeParts[1])
                  : Locale(localeParts[0]);
              
              return GestureDetector(
                onTap: () {
                  HapticUtils.selection();
                  context.setLocale(itemLocale);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 26.0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildFlagIcon(language.code, context),
                      const SizedBox(width: 8),
                      Text(
                        language.nameKey.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }
  }
} 
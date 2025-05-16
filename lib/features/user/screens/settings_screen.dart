import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/theme.dart';
import '../../../app/routes.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../providers/service_providers.dart';
import '../../../core/utils/haptic_utils.dart';
import '../../../providers/theme_provider.dart';
import '../../../core/widgets/language_selector.dart';
import 'package:urocenter/core/utils/logger.dart';
import '../../../core/widgets/app_bar_style2.dart';

/// Settings screen for user account
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _hasEmailPassword = false;
  
  @override
  void initState() {
    super.initState();
    _checkAuthMethod();
  }
  
  // Check if user signed in with email/password
  void _checkAuthMethod() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if user has email provider
      setState(() {
        _hasEmailPassword = user.providerData.any(
          (info) => info.providerId == 'password'
        );
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale;
    final currentLanguage = currentLocale.languageCode == 'ar' ? 'Arabic' : 'English';
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          AppBarStyle2(
            title: 'settings.title'.tr(),
            showBackButton: true,
            showActionButtons: false,
            showSearch: false,
            showFilters: false,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.account_settings'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Account settings
                  _buildSettingsCard(
                    context: context,
                    children: [
                      if (_hasEmailPassword) 
                        _buildSettingsTile(
                          context: context,
                          title: 'settings.change_password'.tr(),
                          icon: Icons.lock_outline,
                          onTap: () {
                            _showChangePasswordDialog();
                          },
                        ),
                      if (_hasEmailPassword)
                        Divider(height: 1, indent: 56, endIndent: 0, color: theme.dividerColor),
                      _buildSettingsTile(
                        context: context,
                        title: 'settings.notifications'.tr(),
                        icon: Icons.notifications_none,
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            HapticUtils.selection();
                            setState(() {
                              _notificationsEnabled = value;
                            });
                            _updateNotificationSettings(value);
                          },
                          activeColor: theme.colorScheme.primary,
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Icon(Icons.notifications_active);
                             }
                              return const Icon(Icons.notifications_off);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'settings.app_settings'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // App settings
                  _buildSettingsCard(
                    context: context,
                    children: [
                      _buildSettingsTile(
                        context: context,
                        title: 'settings.language'.tr(),
                        icon: Icons.language,
                        subtitle: currentLanguage,
                        onTap: () {
                          // Use the reusable language selector component
                          const LanguageSelector().showLanguagePicker(context);
                        },
                      ),
                      Divider(height: 1, indent: 56, endIndent: 0, color: theme.dividerColor),
                      _buildSettingsTile(
                        context: context,
                        title: 'settings.dark_mode'.tr(),
                        icon: Icons.dark_mode_outlined,
                        trailing: Switch(
                          value: themeMode == ThemeMode.dark,
                          onChanged: (value) {
                            HapticUtils.selection();
                            ref.read(themeModeProvider.notifier).toggleThemeMode();
                          },
                          activeColor: theme.colorScheme.primary,
                          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Icon(Icons.dark_mode);
                             }
                              return const Icon(Icons.light_mode);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'settings.about_section'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // About settings
                  _buildSettingsCard(
                    context: context,
                    children: [
                      _buildSettingsTile(
                        context: context,
                        title: 'settings.about'.tr(),
                        icon: Icons.info_outline,
                        onTap: () {
                          context.pushNamed(RouteNames.about);
                        },
                      ),
                      Divider(height: 1, indent: 56, endIndent: 0, color: theme.dividerColor),
                      _buildSettingsTile(
                        context: context,
                        title: 'settings.terms_conditions'.tr(),
                        icon: Icons.description_outlined,
                        onTap: () {
                          context.pushNamed(RouteNames.terms);
                        },
                      ),
                      Divider(height: 1, indent: 56, endIndent: 0, color: theme.dividerColor),
                      _buildSettingsTile(
                        context: context,
                        title: 'settings.privacy_policy'.tr(),
                        icon: Icons.privacy_tip_outlined,
                        onTap: () {
                          context.pushNamed(RouteNames.privacyPolicy);
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Sign out button
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        splashColor: theme.colorScheme.error.withAlpha(26),
                        highlightColor: Colors.transparent,
                        onTap: () {
                          HapticUtils.lightTap();
                          _showSignOutDialog();
                        },
                        child: Center(
                          child: Text(
                            'auth.sign_out'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSettingsCard({required BuildContext context, required List<Widget> children}) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;
    final cardColor = cardTheme.color ?? theme.colorScheme.surfaceContainerLow;
    final cardShadowColor = cardTheme.shadowColor ?? theme.shadowColor;
    final cardShape = cardTheme.shape as RoundedRectangleBorder? ?? 
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final cardElevation = cardTheme.elevation ?? 2.0;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: cardShape.borderRadius as BorderRadius?,
        shape: BoxShape.rectangle,
        border: cardShape.side != BorderSide.none ? Border.fromBorderSide(cardShape.side) : null,
        boxShadow: [
          BoxShadow(
            color: cardShadowColor.withAlpha(isDark ? 51 : 26),
            blurRadius: cardElevation * 4,
            spreadRadius: cardElevation / 4,
            offset: Offset(0, cardElevation),
          ),
        ],
      ),
      clipBehavior: cardTheme.clipBehavior ?? Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
  
  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final VoidCallback? wrappedOnTap = onTap == null ? null : () {
      HapticUtils.lightTap();
      onTap();
    };
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      leading: Icon(
        icon,
        color: theme.colorScheme.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null),
      onTap: wrappedOnTap,
    );
  }
  
  void _showSignOutDialog() async {
    final theme = Theme.of(context);
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'auth.sign_out'.tr(),
      message: 'settings.confirm_sign_out_message'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'auth.sign_out'.tr(),
      confirmColor: theme.colorScheme.error,
    );
    
    if (confirmed == true) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        
        if (mounted) {
           context.go('/');
        }
      } catch (e) {
         AppLogger.e("Error during sign out: $e");
         if (mounted) {
            DialogUtils.showMessageDialog(
               context: context, 
               title: 'settings.sign_out_error_title'.tr(),
               message: 'settings.sign_out_error_message'.tr()
            );
         }
      }
    }
  }
  
  void _showDeleteAccountDialog() {
    final theme = Theme.of(context);
    DialogUtils.showConfirmationDialog(
      context: context,
      title: 'settings.delete_account'.tr(),
      message: 'settings.confirm_delete_message'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'settings.delete_account'.tr(),
      confirmColor: theme.colorScheme.error,
    ).then((confirmed) async {
      if (confirmed) {
        try {
          // Show a progress indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );
          
          // Get current user
          final user = FirebaseAuth.instance.currentUser;
          
          if (user != null) {
            // For email users, we need to reauthenticate first
            if (user.providerData.any((info) => info.providerId == 'password')) {
              // Show reauthentication dialog
              if (mounted) {
                Navigator.of(context).pop(); // Dismiss loading dialog
                _showReauthenticationDialog(user);
                return;
              }
            } else {
              // For other providers (Google, phone), we can delete directly
              await user.delete();
            }
          }
          
          // Dismiss loading dialog if still showing
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          
          // Show success message and navigate to welcome screen
          if (mounted) {
            DialogUtils.showMessageDialog(
              context: context,
              title: 'settings.account_deleted_title'.tr(),
              message: 'settings.account_deleted_message'.tr(),
              buttonText: 'common.ok'.tr(),
            ).then((_) {
              context.goNamed(RouteNames.welcome, extra: true);
            });
          }
        } catch (e) {
          // Dismiss loading dialog if showing
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          
          // Show error message
          if (mounted) {
            DialogUtils.showMessageDialog(
              context: context,
              title: 'settings.delete_error_title'.tr(),
              message: 'settings.delete_error_message'.tr(),
              buttonText: 'common.ok'.tr(),
            );
          }
        }
      }
    });
  }
  
  // Show reauthentication dialog for email users before deleting account
  void _showReauthenticationDialog(User user) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('settings.confirm_identity'.tr()),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('settings.reenter_password'.tr()),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'auth.password'.tr(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'auth.password_required'.tr();
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop();
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                try {
                  // Create credential for reauthentication
                  if (user.email != null) {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: passwordController.text,
                    );
                    
                    // Reauthenticate
                    await user.reauthenticateWithCredential(credential);
                    
                    // Delete the user's data from Firestore first
                    await _deleteUserFirestoreData(user.uid);
                    
                    // Delete the user account
                    await user.delete();
                    
                    // Dismiss loading dialog
                    if (mounted && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    
                    // Show success message and navigate to welcome screen
                    if (mounted) {
                      DialogUtils.showMessageDialog(
                        context: context,
                        title: 'settings.account_deleted_title'.tr(),
                        message: 'settings.account_deleted_message'.tr(),
                        buttonText: 'common.ok'.tr(),
                      ).then((_) {
                        context.goNamed(RouteNames.welcome, extra: true);
                      });
                    }
                  }
                } catch (e) {
                  // Dismiss loading dialog
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // Show error message
                  if (mounted) {
                    DialogUtils.showMessageDialog(
                      context: context,
                      title: 'settings.delete_error_title'.tr(),
                      message: 'auth.incorrect_password'.tr(),
                      buttonText: 'common.ok'.tr(),
                    );
                  }
                }
              }
            },
            child: Text(
              'common.confirm'.tr(),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Delete all user data from Firestore
  Future<void> _deleteUserFirestoreData(String userId) async {
    final firestore = FirebaseFirestore.instance;
    
    try {
      // Delete user document and subcollections
      final userDocRef = firestore.collection('users').doc(userId);
      
      // 1. Delete documents subcollection
      final documentsSnapshot = await userDocRef.collection('documents').get();
      for (final doc in documentsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // 2. Delete notifications subcollection
      final notificationsSnapshot = await userDocRef.collection('notifications').get();
      for (final doc in notificationsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // 3. Find and delete chats where user is a participant
      final chatsQuery = await firestore.collection('chats')
          .where(FieldPath.documentId, whereIn: [
            // Chats may have ID format "userId_otherId" or "otherId_userId"
            ...await _findUserChatsStarting(userId, firestore),
            ...await _findUserChatsEnding(userId, firestore),
          ]).get();
      
      // Delete each chat document and its messages subcollection
      for (final chatDoc in chatsQuery.docs) {
        // Delete messages subcollection first
        final messagesSnapshot = await chatDoc.reference.collection('messages').get();
        for (final message in messagesSnapshot.docs) {
          await message.reference.delete();
        }
        // Then delete the chat document
        await chatDoc.reference.delete();
      }
      
      // 4. Finally delete the main user document
      await userDocRef.delete();
    } catch (e) {
      AppLogger.e('Error deleting user data: $e');
      // Continue with account deletion even if some data cleanup fails
    }
  }
  
  // Helper method to find chat IDs that start with the user's ID
  Future<List<String>> _findUserChatsStarting(String userId, FirebaseFirestore firestore) async {
    try {
      // Get the first 10 chats that start with userId_
      // Note: Firestore limitations may require paginating through results if a user has many chats
      final querySnapshot = await firestore.collection('chats')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
          .where(FieldPath.documentId, isLessThanOrEqualTo: '${userId}_\uf8ff')
          .limit(10)
          .get();
      
      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      AppLogger.e('Error finding chats starting with userId: $e');
      return [];
    }
  }
  
  // Helper method to find chat IDs that end with the user's ID
  Future<List<String>> _findUserChatsEnding(String userId, FirebaseFirestore firestore) async {
    try {
      // This is a workaround since Firestore doesn't support endsWith queries
      // Get all chats (limited to 100 for performance reasons) and filter client-side
      final querySnapshot = await firestore.collection('chats')
          .limit(100)
          .get();
      
      return querySnapshot.docs
          .where((doc) => doc.id.endsWith('_$userId'))
          .map((doc) => doc.id)
          .toList();
    } catch (e) {
      AppLogger.e('Error finding chats ending with userId: $e');
      return [];
    }
  }
  
  void _updateNotificationSettings(bool enabled) async {
    try {
      // In a production app, this would call a service to update notification settings
      // Since we don't have a userService provider, we'll just update the state
      AppLogger.d("Notification settings updated: $enabled");
      // State is already updated in the onChanged callback
    } catch (e) {
      AppLogger.e("Error updating notification settings: $e");
      // Revert switch if update fails
      setState(() {
        _notificationsEnabled = !enabled;
      });
      
      if (mounted) {
        DialogUtils.showMessageDialog(
          context: context,
          title: 'settings.notification_update_error_title'.tr(),
          message: 'settings.notification_update_error_message'.tr(),
          buttonText: 'common.ok'.tr(),
        );
      }
    }
  }
  
  void _showChangePasswordDialog() {
    // Since there's no dedicated change password screen, we'll show a dialog
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings.change_password'.tr()),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'auth.current_password'.tr(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.password_required'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'auth.new_password'.tr(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.password_required'.tr();
                    }
                    if (value.length < 6) {
                      return 'auth.password_too_short'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'auth.confirm_password'.tr(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != newPasswordController.text) {
                      return 'auth.passwords_dont_match'.tr();
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop();
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                try {
                  // Get the current user
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && user.email != null) {
                    // Create credentials
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    
                    // Reauthenticate
                    await user.reauthenticateWithCredential(credential);
                    
                    // Change password
                    await user.updatePassword(newPasswordController.text);
                    
                    // Dismiss loading dialog
                    if (mounted) Navigator.of(context).pop();
                    
                    // Show success message
                    if (mounted) {
                      DialogUtils.showMessageDialog(
                        context: context,
                        title: 'auth.password_updated'.tr(),
                        message: 'auth.password_updated_message'.tr(),
                        buttonText: 'common.ok'.tr(),
                      );
                    }
                  }
                } catch (e) {
                  // Dismiss loading dialog
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // Show error message
                  if (mounted) {
                    DialogUtils.showMessageDialog(
                      context: context,
                      title: 'auth.password_update_failed'.tr(),
                      message: 'auth.incorrect_password'.tr(),
                      buttonText: 'common.ok'.tr(),
                    );
                  }
                }
              }
            },
            child: Text(
              'common.save'.tr(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 

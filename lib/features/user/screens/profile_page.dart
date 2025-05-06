import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // <<< ADD animations import
import 'package:easy_localization/easy_localization.dart'; // Add import for translations
import 'package:urocenter/core/utils/logger.dart';
// import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // REMOVE animations import
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../app/routes.dart';
import '../../../providers/service_providers.dart';
import '../../../features/user/services/user_profile_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/navigation_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/haptic_utils.dart';

/// User Profile Screen
class ProfilePage extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState(); // Changed createState
}

// Changed to ConsumerState
class _ProfilePageState extends ConsumerState<ProfilePage> { 
  
  // --- State Variables ---
  Map<String, dynamic>? _userData; // Firestore profile data
  User? _firebaseUser; // <<< ADDED Firebase User object >>>
  bool _isLoading = true; // Start in loading state
  String? _error;
  // --- End State Variables ---
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile(); // Load data on init
  }

  // --- Data Fetching Method ---
  Future<void> _loadUserProfile() async {
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _isLoading = true;
      _error = null; // Clear previous errors
    });

    try {
      // <<< Get Firebase User first >>>
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Handle case where user is somehow null despite being on profile page
        // This might happen in rare race conditions during sign out
        throw Exception("User is not signed in."); 
      }
      
      final userProfileService = ref.read(userProfileServiceProvider);
      final profileData = await userProfileService.getUserProfile(currentUser.uid); // Use uid from currentUser
      AppLogger.d("Profile Page - Fetched Profile: $profileData");

      if (mounted) {
        setState(() {
          _firebaseUser = currentUser; // <<< Store Firebase User >>>
          _userData = profileData; // Assign fetched map (can be null)
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.e("Error loading user profile: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Use ErrorHandler
          _error = "profile.load_error".tr(args: [ErrorHandler.handleError(e)]); 
        });
      }
    }
  }
  // --- End Data Fetching Method ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- Build logic using state ---
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }
    
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)));
    }

    if (_userData == null) {
      return Center(child: Text('profile.no_data'.tr(), style: theme.textTheme.bodyLarge)); 
    }
    
    // Data extraction from _userData...
    final String stateUserName = _userData!['fullName'] as String? ?? 'N/A';
    
    final bool isGoogleSignIn = _firebaseUser?.providerData.any((info) => info.providerId == 'google.com') ?? false;
    final String displayEmail = (isGoogleSignIn ? _firebaseUser?.email : _userData!['email'] as String?) ?? 'N/A';
    
    final String stateUserPhone = _userData!['phoneNumber'] as String? ?? 'N/A';
    
    final num? ageNum = _userData!['age'] as num?;
    final String displayAge = ageNum != null ? ageNum.toString() : 'N/A';

    final String stateUserGender = _userData!['gender'] as String? ?? 'N/A';
    
    final String? city = _userData!['city'] as String?;
    final String? country = _userData!['country'] as String?;
    String stateUserLocation = 'N/A';
    if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) {
      stateUserLocation = '$city, $country';
    } else if (city != null && city.isNotEmpty) {
      stateUserLocation = city;
    } else if (country != null && country.isNotEmpty) {
      stateUserLocation = country;
    }
        
    final Map<String, dynamic>? medicalHistory = _userData!['medicalHistory'] as Map<String, dynamic>?;
    final String medicalSummary = medicalHistory != null ? 'profile.view_details'.tr() : 'profile.not_provided'.tr(); 

    return ScrollableContent(
        padding: const EdgeInsets.only(top: 16.0, bottom: 0),
        bottomSpace: 16.0,
        child: AnimationLimiter(
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 30.0,
                child: FadeInAnimation(
                  curve: Curves.easeOutQuint,
                  duration: const Duration(milliseconds: 600),
                  child: widget,
                ),
              ),
              children: [
                _buildSectionCard(
                  context,
                  title: 'profile.personal_details'.tr(), 
                  icon: Icons.person_outline,
                  iconColor: theme.colorScheme.primary, 
                  children: [
                    _buildDetailRow(context, 'profile.name'.tr(), stateUserName), 
                    _buildDetailRow(context, 'profile.email'.tr(), displayEmail), 
                    _buildDetailRow(context, 'profile.phone'.tr(), stateUserPhone), 
                    _buildDetailRow(context, 'profile.age'.tr(), displayAge),
                    _buildDetailRow(context, 'profile.gender'.tr(), stateUserGender), 
                    _buildDetailRow(context, 'profile.location'.tr(), stateUserLocation, isLast: true),
                  ],
                  isLast: false,
                ),
                _buildSectionCard(
                  context,
                  title: 'profile.medical_summary'.tr(), 
                  icon: Icons.medical_information_outlined, 
                  iconColor: theme.colorScheme.error,
                  children: [
                    _buildSettingsTile(
                      context, 
                      medicalSummary, 
                      Icons.description_outlined,
                      isLast: true,
                      onTap: () => context.pushNamed(RouteNames.userMedicalHistory),
                    ),
                  ],
                  isLast: false,
                ),
                _buildSectionCard(
                  context,
                  title: 'profile.my_documents'.tr(),
                  icon: Icons.folder_copy_outlined,
                  iconColor: theme.colorScheme.secondary,
                  children: [
                    _buildSettingsTile(context, 'profile.view_uploaded_documents'.tr(), Icons.description_outlined, 
                      onTap: () => context.pushNamed(RouteNames.userDocuments),
                      isLast: true
                    ),
                  ],
                  isLast: false,
                ),
                _buildSectionCard(
                  context,
                  title: 'profile.account_settings'.tr(), 
                  icon: Icons.settings_outlined,
                  iconColor: theme.colorScheme.tertiary,
                  children: [
                    _buildSettingsTile(context, 'profile.notifications'.tr(), Icons.notifications_outlined), 
                    _buildSettingsTile(context, 'profile.security'.tr(), Icons.lock_outline), 
                    _buildSettingsTile(context, 'profile.sign_out'.tr(), Icons.logout, 
                      isLast: true,
                      onTap: () async { 
                        try {
                          await ref.read(authServiceProvider).signOut();
                          // GoRouter's refresh listener should handle redirecting to welcome/login
                          AppLogger.d("User signed out");
                        } catch (e) {
                          AppLogger.e("Error signing out: $e");
                          // if(mounted) NavigationUtils.showSnackBar(context, "profile.sign_out_error".tr(), isError: true); // Use isError flag
                          // Revert back to using backgroundColor with theme error color
                          if(mounted) NavigationUtils.showSnackBar(context, "profile.sign_out_error".tr(), backgroundColor: theme.colorScheme.error);
                        }
                      }
                    ),
                  ],
                  isLast: false,
                ),
                _buildSectionCard(
                  context,
                  title: 'profile.support'.tr(), 
                  icon: Icons.support_agent_outlined,
                  iconColor: theme.colorScheme.secondary,
                  children: [
                    _buildSettingsTile(context, 'profile.help_center'.tr(), Icons.help_outline),
                    _buildSettingsTile(context, 'profile.contact_support'.tr(), Icons.email_outlined, isLast: true),
                  ],
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
    );
  }

  // --- Helper Widgets ---

  // REMOVED _buildProfileHeader method
  
  Widget _buildSectionCard(BuildContext context, {
    required String title, 
    required IconData icon, 
    required Color iconColor, 
    required List<Widget> children,
    bool isLast = false,
  }) {
     final theme = Theme.of(context);

     // Implementation exactly like Settings screen's _buildSettingsCard
     return Container(
       margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(bottom: isLast ? 16.0 : 8.0),
       decoration: BoxDecoration(
         color: theme.colorScheme.surfaceContainerLow,
         borderRadius: BorderRadius.circular(16),
         boxShadow: [
           BoxShadow(
             color: theme.shadowColor.withAlpha(theme.brightness == Brightness.light ? 26 : 51),
             blurRadius: 8,
             spreadRadius: 0.5,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       clipBehavior: Clip.antiAlias,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Padding(
             padding: const EdgeInsets.all(16.0),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(
                     color: iconColor.withAlpha(26),
                     borderRadius: BorderRadius.circular(14),
                   ),
                   child: Icon(icon, color: iconColor, size: 24),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         title,
                         style: theme.textTheme.titleMedium?.copyWith(
                           fontWeight: FontWeight.w600,
                           letterSpacing: 0.2,
                         ),
                       ),
                       const SizedBox(height: 4),
                       Container(
                         height: 2.5,
                         width: 24,
                         decoration: BoxDecoration(
                           color: iconColor.withAlpha(153),
                           borderRadius: BorderRadius.circular(1.5),
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ),
           ),
           if (children.isNotEmpty) ...[
             Divider(height: 1, thickness: 1, color: theme.dividerColor), // Use theme-aware divider color
             ...children,
           ]
         ],
       ),
     );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool isLast = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                label, 
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value, 
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
             ]
          )
        ),
        if (!isLast) Divider(
          height: 1,
          thickness: 1,
          indent: 20,
          endIndent: 20,
          color: theme.dividerColor,
        ),
      ]
    );
  }
  
  Widget _buildSettingsTile(BuildContext context, String title, IconData leadingIcon, {bool isLast = false, VoidCallback? onTap}) {
     final theme = Theme.of(context);
     final isDark = theme.brightness == Brightness.dark;
     
     return Column(
       children: [
         InkWell(
           onTap: () {
             if (onTap != null) {
               HapticUtils.lightTap();
               onTap();
             } else {
               HapticUtils.lightTap();
               NavigationUtils.showSnackBar(context, 'profile.feature_coming_soon'.tr());
             }
           },
           borderRadius: BorderRadius.circular(8),
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     color: theme.colorScheme.onSurfaceVariant.withAlpha(20),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Icon(
                     leadingIcon,
                     color: theme.colorScheme.onSurfaceVariant,
                     size: 20,
                   ),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Text(
                     title,
                     style: theme.textTheme.bodyLarge?.copyWith(
                       fontWeight: FontWeight.w500,
                       color: theme.colorScheme.onSurface,
                     ),
                   ),
                 ),
                 if (onTap != null) Icon(
                   Icons.arrow_forward_ios,
                   size: 14,
                   color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                 ),
               ],
             ),
           ),
         ),
         if (!isLast) Divider(
           height: 1,
           thickness: 1, 
           indent: 64,
           endIndent: 20,
           color: theme.dividerColor,
         ),
       ], 
     );
  }
} 

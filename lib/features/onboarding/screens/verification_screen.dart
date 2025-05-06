import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:easy_localization/easy_localization.dart'; // Import for translations
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../../../core/verification/verification.dart';
import '../widgets/onboarding_progress.dart';
import '../providers/onboarding_providers.dart';
import '../../../core/animations/animations.dart';
import '../../../providers/service_providers.dart'; // Import service providers
import '../../../core/constants/app_constants.dart'; // Import constants
import '../../../core/widgets/circular_loading_indicator.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Completion verification screen for onboarding
class OnboardingCompletionScreen extends ConsumerStatefulWidget {
  const OnboardingCompletionScreen({super.key});

  @override
  ConsumerState<OnboardingCompletionScreen> createState() => _OnboardingCompletionScreenState();
}

class _OnboardingCompletionScreenState extends ConsumerState<OnboardingCompletionScreen> 
    with SingleTickerProviderStateMixin implements VerificationAware {
  late AnimationController _animationController;
  final _verificationService = VerificationService();
  bool _isLoading = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Check verification status
    _checkVerificationStatus();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Update the button state in didChangeDependencies which is safe
    _updateButtonState();
  }
  
  // Separate method to update button state
  void _updateButtonState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(onboardingButtonProvider.notifier).state = OnboardingButtonState(
          text: 'onboarding.continue_to_dashboard'.tr(),
          onPressed: _isVerified ? _completeOnboarding : null,
          isLoading: _isLoading && !_isVerified,
        );
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkVerificationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      // Simulate a delay for animation purposes
      await Future.delayed(const Duration(milliseconds: 500));
      
      final isVerified = await _verificationService.checkOnboardingVerification();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVerified = isVerified;
        });
        
        // Update button state after state changes
        _updateButtonState();
        
        if (isVerified) {
          // Play the animation forward and hold the last frame
          _animationController.forward(from: 0.0).whenComplete(() {
            if (mounted) {
              // Ensure the controller value stays at the end (1.0)
              _animationController.value = 1.0;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        showError(ErrorHandler.handleError(e));
        setState(() => _isLoading = false);
        
        // Update button state after state changes
        _updateButtonState();
      }
    }
  }
  
  Future<void> _completeOnboarding() async {
    // Already verified, just setting loading for the final save/nav
    setState(() => _isLoading = true);
    // Also update the button provider to show loading immediately
    ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: true));

    try {
      // 1. Call existing verification service completion (if it does anything)
      await _verificationService.completeOnboarding();

      // 2. Update Firestore profile to mark onboarding as fully complete
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("errors.user_not_logged_in".tr());
      }
      final userId = user.uid;

      final Map<String, dynamic> finalData = {
        'onboardingCompleted': true,
        'onboardingStep': 'completed', // Mark step explicitly as completed
        'profileLastUpdatedAt': FieldValue.serverTimestamp(),
      };

      final userProfileService = ref.read(userProfileServiceProvider);
      await userProfileService.saveUserProfile(userId: userId, data: finalData);
      AppLogger.d("Onboarding marked as complete in Firestore.");

      // 3. Navigate to dashboard on success
      if (mounted) {
        navigateAfterVerification(RouteNames.userDashboard);
      }
    } catch (e) {
      if (mounted) {
        showError(ErrorHandler.handleError(e));
        // Reset loading state on error
        setState(() => _isLoading = false);
        ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: false));
      }
    }
  }

  @override
  void navigateAfterVerification(String routeName, {Object? extra}) {
    context.goNamed(routeName, extra: extra);
  }

  void showError(String message) {
    NavigationUtils.showSnackBar(
      context,
      message,
      backgroundColor: AppColors.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    // Don't update providers in build
    return AppScaffold(
      // Use theme surface color
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // We don't need to add OnboardingProgress here since it's now in the shell
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: _isLoading && !_isVerified
                      ? _buildLoadingState()
                      : _buildSuccessState(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return StaggeredAnimatedList(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      entryType: AnimationEntryType.fadeSlideUp,
      staggerDelay: const Duration(milliseconds: 200),
      children: [
        Container(
          width: 160,
          height: 160,
          margin: const EdgeInsets.only(bottom: 32),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              // Replace with our standardized loading indicator
              CircularLoadingIndicator(
                size: 60,
                strokeWidth: 6,
              ),
            ],
          ),
        ),
        Text(
          'onboarding.verifying_information'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'onboarding.verification_details'.tr(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            // Use theme secondary text color
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildSuccessState() {
    final theme = Theme.of(context); // Get theme
    // Define the scale animation based on the existing controller
    final scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut) // Bouncy effect
    );
    // Define fade animation
     final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)) // Fade in during the first 60% of the animation
    );

    return StaggeredAnimatedList(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      entryType: AnimationEntryType.fadeSlideUp,
      staggerDelay: const Duration(milliseconds: 200),
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // --- Replace Lottie with Animated Icon --- 
              ScaleTransition(
                scale: scaleAnimation,
                child: FadeTransition(
                  opacity: fadeAnimation, 
                  child: Icon(
                    Icons.check_circle_rounded,
                    // Use theme secondary color
                    color: theme.colorScheme.secondary, // Use a success color
                    size: 150, // Adjust size as needed
                    shadows: [
                      BoxShadow(
                        // Use theme secondary with alpha
                        color: theme.colorScheme.secondary.withAlpha(77),
                        blurRadius: 15,
                        spreadRadius: 5,
                      )
                    ]
                  ),
                ),
              )
              // Lottie.asset(
              //   'assets/animations/success.json',
              //   width: 200,
              //   height: 200,
              //   repeat: false,
              //   controller: _animationController,
              // ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'onboarding.verification_complete'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            // Use theme primary color
            color: theme.colorScheme.primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'onboarding.account_ready'.tr(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            // Use theme secondary text color
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildExpectationItem({
    required IconData icon,
    required String title,
    required String description,
    required int delay,
  }) {
    final theme = Theme.of(context); // Get theme
    return AnimatedContent(
      entryType: AnimationEntryType.fadeSlideLeft,
      delay: Duration(milliseconds: 900 + (delay * 200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // Use theme primary container with alpha
              color: theme.colorScheme.primaryContainer.withAlpha(77),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // Use theme primary shadow with alpha
                  color: theme.colorScheme.primary.withAlpha(51),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              // Use theme primary color
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    // Use theme secondary text color
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 

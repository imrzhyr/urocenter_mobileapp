import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:easy_localization/easy_localization.dart'; // Import for translations
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../widgets/onboarding_progress.dart';
import '../providers/onboarding_providers.dart'; // Import provider
import '../../../providers/service_providers.dart'; // Import service providers
import '../../../core/constants/app_constants.dart'; // Import for onboarding steps
import 'package:urocenter/core/utils/logger.dart';

// Define a simple class for payment methods
class PaymentMethod {
  final String id;
  final String name;
  final String iconAssetPath; // Path to the icon asset
  final Color unselectedColor; // Add color for unselected state

  PaymentMethod({
    required this.id,
    required this.name,
    required this.iconAssetPath,
    required this.unselectedColor,
  });
}

/// Payment screen for onboarding
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> with TickerProviderStateMixin {
  String _selectedPaymentMethod = '';
  bool _isLoading = false;
  bool _isExiting = false; // Add state variable
  final String _paymentAmount = "20,000 IQD"; // Define payment amount
  
  // Updated payment methods with colors
  final List<PaymentMethod> _paymentMethods = [
    PaymentMethod(
      id: 'fib',
      name: 'FIB (First Iraqi Bank)',
      iconAssetPath: 'assets/images/payments/fib.png', 
      unselectedColor: const Color(0xFFE0F2F7), // Light Teal
    ),
    PaymentMethod(
      id: 'qi_card',
      name: 'Qi Card',
      iconAssetPath: 'assets/images/payments/qi_card.png', 
      unselectedColor: const Color(0xFFFFF9E0), // Light Yellow
    ),
    PaymentMethod(
      id: 'zaincash',
      name: 'ZainCash',
      iconAssetPath: 'assets/images/payments/zaincash.png',
      unselectedColor: const Color(0xFFF3E5F5), // Light Purple
    ),
  ];
  
  // Animation Controllers and Animations
  late final List<AnimationController> _animControllers = [];
  late final List<Animation<Offset>> _slideAnimations = [];
  late final List<Animation<double>> _fadeAnimations = [];
  final int _numAnimatedSections = 4; // Value Prop, Summary, Methods, Terms
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // Set initial button state (disabled)
      _updateButtonState();
       // Start staggered animations
      _startAnimations();
    });
  }

  void _setupAnimations() {
    for (int i = 0; i < _numAnimatedSections; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400), // Animation duration
      );
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.2), // Start slightly below
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutQuad));
      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));
      
      _animControllers.add(controller);
      _slideAnimations.add(slideAnimation);
      _fadeAnimations.add(fadeAnimation);
    }
  }

  void _startAnimations() async {
     for (int i = 0; i < _numAnimatedSections; i++) {
      // Add delay between sections starting
      await Future.delayed(const Duration(milliseconds: 150)); 
      if (mounted) {
        _animControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    // Dispose animation controllers
    for (var controller in _animControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Update button state based on selection
  void _updateButtonState() {
    final bool isMethodSelected = _selectedPaymentMethod.isNotEmpty;
    final buttonText = 'onboarding.pay_amount'.tr(args: [_paymentAmount]);
    ref.read(onboardingButtonProvider.notifier).state = OnboardingButtonState(
      text: buttonText,
      // Enable button only if a method is selected
      onPressed: isMethodSelected ? _processPayment : null, 
      isLoading: _isLoading, 
    );
  }

  void _selectPaymentMethod(String id) {
     FocusScope.of(context).unfocus(); // Dismiss keyboard if method selection somehow opened it
    setState(() {
      _selectedPaymentMethod = id;
    });
    _updateButtonState(); // Update button state after selection
  }
  
  Future<void> _processPayment() async {
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    if (_selectedPaymentMethod.isEmpty) {
      NavigationUtils.showSnackBar(
        context,
        'onboarding.select_payment_method_error'.tr(),
        backgroundColor: AppColors.warning,
      );
      return;
    }
    
    setState(() => _isExiting = true);
    // Update provider state for loading indicator
    ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: true));
    
    await Future.delayed(const Duration(milliseconds: 300)); 

    if (!mounted) return;

    try {
      AppLogger.d('Processing payment for $_paymentAmount using $_selectedPaymentMethod');
      // TODO: Implement actual payment gateway integration
      // Simulate network request for payment verification
      // await Future.delayed(const Duration(seconds: 2));

      // Get user ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("errors.user_not_logged_in".tr());
      }
      final userId = user.uid;

      // Determine the final onboarding step
      // Assuming AppConstants.onboardingSteps = [..., 'payment', 'verification']
      final String finalOnboardingStep = AppConstants.onboardingSteps[4]; // 'verification'

      // Prepare the data map to save
      final Map<String, dynamic> dataToSave = {
        'paymentCompleted': true,
        'paymentMethodSelected': _selectedPaymentMethod,
        'onboardingStep': finalOnboardingStep,
        'profileLastUpdatedAt': FieldValue.serverTimestamp(),
        // Note: onboardingCompleted remains false until the final step confirms everything
      };

      // Get the service and save data
      final userProfileService = ref.read(userProfileServiceProvider);
      await userProfileService.saveUserProfile(userId: userId, data: dataToSave);
      AppLogger.d("Payment Step Data Saved: $dataToSave");

      // Navigate on success (AFTER saving data)
      NavigationUtils.showSnackBar(
        context,
        'onboarding.payment_successful'.tr(),
        backgroundColor: AppColors.success,
      );
      context.goNamed(RouteNames.onboardingVerification); 

    } catch (e) {
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          ErrorHandler.handleError(e),
          backgroundColor: AppColors.error,
        );
         // Reset state on error
        setState(() => _isExiting = false);
        ref.read(onboardingButtonProvider.notifier).update((state) => state.copyWith(isLoading: false));
      }
    } 
    // No finally block for state reset here
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          Expanded(
            child: ScrollableContent( 
              padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
               // Wrap the main content Column with AnimatedSwitcher
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.0, 0.3),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slideAnimation, child: child),
                    );
                  },
                  child: _isExiting
                    ? const SizedBox.shrink()
                    : Column(
                       key: const ValueKey('payment_content'), // Add key
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          // Header
                          Text(
                             'onboarding.confirm_consultation'.tr(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'onboarding.consultation_description'.tr(),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // --- Insert Value Proposition Section ---
                          _buildAnimatedSection(index: 0, child: _buildValuePropositionSection(context)),
                          const SizedBox(height: 24), // Spacing after value prop
                          
                          // Payment summary
                          _buildAnimatedSection(index: 1, child: _buildPaymentSummary()),
                          const SizedBox(height: 32),
                          
                          // Payment methods section header
                          Text(
                             'onboarding.select_payment_method'.tr(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Payment method list
                          _buildAnimatedSection(
                            index: 2,
                            child: ListView.separated(
                               shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _paymentMethods.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final method = _paymentMethods[index];
                                return PaymentMethodTile(
                                  method: method,
                                  isSelected: _selectedPaymentMethod == method.id,
                                  onSelect: () => _selectPaymentMethod(method.id),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Terms text
                          _buildAnimatedSection(
                            index: 3,
                            child: RichText(
                               textAlign: TextAlign.center,
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                children: [
                                  TextSpan(text: 'onboarding.terms_agreement_prefix'.tr()),
                                  WidgetSpan(child: _buildTextLink('onboarding.terms_conditions'.tr())),
                                  TextSpan(text: ' ${tr('common.and')} '),
                                  WidgetSpan(child: _buildTextLink('onboarding.privacy_policy'.tr())),
                                ],
                              ),
                            )
                          ),
                          
                         // REMOVE padding at the bottom causing scroll
                         // const SizedBox(height: 80), 
                       ],
                    ),
              ),
            ),
          ),
        ],
      );
  }
  
  // Helper for clickable text links
  Widget _buildTextLink(String text) {
    final theme = Theme.of(context); // Get theme
    return InkWell(
      onTap: () {
        // TODO: Navigate to Terms/Privacy screen or show a dialog
        AppLogger.d('Tapped on $text link');
      },
      child: Text(
        text,
        style: TextStyle(
          // Use theme primary
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          // Use theme primary
          decorationColor: theme.colorScheme.primary,
        ),
      ),
    );
  }
  
  Widget _buildPaymentSummary() {
    final theme = Theme.of(context); // Get theme
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        // Use theme primaryContainer with alpha
        color: theme.colorScheme.primaryContainer.withAlpha(51), // ~20% alpha
        borderRadius: BorderRadius.circular(12),
        // Use theme primary with alpha for border
        border: Border.all(color: theme.colorScheme.primary.withAlpha(77)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'onboarding.amount_due'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              // Use theme onSurface
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            _paymentAmount, // Use the defined amount
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              // Use theme primary
              color: theme.colorScheme.primary, // Highlight the price
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper for Value Proposition Section ---
  Widget _buildValuePropositionSection(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      decoration: BoxDecoration(
        // Use theme primaryContainer with alpha
        color: theme.colorScheme.primaryContainer.withAlpha(26), // ~10% alpha
        borderRadius: BorderRadius.circular(12),
        // Use theme primary with alpha for border
        border: Border.all(color: theme.colorScheme.primary.withAlpha(51), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'onboarding.what_you_receive'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              // Use theme primary
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          _buildBenefitRow(
            context,
            icon: Icons.verified_user_outlined, // Icon for expertise/trust
            title: 'onboarding.benefit_expertise_title'.tr(),
            subtitle: 'onboarding.benefit_expertise_subtitle'.tr(),
          ),
          _buildBenefitRow(
            context,
            icon: Icons.lock_outline_rounded, // Icon for privacy/security
            title: 'onboarding.benefit_privacy_title'.tr(),
            subtitle: 'onboarding.benefit_privacy_subtitle'.tr(),
          ),
          _buildBenefitRow(
            context,
            icon: Icons.duo_outlined, // Icon for video + chat
            title: 'onboarding.benefit_consultation_title'.tr(),
            subtitle: 'onboarding.benefit_consultation_subtitle'.tr(),
          ),
          _buildBenefitRow(
            context,
            icon: Icons.home_outlined, // Icon for convenience
            title: 'onboarding.benefit_care_title'.tr(),
            subtitle: 'onboarding.benefit_care_subtitle'.tr(),
            isLast: true, // No divider after last item
          ),
        ],
      ),
    );
  }

  // --- Helper for a single benefit row ---
  Widget _buildBenefitRow(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    final theme = Theme.of(context); // Get theme
     return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16.0), // Spacing between rows
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use theme primary for icon
          Icon(icon, color: theme.colorScheme.primary, size: 26), // Slightly larger icon
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    // Use theme onSurfaceVariant
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper to wrap sections with animation ---
  Widget _buildAnimatedSection({required int index, required Widget child}) {
    if (index < 0 || index >= _numAnimatedSections) return child; // Safety check

    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
  }
}

// --- Custom Payment Method Tile --- (Assuming you might need one)

class PaymentMethodTile extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onSelect;

  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          // Use theme container colors
          color: isSelected ? theme.colorScheme.primaryContainer.withAlpha(77) : theme.colorScheme.surfaceContainer, 
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            // Use theme primary and outline colors
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withAlpha(128), 
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Icon using Image.asset
            Image.asset(
              method.iconAssetPath,
              width: 36, 
              height: 36,
              errorBuilder: (context, error, stackTrace) {
                // Placeholder if image fails to load
                // Use theme onSurfaceVariant color
                return Icon(Icons.payment, size: 36, color: theme.colorScheme.onSurfaceVariant);
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                method.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  // Use theme primary and onSurface colors
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            ),
            // Selection indicator (e.g., Radio button style)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, 
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Use theme primary and onSurfaceVariant colors
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withAlpha(128),
                  width: 2,
                ),
                // Use theme primary or transparent
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              ),
              child: isSelected 
                  // Use theme onPrimary
                  ? Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
} 

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/utils/navigation_utils.dart';
import '../providers/onboarding_providers.dart';
import '../../../core/animations/animations.dart';
import '../widgets/onboarding_progress.dart';
import '../../../core/utils/haptic_utils.dart';

/// A shell widget for the onboarding flow that displays a persistent AppBar and progress bar.
class OnboardingShell extends ConsumerStatefulWidget {
  final Widget child;

  const OnboardingShell({super.key, required this.child});
  
  @override
  ConsumerState<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends ConsumerState<OnboardingShell> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  String _currentLocation = '';
  String _previousLocation = '';
  int _currentStep = 1;
  int _totalSteps = 5;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_isInitialized) {
      // Initialize tracking variables
      _currentLocation = GoRouterState.of(context).matchedLocation;
      _previousLocation = _currentLocation;
      _currentStep = _getCurrentStep(_currentLocation);
      
      // Set the initial progress bar value
      _animationController.value = _currentStep / _totalSteps;
      
      _isInitialized = true;
    }
  }
  
  @override
  void didUpdateWidget(OnboardingShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final newLocation = GoRouterState.of(context).matchedLocation;
    
    if (newLocation != _currentLocation) {
      // Store previous location and update current
      _previousLocation = _currentLocation;
      _currentLocation = newLocation;
      
      // Determine the new step
      final newStep = _getCurrentStep(newLocation);
      
      // Save current step
      _currentStep = newStep;
      
      // Animate the progress bar
      _animateProgressTo(_currentStep / _totalSteps);
    }
  }
  
  void _animateProgressTo(double targetValue) {
    _animationController.animateTo(
      targetValue,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
  
  // Helper function to determine the current step based on the route path
  int _getCurrentStep(String location) {
    final List<String> stepPaths = [
      '${RouteNames.onboardingBase}/profile-setup',
      '${RouteNames.onboardingBase}/medical-history',
      '${RouteNames.onboardingBase}/document-upload',
      '${RouteNames.onboardingBase}/payment',
      '${RouteNames.onboardingBase}/verification',
    ];
    int currentStep = stepPaths.indexOf(location);
    // Return 0-based index directly. Handle -1 if route not found (fallback to 0)
    return currentStep != -1 ? currentStep + 1 : 1; 
  }

  // Helper function to get the screen title based on the route path
  String _getScreenTitle(String location) {
    switch (location) {
      case '${RouteNames.onboardingBase}/profile-setup':
        return 'Profile Setup'; // TODO: Localize
      case '${RouteNames.onboardingBase}/medical-history':
        return 'Medical History'; // TODO: Localize
      case '${RouteNames.onboardingBase}/document-upload':
        return 'Document Upload'; // TODO: Localize
      case '${RouteNames.onboardingBase}/payment':
        return 'Payment Information'; // TODO: Localize
      case '${RouteNames.onboardingBase}/verification':
        return 'Verification'; // TODO: Localize
      default:
        return 'Onboarding'; // Fallback title
    }
  }

  // Helper function to handle back navigation within the shell
  void _handleShellBack() {
    HapticUtils.lightTap();
    final currentStep = _getCurrentStep(GoRouterState.of(context).uri.toString());
    // Log the back action
    print(
        'OnboardingShell Back Pressed: Current Step: $currentStep, Route: ${GoRouterState.of(context).uri}');

    // Determine the previous route based on the defined order
    final Map<String, String> routeNameToPath = {
      RouteNames.profileSetup: '${RouteNames.onboardingBase}/profile-setup',
      RouteNames.medicalHistory: '${RouteNames.onboardingBase}/medical-history',
      RouteNames.documentUpload: '${RouteNames.onboardingBase}/document-upload',
      RouteNames.payment: '${RouteNames.onboardingBase}/payment',
      RouteNames.onboardingVerification: '${RouteNames.onboardingBase}/verification',
    };

    final List<String> orderedRouteNames = [
      RouteNames.profileSetup,
      RouteNames.medicalHistory,
      RouteNames.documentUpload,
      RouteNames.payment,
      RouteNames.onboardingVerification,
    ];

    int currentIndex = routeNameToPath.values.toList().indexOf(_currentLocation);

    if (currentIndex > 0) {
      // Navigate to the previous step
      String previousRouteName = orderedRouteNames[currentIndex - 1];
      context.goNamed(previousRouteName); 
    } else {
      // If it's the first step, navigate back out of onboarding
      context.goNamed(RouteNames.welcome, extra: true); 
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String screenTitle = _getScreenTitle(_currentLocation);

    // Watch the button state provider
    final buttonState = ref.watch(onboardingButtonProvider);

    return AppScaffold(
      // backgroundColor: AppColors.surface, // Remove explicit background
      appBar: AppBar(
        // backgroundColor: AppColors.surface, // Remove explicit background for shell clarity
        // elevation: 0, // Removed, matches theme
        // iconTheme color matches theme
        title: AnimatedContent(
          entryType: AnimationEntryType.fadeSlideDown,
          duration: const Duration(milliseconds: 400),
          child: Text(
            screenTitle, 
            // style inherits color and weight from theme's titleTextStyle
            // style: const TextStyle(
            //   color: AppColors.textPrimary, 
            //   fontWeight: FontWeight.bold
            // ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios), // Color inherited
          onPressed: _handleShellBack,
        ),
      ),
      body: Column(
        children: [
          // Original progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: OnboardingProgress(
              currentStep: _currentStep - 1, // Convert to 0-indexed
              totalSteps: _totalSteps,
            ),
          ),
          
          // The actual content of the current onboarding screen - no transitions
          Expanded(
            child: KeyedSubtree(
              key: ValueKey<String>(_currentLocation),
              child: widget.child,
            ),
          ),
        ],
      ),
      persistentFooterButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: PulseButton(
          key: ValueKey<String>('${buttonState.text}-${buttonState.isLoading}'),
          text: buttonState.text,
          onPressed: buttonState.onPressed, 
          isLoading: buttonState.isLoading, 
          icon: Icons.arrow_forward,
        ),
      ),
    );
  }
}

/// Enum to track the page transition direction
enum PageTransitionStatus {
  forward,
  backward,
  none,
} 
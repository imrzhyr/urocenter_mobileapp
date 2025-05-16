import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart'; // Add import for translations
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../../../providers/service_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider; // Keep FirebaseAuthException
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';

// <<< Define Auth Steps >>>
enum _AuthStep {
  selectMethod,
  enterPhoneDetails,
  enterEmailPassword, // Added step
}

/// Sign up screen
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  // <<< Add Email/Password Controllers >>>
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _phoneCountryCode = '+964';
  bool _isLoading = false;
  bool _termsAccepted = false;
  String? _phoneError;
  String? _emailPasswordError; // Error message for email/pw form
  bool _obscurePassword = true; // <-- Add state for password
  bool _obscureConfirmPassword = true; // <-- Add state for confirm password
  
  // <<< Add Current Step State >>>
  _AuthStep _currentStep = _AuthStep.selectMethod;
  
  // Test credentials
  final String _testPhoneNumber = '+9647702428154';

  @override
  void dispose() {
    _phoneController.dispose();
    // <<< Dispose new controllers >>>
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onCountryCodeChanged(CountryCode code) {
    setState(() {
      _phoneCountryCode = code.dialCode ?? '+1';
    });
  }

  void _onTermsChanged(bool? value) {
    HapticUtils.lightTap(); // Add haptics to checkbox change
    setState(() {
      _termsAccepted = value ?? false;
    });
  }

  void _viewTerms() {
    HapticUtils.lightTap(); // Add haptics to view terms
    context.pushNamed(RouteNames.terms);
  }

  // <<< Add method to view Privacy Policy >>>
  void _viewPrivacyPolicy() {
    HapticUtils.lightTap();
    context.pushNamed(RouteNames.privacyPolicy);
  }

  // Renamed from _signUp to clarify it's the phone sign-up action
  Future<void> _startPhoneSignUpProcess() async { 
    HapticUtils.lightTap(); // Add haptics to sign up button
    if (!_formKey.currentState!.validate()) return;
    final theme = Theme.of(context); // Get theme
    if (!_termsAccepted) {
      NavigationUtils.showSnackBar(
        context,
        'auth.accept_terms_error'.tr(),
        backgroundColor: theme.colorScheme.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Normalize phone number
      String fullPhoneNumber = _phoneCountryCode + _phoneController.text.trim();
      // Normalize Iraqi phone numbers by removing leading zero if +964 is present
      if (_phoneCountryCode == '+964' && _phoneController.text.startsWith('0')) {
        // Remove the leading zero for Iraqi numbers
        final normalizedPhone = _phoneController.text.substring(1);
        fullPhoneNumber = _phoneCountryCode + normalizedPhone;
      }
      
      // Check if using test phone number
      bool isTestNumber = fullPhoneNumber == _testPhoneNumber;
      
      // Save the name to local storage or pass needed info?
      // For now, we just need the phone number for verification step.
      
      // Proceed to verification screen (will handle actual code sending there)
      AppLogger.d('Proceeding to verification for phone: $fullPhoneNumber');
      if (mounted) {
        // TODO: Pass necessary data (like maybe pre-filled name if collected elsewhere)
        context.goNamed(
          RouteNames.verification,
          extra: {'phoneNumber': fullPhoneNumber} // Pass phone number
        );
      }
      
    } catch (e) {
      if (mounted) {
        HapticUtils.heavyTap();
        NavigationUtils.showSnackBar(
          context,
          ErrorHandler.handleError(e),
          backgroundColor: theme.colorScheme.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Google Sign Up Handling ---
  void _handleGoogleSignUp() {
    // Use the GoogleSignInButton's built-in logic by triggering its onPressed
    // Need a GlobalKey for the GoogleSignInButton or simulate its behavior
    // For simplicity, let's reuse the logic pattern here for now
    HapticUtils.lightTap();
    setState(() => _isLoading = true);
    final theme = Theme.of(context); // Get theme
    
    // Access AuthService or trigger GoogleSignInButton logic
    final authService = ref.read(authServiceProvider);
    authService.signInWithGoogle().then((userCredential) {
       if (userCredential != null) {
         AppLogger.d('Google Sign-Up/In Success from _handleGoogleSignUp: ${userCredential.user?.uid}');
         // Navigation is handled by GoRouter redirect
       } else {
          AppLogger.e('Google Sign-Up/In cancelled or failed.');
       }
       if (mounted) setState(() => _isLoading = false);
     }).catchError((error) {
       AppLogger.e('Google Sign-Up/In Error from _handleGoogleSignUp: $error');
       if (mounted) {
         NavigationUtils.showSnackBar(
           context,
           ErrorHandler.handleError(error),
           backgroundColor: theme.colorScheme.error,
         );
         setState(() => _isLoading = false);
       }
     });
  }
  
  // <<< Add Email/Password Sign Up Logic >>>
  Future<void> _signUpWithEmailPassword() async {
    HapticUtils.lightTap();
    // Use the SAME form key if fields are within the same Form widget
    // If separate forms, use a specific key for email/password form
    if (!_formKey.currentState!.validate()) return;
    final theme = Theme.of(context); // Get theme
    
    // <<< Add Terms Acceptance Check >>>
    if (!_termsAccepted) {
      NavigationUtils.showSnackBar(
        context,
        'auth.accept_terms_error'.tr(),
        backgroundColor: theme.colorScheme.error,
      );
      return;
    }
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      setState(() => _emailPasswordError = 'errors.passwords_dont_match'.tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _emailPasswordError = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      UserCredential userCredential = await authService.createUserWithEmailAndPassword(email, password);
      AppLogger.d('Email/Password Sign-Up Success: ${userCredential.user?.uid}');

      // Decide next step: Maybe verify email (outside app) or go to onboarding
      if (mounted) {
         // Example: Directly go to profile setup after email sign up
         // Navigation might be handled by GoRouter redirect listening to auth state
         // Or explicitly navigate if needed after setting user data
         // context.goNamed(RouteNames.profileSetup);
         AppLogger.d("Email sign up successful, navigation likely handled by redirect.");
      } 

    } on FirebaseAuthException catch (e) {
      String errorMessage = '${'auth.sign_up_failed'.tr()} ';
      if (e.code == 'weak-password') {
        errorMessage += 'auth.weak_password'.tr();
      } else if (e.code == 'email-already-in-use') {
        errorMessage += 'auth.email_already_in_use'.tr();
      } else if (e.code == 'invalid-email') {
        errorMessage += 'errors.invalid_email'.tr();
      } else {
        errorMessage += ErrorHandler.handleError(e); // Use generic handler
      }
      AppLogger.e("Email Sign-Up Error Code: ${e.code}");
       if (mounted) {
         setState(() {
           _emailPasswordError = errorMessage;
         });
       }
    } catch (e) {
      AppLogger.e('Generic email sign-up error: $e');
      if (mounted) {
         setState(() {
           _emailPasswordError = 'errors.unexpected_error'.tr();
         });
       }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // --- Build Content Area Based on Current Step ---
  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0), 
          end: Offset.zero,            
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic, 
        ));

        // Fade transition removed
        // final fadeAnimation = Tween<double>(
        //   begin: 0.5, 
        //   end: 1.0,   
        // ).animate(CurvedAnimation(
        //   parent: animation,
        //   curve: Curves.easeInOutCubic,
        // ));
        
        // Only use SlideTransition
        return SlideTransition(
            position: slideAnimation,
            child: child, 
          );
      },
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topCenter, // Force top alignment
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null)
              currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey<_AuthStep>(_currentStep),
        child: _buildStepSpecificContent(),
      ),
    );
  }

  // --- Helper to get content for the current step ---
  Widget _buildStepSpecificContent() {
    switch (_currentStep) {
      case _AuthStep.selectMethod:
        return _buildMethodSelection();
      case _AuthStep.enterPhoneDetails:
        return _buildPhoneSignUpForm();
      // <<< Add case for Email/Password >>>
      case _AuthStep.enterEmailPassword:
        return _buildEmailPasswordSignUpForm(); 
    }
  }

  // --- Build Method Selection View ---
  Widget _buildMethodSelection() {
    final theme = Theme.of(context); // Get theme
    // <<< Wrap in SizedBox to provide height constraint for spaceBetween >>>
    // Subtract approximate AppBar height and padding
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Account for the main padding(24*2=48) and any extra space needed 
    final availableHeight = screenHeight - appBarHeight - topPadding - bottomPadding - 48; 
    
    // Ensure minimum height in case calculation is too small (e.g., landscape mode)
    final calculatedHeight = (availableHeight > 300) ? availableHeight : 300.0; 

    return SizedBox(
       height: calculatedHeight, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
         // <<< Use spaceBetween to push link to bottom >>>
         mainAxisAlignment: MainAxisAlignment.spaceBetween, 
         children: [
           // Group the top elements together 
           Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             mainAxisSize: MainAxisSize.min, // Prevent this inner column from expanding
                children: [
                  // Header
                  Text(
                    'auth.sign_up'.tr(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'auth.choose_sign_up_method'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
               // <<< Buttons Section >>>
               ElevatedButton.icon(
                 icon: const Icon(Icons.phone_outlined),
                 label: Text('auth.sign_up_with_phone'.tr()),
                 onPressed: _isLoading ? null : () {
                   HapticUtils.lightTap();
                   setState(() => _currentStep = _AuthStep.enterPhoneDetails);
                 },
                 style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
               ),
               const SizedBox(height: 16),
               ElevatedButton.icon(
                 icon: const Icon(Icons.email_outlined),
                 label: Text('auth.sign_up_with_email'.tr()),
                 onPressed: _isLoading ? null : () { 
                    HapticUtils.lightTap();
                    setState(() => _currentStep = _AuthStep.enterEmailPassword);
                 },
                 style: ElevatedButton.styleFrom(
                   minimumSize: const Size(double.infinity, 50),
                   backgroundColor: theme.colorScheme.secondary,
                   foregroundColor: theme.colorScheme.onSecondary,
                 ),
               ),
               const SizedBox(height: 16),
               GoogleSignInButton(
                 onSignInStarted: (loading) {
                   setState(() => _isLoading = loading);
                 },
                 onSignInSuccess: (credential) {
                   AppLogger.d('Google Sign-Up/In Success from Button: ${credential.user?.uid}');
                   if (mounted) setState(() => _isLoading = false);
                 },
                 onSignInError: (error) {
                   AppLogger.e('Google Sign-Up/In Error from Button: $error');
                   if (mounted) {
                     NavigationUtils.showSnackBar(
                       context,
                       ErrorHandler.handleError(error),
                       backgroundColor: theme.colorScheme.error,
                     );
                     setState(() => _isLoading = false);
                   }
                 },
               ),
               Padding(
                 padding: const EdgeInsets.only(top: 12.0, left: 8.0, right: 8.0),
                 child: RichText(
                   textAlign: TextAlign.center,
                   text: TextSpan(
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                     children: <TextSpan>[
                       TextSpan(text: '${'auth.google_signup_terms_intro'.tr()} '),
                       TextSpan(
                         text: 'auth.terms_and_conditions'.tr(),
                         style: TextStyle(
                             color: theme.colorScheme.primary,
                             decoration: TextDecoration.underline,
                             decorationColor: theme.colorScheme.primary,
                         ),
                         recognizer: TapGestureRecognizer()..onTap = _viewTerms,
                       ),
                       TextSpan(text: ' ${'common.and'.tr()} '),
                       TextSpan(
                         text: 'settings.privacy_policy'.tr(),
                         style: TextStyle(
                             color: theme.colorScheme.primary,
                             decoration: TextDecoration.underline,
                             decorationColor: theme.colorScheme.primary,
                         ),
                         recognizer: TapGestureRecognizer()..onTap = _viewPrivacyPolicy,
                       ),
                       const TextSpan(text: '.'),
                     ],
                   ),
                 ),
               ),
             ],
           ),
           
           // <<< Bottom Link Section >>>
           Column(
              mainAxisSize: MainAxisSize.min, // Prevent this inner column from expanding
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${'auth.already_have_account'.tr()} ',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticUtils.lightTap();
                        context.pushReplacementNamed(RouteNames.signIn); 
                      },
                      child: Text(
                        'auth.sign_in'.tr(),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                 const SizedBox(height: 0), // Reduced bottom padding slightly by removing SizedBox(24)
              ],
            ),
         ],
       ),
    );
  }
  
  // --- Build Phone Sign Up Form View ---
  Widget _buildPhoneSignUpForm() {
    final theme = Theme.of(context); // Get theme
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           // Header specific to this step
           Text(
            'auth.enter_phone_details'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'auth.phone_verification_explanation'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 40),
                  
          // Phone number field (copied from original build)
          Text(
            'auth.phone_number'.tr(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.inputDecorationTheme.enabledBorder?.borderSide.color ?? Colors.transparent),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 110, 
                  child: CountryCodePicker(
                    onChanged: _onCountryCodeChanged,
                    initialSelection: 'IQ',
                    favorite: const ['+964', 'IQ'],
                    countryList: const [
                      {'name': 'Iraq', 'code': 'IQ', 'dial_code': '+964'}, 
                      {'name': 'Egypt', 'code': 'EG', 'dial_code': '+20'}, 
                      {'name': 'Saudi Arabia', 'code': 'SA', 'dial_code': '+966'}, 
                      {'name': 'Jordan', 'code': 'JO', 'dial_code': '+962'}, 
                      {'name': 'United Arab Emirates', 'code': 'AE', 'dial_code': '+971'}, 
                    ],
                    flagWidth: 25,
                    dialogBackgroundColor: theme.dialogTheme.backgroundColor ?? theme.cardColor,
                    textStyle: TextStyle(color: theme.colorScheme.onSurface),
                    dialogTextStyle: TextStyle(color: theme.colorScheme.onSurface),
                    searchDecoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                      hintText: 'common.search_country'.tr(),
                      hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      border: theme.inputDecorationTheme.border,
                    ),
                    boxDecoration: null,
                    padding: EdgeInsets.zero,
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textAlign: TextAlign.left,
                    decoration: InputDecoration(
                      hintText: 'auth.enter_phone_number_hint'.tr(),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
                    ),
                    validator: Validators.validatePhone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _startPhoneSignUpProcess(),
                  ),
                ),
              ],
            ),
          ),
          if (_phoneError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                _phoneError!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 24),
          
          // Terms and Conditions Checkbox
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _termsAccepted,
                  onChanged: _onTermsChanged,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _onTermsChanged(!_termsAccepted),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: <TextSpan>[
                        TextSpan(text: '${'auth.agree_terms'.tr()} '),
                        TextSpan(
                          text: 'auth.terms_and_conditions'.tr(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = _viewTerms,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          AnimatedButton(
            text: 'common.continue'.tr(),
            onPressed: _startPhoneSignUpProcess,
            isLoading: _isLoading,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  // --- Build Email/Password Sign Up Form ---
  Widget _buildEmailPasswordSignUpForm() {
    final theme = Theme.of(context); // Get theme
    return Form(
      key: _formKey,
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
            // Header specific to this step
            Text(
             'auth.email_sign_up'.tr(),
             style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                   color: theme.colorScheme.onSurface,
                   fontWeight: FontWeight.bold,
                 ),
           ),
           const SizedBox(height: 12),
           Text(
             'auth.create_account_subtitle'.tr(),
             style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                   color: theme.colorScheme.onSurfaceVariant,
                 ),
           ),
           const SizedBox(height: 40),
             
           TextFormField(
             controller: _emailController,
             decoration: InputDecoration(
               labelText: 'auth.email'.tr(), 
               prefixIcon: Icon(Icons.email_outlined, color: theme.inputDecorationTheme.prefixIconColor)
             ),
             keyboardType: TextInputType.emailAddress,
             validator: (value) => value == null || value.isEmpty || !value.contains('@') 
                                  ? 'errors.invalid_email'.tr() 
                                  : null,
             textInputAction: TextInputAction.next,
           ),
           const SizedBox(height: 16),
           
           TextFormField(
             controller: _passwordController,
             obscureText: _obscurePassword, // <-- Use state variable
             decoration: InputDecoration(
               labelText: 'auth.password'.tr(), 
               prefixIcon: Icon(Icons.lock_outline, color: theme.inputDecorationTheme.prefixIconColor),
               suffixIcon: IconButton( // <-- Add suffix icon
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: theme.iconTheme.color?.withOpacity(0.6),
                  ),
                  onPressed: () {
                    HapticUtils.lightTap();
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
             ),
             validator: (value) => value == null || value.isEmpty || value.length < 6 
                                  ? 'errors.invalid_password'.tr(namedArgs: {'length': '6'}) 
                                  : null,
             textInputAction: TextInputAction.next,
           ),
           const SizedBox(height: 16),
           
           TextFormField(
             controller: _confirmPasswordController,
             obscureText: _obscureConfirmPassword, // <-- Use state variable
             decoration: InputDecoration(
               labelText: 'auth.confirm_password'.tr(), 
               prefixIcon: Icon(Icons.lock_outline, color: theme.inputDecorationTheme.prefixIconColor),
               suffixIcon: IconButton( // <-- Add suffix icon
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: theme.iconTheme.color?.withOpacity(0.6),
                  ),
                  onPressed: () {
                    HapticUtils.lightTap();
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
             ),
             validator: (value) => value == null || value.isEmpty || value != _passwordController.text 
                                  ? 'errors.passwords_dont_match'.tr() 
                                  : null,
             textInputAction: TextInputAction.done,
             onFieldSubmitted: (_) => _signUpWithEmailPassword(),
           ),
           
           if (_emailPasswordError != null)
             Padding(
               padding: const EdgeInsets.only(top: 12, bottom: 8),
               child: Text(
                 _emailPasswordError!,
                 style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                 textAlign: TextAlign.center,
               ),
             ),
           
           const SizedBox(height: 24),
          
           // Terms and Conditions Checkbox
           Row(
             children: [
               SizedBox(
                 width: 24,
                 height: 24,
                 child: Checkbox(
                   value: _termsAccepted,
                   onChanged: _onTermsChanged,
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(4),
                   ),
                   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                 ),
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: GestureDetector(
                   onTap: () => _onTermsChanged(!_termsAccepted),
                   child: RichText(
                     text: TextSpan(
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         color: theme.colorScheme.onSurfaceVariant,
                       ),
                       children: <TextSpan>[
                         TextSpan(text: '${'auth.agree_terms'.tr()} '),
                         TextSpan(
                           text: 'auth.terms_and_conditions'.tr(),
                           style: TextStyle(
                             color: theme.colorScheme.primary,
                             fontWeight: FontWeight.bold,
                           ),
                           recognizer: TapGestureRecognizer()..onTap = _viewTerms,
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
             ],
           ),
           const SizedBox(height: 24),
          
           AnimatedButton(
             text: 'auth.sign_up'.tr(),
             onPressed: _signUpWithEmailPassword,
             isLoading: _isLoading,
             icon: const Icon(Icons.arrow_forward),
           ),
         ],
       ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Translate the app bar title based on current step
    String appBarTitle;
    switch (_currentStep) {
      case _AuthStep.enterPhoneDetails:
        appBarTitle = 'auth.enter_phone'.tr();
        break;
      case _AuthStep.enterEmailPassword:
        appBarTitle = 'auth.email_sign_up'.tr();
        break;
      case _AuthStep.selectMethod:
      default:
        appBarTitle = 'auth.sign_up'.tr();
        break;
    }
    
    final theme = Theme.of(context); // Get theme
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.appBarTheme.iconTheme?.color),
          onPressed: () {
            HapticUtils.lightTap();
            if (_currentStep != _AuthStep.selectMethod) {
              setState(() {
                _isLoading = false;
                _emailPasswordError = null;
                _phoneError = null;
                _currentStep = _AuthStep.selectMethod;
              });
            } else {
              context.goNamed(RouteNames.welcome); 
            }
          },
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.all(24.0), 
            child: _buildContent(),
          ),
        ),
      ),
    );
  }
} 

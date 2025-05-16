import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/utils.dart';
import '../../../app/routes.dart';
import '../../../providers/service_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' hide PhoneAuthProvider, EmailAuthProvider;
import '../../../core/utils/haptic_utils.dart';
import 'package:urocenter/core/utils/logger.dart';

// <<< Define Sign In Steps >>>
enum _SignInStep {
  selectMethod,
  enterPhone,
  enterEmailPassword,
}

/// Sign in screen
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _phoneCountryCode = '+964';
  bool _isLoading = false;
  String? _phoneError;
  String? _emailPasswordError;
  bool _obscurePassword = true;
  
  // <<< Current Sign In Step State >>>
  _SignInStep _currentStep = _SignInStep.selectMethod;
  
  // Test credentials
  final String _testPhoneNumber = '+9647702428154';
  final String _testSmsCode = '123455';

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onCountryCodeChanged(CountryCode code) {
    setState(() {
      _phoneCountryCode = code.dialCode ?? '+1';
    });
  }

  Future<void> _verifyPhone() async {
    HapticUtils.lightTap();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String fullPhoneNumber = _phoneCountryCode + _phoneController.text.trim();
      if (_phoneCountryCode == '+964' && _phoneController.text.startsWith('0')) {
        final normalizedPhone = _phoneController.text.substring(1);
        fullPhoneNumber = _phoneCountryCode + normalizedPhone;
      }
      
      bool isTestNumber = fullPhoneNumber == _testPhoneNumber;
      AppLogger.d('Verifying phone number: $fullPhoneNumber');
      
      if (fullPhoneNumber == '+964 7705449905' || 
          fullPhoneNumber == '+9647705449905' ||
          fullPhoneNumber == '+964 07705449905' ||
          fullPhoneNumber == '+96407705449905' ||
          _phoneController.text.trim() == '7705449905' ||
          _phoneController.text.trim() == '07705449905') {
        AppLogger.d('Admin phone detected, requesting verification code');
      } 
      
      if (isTestNumber) {
        AppLogger.d('Test phone number detected, simulating code sent');
        _onCodeSent('test-verification-id', null); 
        NavigationUtils.showSnackBar(context, 'auth.test_phone_detected'.tr(), backgroundColor: Theme.of(context).colorScheme.secondary);
        return;
      }
      
      final authService = ref.read(authServiceProvider);
      await authService.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onCodeAutoRetrievalTimeout,
      );
    } catch (e) {
      AppLogger.e('Phone verification error: $e');
      if (mounted) {
        NavigationUtils.showSnackBar(context, ErrorHandler.handleError(e), backgroundColor: Theme.of(context).colorScheme.error);
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _onVerificationCompleted(PhoneAuthCredential credential) async {
    AppLogger.d('Verification completed automatically');
    if (mounted) {
      setState(() => _isLoading = true);
      try {
        final authService = ref.read(authServiceProvider);
        final userCredential = await authService.signInWithPhoneCredential(credential);
        AppLogger.d('Auto-verification sign-in successful: ${userCredential.user?.uid}');
      } catch (e) {
        AppLogger.e('Auto-verification sign-in error: $e');
        if (mounted) {
          NavigationUtils.showSnackBar(context, 'auth.sign_in_failed'.tr(), backgroundColor: Theme.of(context).colorScheme.error);
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  void _onVerificationFailed(FirebaseAuthException e) {
    AppLogger.e('Verification failed: ${e.message}');
    if (mounted) {
      String errorMessage = '${'auth.phone_verification_failed'.tr()} ';
      if (e.code == 'invalid-phone-number') {
        errorMessage += 'auth.enter_valid_phone'.tr();
      } else {
        errorMessage += 'common.try_again'.tr();
      }
      NavigationUtils.showSnackBar(context, errorMessage, backgroundColor: Theme.of(context).colorScheme.error);
      setState(() => _isLoading = false);
    }
  }
  
  void _onCodeSent(String verificationId, int? resendToken) {
    if (!mounted) return;
    AppLogger.d('SMS code sent (from SignInScreen), verification ID: $verificationId');
    
    final String fullPhoneNumber = _phoneCountryCode + _phoneController.text.trim();
    
      setState(() {
        _isLoading = false;
      });
    
    context.goNamed(
      RouteNames.verification,
      extra: {
        'phoneNumber': fullPhoneNumber,
        'verificationId': verificationId,
        'resendToken': resendToken,
      },
    );
  }
  
  void _onCodeAutoRetrievalTimeout(String verificationId) {
    AppLogger.d('Code auto retrieval timeout, verification ID: $verificationId');
    if (mounted) {
      setState(() {
        // _verificationId = verificationId;
      });
    }
  }

  Future<void> _handleGoogleSignInAttempt() async {
    HapticUtils.lightTap();
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();

      if (userCredential != null) {
         AppLogger.d('Google Sign-In successful (handled by router): ${userCredential.user?.uid}');
      } else {
        AppLogger.e('Google Sign-In cancelled or failed.');
      }
       if (mounted) {
         setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.e('Google Sign-In error: $e');
      if (mounted) {
        NavigationUtils.showSnackBar(
          context,
          ErrorHandler.handleError(e),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
         setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithEmail() async {
    HapticUtils.lightTap();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _emailPasswordError = "auth.enter_email_and_password".tr();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailPasswordError = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmailAndPassword(email, password);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "${"auth.sign_in_failed".tr()} ";
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        errorMessage += "auth.no_user_for_email".tr();
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage += "auth.incorrect_credentials".tr();
      } else {
        errorMessage += "errors.unexpected_error".tr();
      }
      AppLogger.e("Email Sign-In Error Code: ${e.code}");
       if (mounted) {
         setState(() {
           _emailPasswordError = errorMessage;
           _isLoading = false;
         });
       }
    } catch (e) {
      AppLogger.e('Generic email sign-in error: $e');
      if (mounted) {
         setState(() {
           _emailPasswordError = "auth.unexpected_sign_in_error".tr();
           _isLoading = false;
         });
       }
    }
  }
  
  // <<< Build Content Area Based on Current Step >>>
  Widget _buildContent() {
    // <<< Wrap with AnimatedSwitcher and provide custom transition >>>
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
        
        // Only use SlideTransition
        return SlideTransition(
            position: slideAnimation,
            child: child, 
          );
      },
      child: KeyedSubtree(
        // <<< Use _currentStep as key to trigger animation >>>
        key: ValueKey< _SignInStep>(_currentStep),
        child: _buildStepSpecificContent(),
      ),
    );
  }
  
  // <<< Helper to get content for the current step >>>
  Widget _buildStepSpecificContent() {
    switch (_currentStep) {
      case _SignInStep.selectMethod:
        return _buildMethodSelection();
      case _SignInStep.enterPhone:
        return _buildPhoneInput();
      case _SignInStep.enterEmailPassword:
        return _buildEmailPasswordInput();
    }
  }

  // <<< Build Method Selection View >>>
  Widget _buildMethodSelection() {
    final theme = Theme.of(context);
    return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'auth.sign_in'.tr(), 
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'auth.choose_sign_in_method'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 40),
                  
        // Phone Sign In Button
        ElevatedButton.icon(
          icon: const Icon(Icons.phone_outlined),
          label: Text('auth.sign_in_with_phone'.tr()),
          onPressed: _isLoading ? null : () {
            HapticUtils.lightTap();
            setState(() => _currentStep = _SignInStep.enterPhone);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ),
        const SizedBox(height: 16),

        // Email/Password Sign In Button
        ElevatedButton.icon(
          icon: const Icon(Icons.email_outlined),
          label: Text('auth.sign_in_with_email'.tr()),
          onPressed: _isLoading ? null : () {
            HapticUtils.lightTap();
            setState(() => _currentStep = _SignInStep.enterEmailPassword);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: theme.colorScheme.onSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Google Sign In Button - Use the custom one
        GoogleSignInButton(
           onSignInStarted: (loading) {
              setState(() => _isLoading = loading);
              AppLogger.d("Google Sign in Started: $loading");
            },
            onSignInSuccess: (credential) {
              AppLogger.d("Google Sign in Success (callback): ${credential.user?.uid}");
              if (mounted) setState(() => _isLoading = false);
            },
            onSignInError: (error) {
              AppLogger.e("Google Sign in Error (callback): $error");
              if (mounted) {
                 setState(() => _isLoading = false);
                NavigationUtils.showSnackBar(
                  context,
                  ErrorHandler.handleError(error),
                  backgroundColor: Theme.of(context).colorScheme.error,
                );
              }
            },
        ),
        
        const Spacer(), // Pushes Sign Up link to bottom

        // Sign Up Link
        Center(
          child: GestureDetector(
            onTap: () {
              HapticUtils.lightTap();
              context.pushNamed(RouteNames.signUp);
            },
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: '${'auth.dont_have_account'.tr()} ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'auth.sign_up'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
                    ),
        const SizedBox(height: 24),
      ],
    );
  }
  
  // <<< Build Phone Input View >>>
  Widget _buildPhoneInput() {
    final theme = Theme.of(context);
    // <<< Define the Send Code Button >>>
    final sendCodeButton = AnimatedButton(
      text: 'auth.send_code'.tr(),
      onPressed: _verifyPhone,
      isLoading: _isLoading,
      icon: const Icon(Icons.send_rounded),
    );
    
    // <<< Wrap Column with Form widget >>>
    return Form( 
      key: _formKey, // Associate the key with this Form
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'auth.enter_phone_number'.tr(), 
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'auth.verification_code_explanation'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 40),
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
                                hintText: 'auth.phone_number'.tr(),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
                              ),
                              validator: Validators.validatePhone,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _verifyPhone(),
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
          
          // <<< Add the Send Code Button here >>>
          sendCodeButton,
          
          const SizedBox(height: 24), // Add some padding at the bottom
        ],
      ),
    );
  }
  
  // --- Build method for entering email/password ---
  Widget _buildEmailPasswordInput() {
    final theme = Theme.of(context);
    final emailSignInButton = AnimatedButton(
       text: 'auth.sign_in'.tr(),
       onPressed: _signInWithEmail,
       isLoading: _isLoading, 
       icon: const Icon(Icons.login),
     );
     
     return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Text(
            'auth.sign_in_with_email'.tr(), 
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                ),
          ),
           const SizedBox(height: 12),
           Text(
            'auth.enter_email_password'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24), // Add padding before fields
          
           TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'auth.email'.tr(), 
              prefixIcon: Icon(Icons.email_outlined, color: theme.inputDecorationTheme.prefixIconColor),
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
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'auth.password'.tr(), 
              prefixIcon: Icon(Icons.lock_outline, color: theme.inputDecorationTheme.prefixIconColor),
              suffixIcon: IconButton(
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
            validator: (value) => value == null || value.isEmpty 
                                ? 'errors.password_required'.tr()
                                : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signInWithEmail(),
          ),
          const SizedBox(height: 8),
          if (_emailPasswordError != null)
             Padding(
               padding: const EdgeInsets.only(top: 8, bottom: 8),
               child: Text(
                 _emailPasswordError!,
                 style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                 textAlign: TextAlign.center,
                      ),
                    ),
          const SizedBox(height: 24),
          emailSignInButton,
          const SizedBox(height: 24),
        ],
      );
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle;
    switch (_currentStep) {
      case _SignInStep.enterPhone:
        appBarTitle = 'auth.enter_phone'.tr();
        break;
      case _SignInStep.enterEmailPassword:
        appBarTitle = 'auth.email_sign_in'.tr();
        break;
      case _SignInStep.selectMethod:
      default:
        appBarTitle = 'auth.sign_in'.tr();
        break;
    }
    
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.appBarTheme.iconTheme?.color),
          onPressed: () {
            HapticUtils.lightTap();
            if (_currentStep != _SignInStep.selectMethod) {
              setState(() {
                _isLoading = false;
                _emailPasswordError = null;
                _phoneError = null;
                _currentStep = _SignInStep.selectMethod;
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

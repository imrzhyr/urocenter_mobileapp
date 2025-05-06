import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../app/routes.dart';
import '../../../core/utils/haptic_utils.dart';

/// Welcome screen of the app
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  // For slide animations
  late AnimationController _animController;
  late Animation<Offset> _logoSlideAnimation;
  
  bool _showCursor = true;
  
  // Typewriter effect variables
  late List<String> _phraseKeys; // Store keys instead of translated strings
  int _currentPhraseIndex = 0;
  String _currentText = '';
  bool _isTyping = true;
  Timer? _typewriterTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize phrase keys without translation
    _phraseKeys = [
      'welcome.typewriter.consultations',
      'welcome.typewriter.urologist',
      'welcome.typewriter.healthcare',
      'welcome.typewriter.secure',
      'welcome.typewriter.expert',
    ];
    
    // Single animation controller for sequenced animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // Logo slides in from top
    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    
    // Tagline slides in from left
    
    // Subtitle slides in from right
    
    // Buttons scale up

    _animController.forward();
    
    // Start cursor blinking
    _startCursorAnimation();
    
    // Start typewriter after animation starts
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _startTypewriterEffect();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Reset typewriter on language change
    _typewriterTimer?.cancel();
    setState(() {
      _currentPhraseIndex = 0;
      _currentText = '';
      _isTyping = true;
    });
    
    // Restart typewriter effect
    _startTypewriterEffect();
  }

  // Get current translated phrase
  String get _currentPhrase => _phraseKeys[_currentPhraseIndex].tr();

  void _startCursorAnimation() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
        _startCursorAnimation();
      }
    });
  }
  
  void _startTypewriterEffect() {
    // Typing speed
    const typingSpeed = 60; // milliseconds per character
    const deletionSpeed = 25; // milliseconds per character (faster deletion)
    const pauseDuration = 1500; // stay for 1.5 seconds
    
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: typingSpeed), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_isTyping) {
          // Type the current phrase
          if (_currentText.length < _currentPhrase.length) {
            _currentText = _currentPhrase.substring(0, _currentText.length + 1);
          } else {
            // Pause at the end of typing
            timer.cancel();
            // Stay for 1.5 seconds before deleting
            Future.delayed(const Duration(milliseconds: pauseDuration), () {
              if (mounted) {
                setState(() {
                  _isTyping = false;
                  // Start deletion with faster speed
                  _typewriterTimer = Timer.periodic(
                    const Duration(milliseconds: deletionSpeed), 
                    (timer) => _handleDeletion(timer)
                  );
                });
              }
            });
          }
        }
      });
    });
  }
  
  void _handleDeletion(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    
    setState(() {
      if (_currentText.isNotEmpty) {
        _currentText = _currentText.substring(0, _currentText.length - 1);
      } else {
        // Move to the next phrase
        _currentPhraseIndex = (_currentPhraseIndex + 1) % _phraseKeys.length;
        _isTyping = true;
        timer.cancel();
        
        // Start typing the next phrase
        _typewriterTimer = Timer.periodic(
          const Duration(milliseconds: 60), 
          (timer) => _handleTyping(timer)
        );
      }
    });
  }
  
  void _handleTyping(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    
    setState(() {
      if (_currentText.length < _currentPhrase.length) {
        _currentText = _currentPhrase.substring(0, _currentText.length + 1);
      } else {
        timer.cancel();
        // Stay for 1.5 seconds before deleting
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _isTyping = false;
              // Start deletion with faster speed
              _typewriterTimer = Timer.periodic(
                const Duration(milliseconds: 25), 
                (timer) => _handleDeletion(timer)
              );
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Language selector at top right
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        // Fix withValues
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const LanguageSelector(isMinimal: true),
                    ),
                  ),
                ),
                
                // Logo and content
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // UroCenter text logo with slide animation
                      SlideTransition(
                        position: _logoSlideAnimation,
                        child: RichText(
                          // Use theme colors for logo text
                          text: TextSpan(
                            // Default style from theme
                            style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold), 
                            children: [
                              TextSpan(
                                text: 'Uro',
                                // style: TextStyle(
                                //   fontSize: 48,
                                //   fontWeight: FontWeight.bold,
                                //   color: Colors.black, // Use theme onBackground
                                // ),
                                style: TextStyle(color: theme.colorScheme.onSurface)
                              ),
                              TextSpan(
                                text: 'Center',
                                // style: TextStyle(
                                //   fontSize: 48,
                                //   fontWeight: FontWeight.bold,
                                //   color: AppColors.primary, // Use theme primary
                                // ),
                                style: TextStyle(color: theme.colorScheme.primary)
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Typewriter effect with phrases
                      SizedBox(
                        height: 25,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentText,
                              style: TextStyle(
                                fontSize: 18,
                                // color: Colors.grey[600], // Use theme secondary/variant color
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_showCursor)
                              Text(
                                '|',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  // color: Colors.grey[600], // Use theme secondary/variant color
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Buttons with scale animation
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Create Account button (blue)
                    AnimatedButton(
                      text: 'auth.sign_up'.tr(),
                      onPressed: () {
                        HapticUtils.lightTap();
                        context.pushNamed(RouteNames.signUp);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Sign in button (outline)
                    AnimatedButton(
                      text: 'auth.sign_in'.tr(),
                      isOutlined: true,
                      onPressed: () {
                        HapticUtils.lightTap();
                        context.pushNamed(RouteNames.signIn);
                      },
                    ),
                    // Add padding at the bottom to ensure buttons aren't too close to the edge
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
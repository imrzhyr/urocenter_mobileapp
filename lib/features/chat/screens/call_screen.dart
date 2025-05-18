import 'dart:async';
import 'package:urocenter/core/utils/logger.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:urocenter/core/theme/app_colors.dart';
import 'package:urocenter/features/chat/providers/call_controller.dart';
import 'package:urocenter/features/chat/models/call_params.dart';
import 'package:urocenter/core/widgets/circular_icon_button.dart';
import 'package:urocenter/core/widgets/animated_loader.dart';
import 'package:urocenter/core/utils/haptic_utils.dart';
import 'package:urocenter/app/routes.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urocenter/providers/service_providers.dart';
import 'package:urocenter/core/services/sound_service.dart';

/// A unified screen for handling all call states: incoming, outgoing, and connected
class CallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData;

  const CallScreen({super.key, required this.extraData});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;
  String _partnerName = 'Contact';
  bool _hasSetupListeners = false;
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  Timer? _durationUpdateTimer;
  bool _soundsInitialized = false;
  SoundService? _soundService;
  
  @override
  void initState() {
    super.initState();
    AppLogger.d("CallScreen: initState called");

    // Setup animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Pulsing animation for avatar in ringing state
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05)
          .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_animController);
    
    // Start and repeat the animation
    _animController.forward();
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.repeat();
      }
    });
    
    // Check if we should end call immediately
    final shouldEndCall = widget.extraData?['endCallImmediately'] == true;
    if (shouldEndCall) {
      // If this flag is set, end the call immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final params = CallParams.fromMap(widget.extraData);
        if (params != null) {
          final callController = ref.read(callControllerProvider(params.toRecord()).notifier);
          callController.hangUp();
          // Go back
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      });
      return;
    }
    
    // Parse and validate parameters
    final params = CallParams.fromMap(widget.extraData);
    if (params == null) {
      AppLogger.d("CallScreen: Invalid parameters received");
      return;
    }

    // Check if we have saved call duration and restore it
    if (widget.extraData != null && 
        widget.extraData!.containsKey('currentDuration') && 
        widget.extraData!['currentDuration'] is int) {
      final savedDuration = widget.extraData!['currentDuration'] as int;
      if (savedDuration > 0) {
        setState(() {
          _callDuration = Duration(seconds: savedDuration);
          AppLogger.d("CallScreen: Restored call duration: ${_formatDuration(_callDuration)}");
        });
      }
    }

    // Get partner name from params
    if (params.partnerName.isNotEmpty) {
      _partnerName = params.partnerName;
      AppLogger.d("CallScreen: Using provided partner name: ${params.partnerName}");
    } else {
      _partnerName = 'Call Participant';
      AppLogger.w("CallScreen: Empty partner name received, using fallback name");
    }

    // Use post-frame callback to ensure UI is built before accessing provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _setupCallStateListeners(params);
      
      // Register this call with the active call provider when it starts
      _updateActiveCall(params);
      
      // Initialize sounds based on call state
      _initializeCallSounds(params);
      
      // Activate haptic feedback for incoming calls
      if (!params.isCaller) {
        HapticUtils.heavyTap();
        // Schedule periodic vibrations
        Timer.periodic(const Duration(seconds: 3), (timer) {
          if (!mounted || ref.read(callControllerProvider(params.toRecord())).connectionState != CallConnectionState.ringing) {
            timer.cancel();
            return;
          }
          HapticUtils.heavyTap();
        });
      }
    });
  }
  
  void _initializeCallSounds(CallParams params) {
    if (_soundsInitialized) return;
    _soundsInitialized = true;
    
    final soundService = ref.read(soundServiceProvider);
    // Store soundService reference for dispose
    _soundService = soundService;
    
    final callState = ref.read(callControllerProvider(params.toRecord()));
    
    // Start appropriate sound based on call state
    switch (callState.connectionState) {
      case CallConnectionState.ringing:
        if (params.isIncoming) {
          // Play incoming call ringtone
          soundService.playIncomingRingtone();
        } else {
          // Play outgoing dial tone
          soundService.playDialingSound();
        }
        break;
        
      case CallConnectionState.connecting:
        // Play outgoing dial tone
        if (params.isCaller) {
          soundService.playDialingSound();
        }
        break;
        
      default:
        // No sound for other states
        break;
    }
  }
  
  void _updateActiveCall(CallParams params) {
    // Create active call data
    final activeCallData = params.toMap();
    
    // Add current duration if available
    if (_callDuration.inSeconds > 0) {
      activeCallData['currentDuration'] = _callDuration.inSeconds;
    }
    
    // Get a reference to the provider before setting up the timer
    final activeCallProviderRef = ref.read(activeCallProvider.notifier);
    
    // Schedule a periodic update every 5 seconds
    _durationUpdateTimer?.cancel();
    _durationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // Update the duration in the active call provider - using stored reference
        final currentActiveCall = activeCallProviderRef.state;
        if (currentActiveCall != null && 
            currentActiveCall['callId'] == params.callId &&
            _callDuration.inSeconds > 0) {
          activeCallProviderRef.state = {
            ...currentActiveCall,
            'currentDuration': _callDuration.inSeconds,
          };
        }
      } catch (e) {
        // Ignore errors if widget was disposed
        timer.cancel();
      }
    });
    
    // Set active call in provider
    activeCallProviderRef.state = activeCallData;
  }

  void _setupCallStateListeners(CallParams params) {
    if (_hasSetupListeners) return;
    _hasSetupListeners = true;
    
    final callState = ref.read(callControllerProvider(params.toRecord()));
    final soundService = ref.read(soundServiceProvider);
    final activeCallProviderRef = ref.read(activeCallProvider.notifier);
    
    // Save navigator context for safe usage in callbacks
    final navigatorContext = context;
    final navigator = Navigator.of(navigatorContext);
    
    // If already connected, start timer
    if (callState.connectionState == CallConnectionState.connected) {
      _startTimer();
    }
    
    // Listen for state changes
    ref.listenManual(callControllerProvider(params.toRecord()), (previous, next) {
      if (!mounted) return;
      
      // Handle timer management based on state changes
      if (previous?.connectionState != CallConnectionState.connected && 
          next.connectionState == CallConnectionState.connected) {
        // Call just connected
        _startTimer();
        HapticUtils.mediumTap(); // Give feedback when call connects
        
        // Play connect sound
        soundService.playConnectSound();
      } else if (previous?.connectionState == CallConnectionState.connected &&
                next.connectionState != CallConnectionState.connected) {
        // Call just disconnected
        _stopTimer();
        
        // Play disconnect sound
        soundService.playDisconnectSound();
      } else if (previous?.connectionState == CallConnectionState.ringing &&
                 next.connectionState == CallConnectionState.connecting) {
        // Call transitioning from ringing to connecting
        // Stop ringtone as appropriate
        soundService.stopRingtone();
      } else if (next.connectionState == CallConnectionState.ended ||
                 next.connectionState == CallConnectionState.failed) {
        // Call ended or failed
        soundService.stopAllSounds();
      }
      
      // Log call completion
      if (previous?.connectionState == CallConnectionState.connected && 
          next.connectionState == CallConnectionState.ended) {
        AppLogger.d("CallScreen: Call ended with duration: ${_formatDuration(_callDuration)}");
        
        // Clear active call when ended - using stored reference
        activeCallProviderRef.state = null;
        
        // Store params locally to avoid capturing ref in the closure
        final paramsRecord = params.toRecord();
        
        // Auto-close screen after call ends with delay
        Future.delayed(const Duration(seconds: 2), () {
          // Only proceed if widget is still mounted
          if (!mounted) return;
          
          try {
            // Use stored navigator reference instead of context
            navigator.pop();
          } catch (e) {
            // Ignore errors if navigator context is invalid
            AppLogger.d("CallScreen: Error popping navigator: $e");
          }
        });
      }
    });
  }

  void _startTimer() {
    _callDurationTimer?.cancel();
    setState(() {
      _callDuration = Duration.zero;
    });
    
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _stopTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    // Cancel all timers first
    _stopTimer();
    _animController.dispose();
    _durationUpdateTimer?.cancel();
    
    // Save reference to sound service locally to avoid using ref after dispose
    final localSoundService = _soundService;
    
    // Call super.dispose() before trying to use ref to avoid errors
    super.dispose();
    
    // Stop sounds using the saved reference
    if (localSoundService != null) {
      localSoundService.stopAllSounds();
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = CallParams.fromMap(widget.extraData);
    
    if (params == null) {
      return _buildErrorScaffold('Invalid call parameters');
    }
    
    final callState = ref.watch(callControllerProvider(params.toRecord()));
    
    return WillPopScope(
      // Prevent back button from doing anything during a call
      onWillPop: () async {
        // Prevent any back navigation by returning false
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with minimal controls
              _buildTopBar(params.isCaller),
              
              // Main call UI (expands to fill available space)
              Expanded(child: _buildCallUI(params, callState)),
              
              // Bottom action buttons
              _buildCallControls(params, callState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isCaller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Empty container where minimize button used to be
          Container(),
          const Spacer(),
          // Could add additional controls here
        ],
      ),
    );
  }
  
  // Method to handle call minimization - kept but unused now
  void _minimizeCall() {
    final params = CallParams.fromMap(widget.extraData);
    if (params == null) {
      // Clear active call data when popping
      ref.read(activeCallProvider.notifier).state = null;
      Navigator.of(context).pop();
      return;
    }
    
    // Just pop the current screen and clear active call
    ref.read(activeCallProvider.notifier).state = null;
    Navigator.of(context).pop();
  }
  
  Widget _buildCallUI(CallParams params, CallControllerState callState) {
    // Use isIncoming directly from params instead of deriving it
    final isIncoming = params.isIncoming && callState.connectionState == CallConnectionState.ringing;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Caller avatar with animation for ringing state
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            // Pulse animation only for ringing state
            final shouldPulse = callState.connectionState == CallConnectionState.ringing;
            
            return Transform.scale(
              scale: shouldPulse ? _pulseAnimation.value : 1.0,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: shouldPulse ? 5 : 0,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 32),
        
        // Partner name
        Text(
          _partnerName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Call status with animation
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStatusText(callState.connectionState, isIncoming),
        ),
        
        // Call timer (visible only when connected)
        AnimatedOpacity(
          opacity: callState.connectionState == CallConnectionState.connected ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _formatDuration(_callDuration),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusText(CallConnectionState state, bool isIncoming) {
    String text;
    Color color;
    
    switch (state) {
      case CallConnectionState.connecting:
        text = 'Connecting...';
        color = Colors.white70;
        break;
      case CallConnectionState.ringing:
        text = isIncoming ? 'Incoming call' : 'Ringing...';
        color = isIncoming ? Colors.green.shade300 : Colors.white70;
        break;
      case CallConnectionState.connected:
        text = 'Connected';
        color = Colors.green;
        break;
      case CallConnectionState.ended:
        text = 'Call ended';
        color = Colors.red.shade300;
        break;
      case CallConnectionState.failed:
        text = 'Call failed';
        color = Colors.red;
        break;
      default:
        text = '';
        color = Colors.white70;
    }
    
    return Text(
      text,
      key: ValueKey(state), // For AnimatedSwitcher
      style: TextStyle(
        fontSize: 18,
        color: color,
      ),
    );
  }
  
  Widget _buildCallControls(CallParams params, CallControllerState callState) {
    // Use isIncoming directly from params
    final isIncoming = params.isIncoming && callState.connectionState == CallConnectionState.ringing;
    final callController = ref.read(callControllerProvider(params.toRecord()).notifier);
    
    // Bottom padding
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Container(
      padding: EdgeInsets.only(
        left: 24, 
        right: 24, 
        bottom: 24 + bottomPadding,
        top: 16,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCallButtonsForState(params, callState, isIncoming, callController),
      ),
    );
  }
  
  Widget _buildCallButtonsForState(
    CallParams params,
    CallControllerState callState,
    bool isIncoming,
    CallController callController
  ) {
    // For call ended state
    if (callState.connectionState == CallConnectionState.ended ||
        callState.connectionState == CallConnectionState.failed) {
      return Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            backgroundColor: Colors.white24,
          ),
          child: Text('Close', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    
    // For incoming call
    if (isIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject button
          CircularIconButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            onPressed: () {
              HapticUtils.mediumTap();
              callController.rejectCall();
              // Stop ringtone
              ref.read(soundServiceProvider).stopRingtone();
              // Clear active call when rejected
              ref.read(activeCallProvider.notifier).state = null;
              Navigator.of(context).pop();
            },
            size: 70,
          ),
          
          // Answer button
          CircularIconButton(
            icon: Icons.call,
            backgroundColor: Colors.green,
            onPressed: () {
              HapticUtils.mediumTap();
              // Stop ringtone
              ref.read(soundServiceProvider).stopRingtone();
              callController.answerCall();
            },
            size: 70,
          ),
        ],
      );
    }
    
    // For connected call
    if (callState.connectionState == CallConnectionState.connected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button - white background when active
          CircularIconButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            backgroundColor: _isMuted ? Colors.white : Colors.white12,
            iconColor: _isMuted ? AppColors.primary : Colors.white,
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
              });
              callController.toggleMute();
            },
            size: 60,
          ),
          
          // End call button
          CircularIconButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            onPressed: () {
              callController.hangUp();
              // Play disconnect sound
              ref.read(soundServiceProvider).playDisconnectSound();
              // Clear active call when ended
              ref.read(activeCallProvider.notifier).state = null;
              Navigator.of(context).pop();
            },
            size: 70,
          ),
          
          // Speaker button - white background when active
          CircularIconButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            backgroundColor: _isSpeakerOn ? Colors.white : Colors.white12,
            iconColor: _isSpeakerOn ? AppColors.primary : Colors.white,
            onPressed: () {
              setState(() {
                _isSpeakerOn = !_isSpeakerOn;
              });
              callController.toggleSpeaker();
            },
            size: 60,
          ),
        ],
      );
    }
    
    // For outgoing call (ringing or connecting)
    return Center(
      child: CircularIconButton(
        icon: Icons.call_end,
        backgroundColor: Colors.red,
        onPressed: () {
          callController.hangUp();
          // Stop dialing sound
          ref.read(soundServiceProvider).stopDialingSound();
          // Clear active call when ended
          ref.read(activeCallProvider.notifier).state = null;
          Navigator.of(context).pop();
        },
        size: 70,
      ),
    );
  }

  Widget _buildErrorScaffold(String errorMessage) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: Text('Error'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

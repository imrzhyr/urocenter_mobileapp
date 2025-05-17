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

/// Screen for handling audio calls with Agora - Simplified for audio only
class CallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData;

  const CallScreen({super.key, required this.extraData});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;
  String _partnerName = 'Contact';
  bool _hasSetupListeners = false; // Track if listeners are set up

  @override
  void initState() {
    super.initState();
    AppLogger.d("CallScreen: initState called");

    // Parse and validate parameters
    final params = CallParams.fromMap(widget.extraData);
    if (params == null) {
      AppLogger.d("CallScreen: Invalid parameters received");
      return;
    }

    // Get partner name from params if available
    if (params.partnerName.isNotEmpty) {
      _partnerName = params.partnerName;
      AppLogger.d("CallScreen: Using provided partner name: ${params.partnerName}");
    } else {
      // Use a fallback if partner name is empty
      _partnerName = 'Call Participant';
      AppLogger.w("CallScreen: Empty partner name received, using fallback name");
    }

    AppLogger.d("CallScreen: Valid parameters received for call ID: ${params.callId}");
    
    // Use post-frame callback to ensure UI is built before accessing the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Access provider after UI is ready
      final controller = ref.read(callControllerProvider(params.toRecord()).notifier);
      AppLogger.d("CallScreen: Call controller initialized for call ID: ${params.callId}");
      
      // If we're the callee (the one receiving the call), automatically answer
      if (!params.isCaller && params.callId.isNotEmpty) {
        AppLogger.d("CallScreen: Auto-answering incoming call as callee");
        // Short delay to ensure controller is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          controller.answerCall();
        });
      }
      
      // Set up timer and state listeners only once
      if (!_hasSetupListeners) {
        _setupCallStateListeners(params);
        _hasSetupListeners = true;
      }
    });
  }

  // Combined method to set up all state listeners in one place
  void _setupCallStateListeners(CallParams params) {
    final callState = ref.read(callControllerProvider(params.toRecord()));
    
    // Start timer immediately if already connected
    if (callState.connectionState == CallConnectionState.connected) {
      _startTimer();
    }
    
    // Listen for state changes that affect timer and call status
    ref.listenManual(callControllerProvider(params.toRecord()), (previous, next) {
      // First check if widget is still mounted before taking any action
      if (!mounted) {
        AppLogger.d("CallScreen: Ignoring state change as widget is no longer mounted");
        return;
      }
      
      // Handle timer start - when call becomes connected
      if (previous?.connectionState != CallConnectionState.connected && 
          next.connectionState == CallConnectionState.connected) {
        _startTimer();
      } 
      // Handle timer stop - when call disconnects after being connected
      else if (previous?.connectionState == CallConnectionState.connected &&
               next.connectionState != CallConnectionState.connected) {
        // Handle stop timer safely
        if (_callDurationTimer != null) {
          _callDurationTimer!.cancel();
          _callDurationTimer = null;
          AppLogger.d("CallScreen: Timer stopped due to call state change");
        }
      }
      
      // Special handling for call end - preserve the final duration
      if (previous?.connectionState == CallConnectionState.connected && 
          next.connectionState == CallConnectionState.ended) {
        AppLogger.d("CallScreen: Call ended with final duration: ${_formatDuration(_callDuration)}");
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
    
    AppLogger.d("CallScreen: Call duration timer started");
  }

  void _stopTimer({bool resetDuration = true}) {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
    
    // Only reset duration if specified AND widget is still mounted
    // This prevents setState being called during disposal
    if (resetDuration && mounted) {
      // Using try-catch to prevent errors if widget is in an invalid state
      try {
        setState(() {
          _callDuration = Duration.zero;
        });
      } catch (e) {
        AppLogger.e("CallScreen: Error in _stopTimer: $e");
        // Just set the value directly without setState if there's an error
        _callDuration = Duration.zero;
      }
    }
    
    AppLogger.d("CallScreen: Call duration timer stopped, duration preserved: $_callDuration");
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return hours == '00' ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final params = CallParams.fromMap(widget.extraData);
    
    if (params == null) {
      return _buildErrorScaffold('Invalid call parameters');
    }
    
    return _buildCallScreen(params);
  }

  Widget _buildErrorScaffold(String errorMessage) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: Text('chat.call_error_title'.tr()),
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
              child: Text('common.back'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallScreen(CallParams params) {
    // Listen to call state
    final callState = ref.watch(callControllerProvider(params.toRecord()));
    
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        title: Text('chat.start_audio_call'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
              ),
      body: SafeArea(
              child: Center(
                child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
              // Call status and partner info
              _buildCallerInfo(params, callState),
                            
              // Audio waveform or call status icon
              _buildCallStatusVisual(callState),
              
              // Call controls
              _buildCallControls(params, callState),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCallerInfo(CallParams params, CallControllerState callState) {
    return Column(
      children: [
        // User avatar or placeholder
        Container(
              width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            size: 60,
            color: AppColors.primary,
                ),
        ),
        const SizedBox(height: 20),
        
        // User name
        Text(
          _partnerName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Call status text
                      Text(
          _getCallStatusText(callState),
          style: TextStyle(
            fontSize: 16,
            color: _getCallStatusColor(callState),
          ),
                  ),
        
        // Call timer
        if (callState.connectionState == CallConnectionState.connected)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _formatDuration(_callDuration),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                    ),
                  ),
                ),
        ],
    );
  }

  Widget _buildCallStatusVisual(CallControllerState callState) {
    // Return different visuals based on call state
    switch (callState.connectionState) {
      case CallConnectionState.connecting:
      case CallConnectionState.ringing:
        return const AnimatedLoader(size: 120);
        
      case CallConnectionState.connected:
        // Audio waveform visualization would go here
        // For now, just show a simple animation
        return Container(
          width: 200,
          height: 100,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return _buildAudioBar(index);
            }),
          ),
        );
        
      case CallConnectionState.failed:
        return const Icon(
          Icons.error_outline,
          size: 80,
          color: Colors.red,
        );
        
      case CallConnectionState.ended:
        return const Icon(
          Icons.call_end,
          size: 80,
          color: Colors.red,
        );
    }
  }

  // Simple animated audio bar for visualization
  Widget _buildAudioBar(int index) {
    // Create slightly randomized heights for bars based on index
    final heights = [30.0, 45.0, 60.0, 40.0, 25.0];
    final height = heights[index % heights.length];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 10,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildCallControls(CallParams params, CallControllerState callState) {
    final callController = ref.read(callControllerProvider(params.toRecord()).notifier);
    
    // Don't show controls if call has ended or failed
    if (callState.connectionState == CallConnectionState.ended || 
        callState.connectionState == CallConnectionState.failed) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Text('common.close'.tr()),
        ),
      );
    }
    
    // For connecting/ringing state (callee view)
    if (!params.isCaller && 
        (callState.connectionState == CallConnectionState.connecting || 
         callState.connectionState == CallConnectionState.ringing)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Reject button
          CircularIconButton(
            icon: Icons.call_end,
            backgroundColor: Colors.red,
            onPressed: () {
              callController.rejectCall();
              Navigator.of(context).pop();
            },
            size: 64,
          ),
          const SizedBox(width: 48),
          
          // Answer button
          CircularIconButton(
            icon: Icons.call,
            backgroundColor: Colors.green,
            onPressed: () => callController.answerCall(),
            size: 64,
          ),
        ],
      );
    }

    // For ongoing call
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        CircularIconButton(
          icon: callState.isMuted ? Icons.mic_off : Icons.mic,
          backgroundColor: callState.isMuted ? Colors.grey : AppColors.primary,
          onPressed: () => callController.toggleMute(),
          size: 56,
        ),
        
        // End call button
        CircularIconButton(
          icon: Icons.call_end,
          backgroundColor: Colors.red,
          onPressed: () {
            callController.hangUp();
            Navigator.of(context).pop();
          },
          size: 64,
        ),
        
        // Speaker button
        CircularIconButton(
          icon: callState.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          backgroundColor: callState.isSpeakerOn ? AppColors.primary : Colors.grey,
          onPressed: () => callController.toggleSpeaker(),
          size: 56,
        ),
      ],
    );
  }

  String _getCallStatusText(CallControllerState callState) {
    switch (callState.connectionState) {
      case CallConnectionState.connecting:
        return 'chat.call_status_connecting'.tr();
      case CallConnectionState.ringing:
        return 'chat.call_status_ringing'.tr();
      case CallConnectionState.connected:
        return 'chat.call_status_connected'.tr();
      case CallConnectionState.ended:
        // Additional check for ended calls with duration
        if (callState.callStatus == 'completed' || 
            (callState.callStatus == 'ended' && _callDuration.inSeconds > 0)) {
          // Return a status that shows it was a successful call
          return 'chat.call_completed'.tr();
        }
        // Otherwise handle as before
        return callState.callStatus == 'rejected' ? 'chat.call_rejected'.tr() : 'chat.call_ended'.tr();
      case CallConnectionState.failed:
        return callState.errorMessage ?? 'chat.call_error_generic'.tr();
    }
  }

  Color _getCallStatusColor(CallControllerState callState) {
    switch (callState.connectionState) {
      case CallConnectionState.connecting:
      case CallConnectionState.ringing:
        return Colors.orange;
      case CallConnectionState.connected:
        return Colors.green;
      case CallConnectionState.ended:
      case CallConnectionState.failed:
        return Colors.red;
    }
    
    // Default fallback color if none matched (shouldn't happen with enum)
    return Colors.grey;
  }

  @override
  void dispose() {
    AppLogger.d("CallScreen: Disposing screen");
    
    // Cancel timer directly instead of using _stopTimer to avoid setState calls
    if (_callDurationTimer != null) {
      _callDurationTimer!.cancel();
      _callDurationTimer = null;
      AppLogger.d("CallScreen: Timer cancelled during dispose");
    }
    
    super.dispose();
  }
}

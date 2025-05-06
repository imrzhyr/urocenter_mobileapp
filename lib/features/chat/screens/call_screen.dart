import 'dart:async';
import 'package:urocenter/core/utils/logger.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:urocenter/core/theme/app_colors.dart';
import 'package:urocenter/features/chat/providers/call_controller.dart';
import 'package:urocenter/features/chat/models/call_params.dart';
import 'package:urocenter/core/widgets/circular_icon_button.dart';
import 'package:urocenter/core/widgets/animated_loader.dart';

/// Screen for handling audio/video calls - Now using Riverpod
class CallScreen extends ConsumerStatefulWidget { // Changed to ConsumerStatefulWidget
  final Map<String, dynamic>? extraData;

  const CallScreen({super.key, required this.extraData});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState(); // Changed to ConsumerState
}

class _CallScreenState extends ConsumerState<CallScreen> { // Changed to ConsumerState
  // Call Info State (kept from arguments)
  // String _partnerName = 'Contact';
  // String? _callId;
  // bool _isCaller = false;
  // String _initialError = ''; // To show initialization errors

  // Keep Renderers managed by the widget state
  late final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  late final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Timer? _callDurationTimer;
  Duration _callDuration = Duration.zero;

  // Remove old WebRTC/Firestore state variables
  // RTCPeerConnection? _peerConnection;
  // MediaStream? _localStream;
  // String _callStatus = 'Initializing...';
  // bool _isMuted = false;
  // StreamSubscription? _callDocSubscription;
  // StreamSubscription? _mainCallDocSubscription;
  // bool _initialUpdatesComplete = false;
  // final List<RTCIceCandidate> _pendingIceCandidates = [];
  // final Map<String, dynamic> _configuration = { ... };
  // final Map<String, dynamic> _sdpConstraints = { ... };

  @override
  void initState() {
    super.initState();
    AppLogger.d("CallScreen: initState called");
    
    // First, initialize renderers
    _initRenderers();

    // Parse and validate parameters
    final params = CallParams.fromMap(widget.extraData);
    if (params == null) {
      AppLogger.d("CallScreen: Invalid parameters received");
      return;
    }

    AppLogger.d("CallScreen: Valid parameters received for call ID: ${params.callId}");
    
    // Use post-frame callback to ensure UI is built before accessing the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Access provider after UI is ready
      ref.read(callControllerProvider(params.toRecord()));
      AppLogger.d("CallScreen: Call controller initialized for call ID: ${params.callId}");
      
      // Check if we should start timer
      _maybeStartTimer();
    });
  }

  bool _renderersInitialized = false;
  
  Future<void> _initRenderers() async {
    try {
      AppLogger.d("CallScreen: Initializing renderers");
      
      // Clear any previous initializations
      if (_localRenderer.textureId != null) {
        await _localRenderer.dispose();
      }
      if (_remoteRenderer.textureId != null) {
        await _remoteRenderer.dispose();
      }
      
      // Reset initialization flag
      if (mounted) {
        setState(() {
          _renderersInitialized = false;
        });
      }
      
      // Initialize renderers with proper error handling
      await _localRenderer.initialize().catchError((e) {
        AppLogger.e("Failed to initialize local renderer: $e");
        throw e;  // Rethrow to be caught by the outer try-catch
      });
      
      await _remoteRenderer.initialize().catchError((e) {
        AppLogger.e("Failed to initialize remote renderer: $e");
        throw e;  // Rethrow to be caught by the outer try-catch
      });
      
      // Wait a small amount of time to ensure WebRTC is ready
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Double check the texture IDs are available
      if (_localRenderer.textureId == null || _remoteRenderer.textureId == null) {
        AppLogger.w("WARNING: Renderer texture IDs are null after initialization");
        throw Exception("Renderer texture IDs not available after initialization");
      }
      
      // Only update state if both renderers initialized successfully and component is still mounted
      if (mounted) {
        setState(() {
          _renderersInitialized = true;
          AppLogger.d("CallScreen: Renderers initialized successfully");
        });
        
        // Log the renderer state after initialization
        _logRendererState();
        
        // Check if we should update streams from current state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          
          final params = CallParams.fromMap(widget.extraData);
          if (params == null) return;
          
          final callState = ref.read(callControllerProvider(params.toRecord()));
          if (callState != null) {
            _updateRendererStreams(callState);
          }
        });
      }
    } catch (e) {
      AppLogger.e("CallScreen: Failed to initialize renderers: $e");
      if (mounted) {
        // Mark initialization as failed but don't crash the UI
        setState(() {
          _renderersInitialized = false;
        });
        
        // Try again once after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            AppLogger.d("Retrying renderer initialization...");
            _retryInitRenderers();
          }
        });
      }
    }
  }

  // Separate method for retry to avoid infinite recursion
  Future<void> _retryInitRenderers() async {
    try {
      // Simple retry without the retry logic to avoid loop
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      
    if (mounted) {
      setState(() {
          _renderersInitialized = true;
          AppLogger.d("CallScreen: Renderers initialized successfully on retry");
        });
        
        _logRendererState();
      }
    } catch (e) {
      AppLogger.e("CallScreen: Failed to initialize renderers on retry: $e");
      // Don't attempt further retries
    }
  }

  // Process navigation arguments and trigger controller initialization
  // void _processArgsAndInitializeController() {
  //   String? receivedCallId;
  //   String? partnerName;
  //   bool isCaller = false;

  //   if (widget.extraData is Map) {
  //     final Map data = widget.extraData as Map;
  //     receivedCallId = data['callId'] as String?;
  //     partnerName = data['partnerName'] as String?;
  //     isCaller = data['isCaller'] as bool? ?? false;
  //     AppLogger.d("[CallScreen Init] Received CallID: $receivedCallId, Partner: $partnerName, IsCaller: $isCaller");
  //   }

  //   if (receivedCallId == null) {
  //     AppLogger.e("[CallScreen Error] Call ID is null. Cannot proceed.");
  //     if (mounted) {
  //       setState(() {
  //         _initialError = "Error: Invalid Call ID";
  //       });
  //       // Optionally pop after a delay
  //       Future.delayed(const Duration(seconds: 3), () {
  //          if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  //       });
  //     }
  //     return;
  //   }

  //   // Update local state with basic call info needed for the provider params
  //   setState(() {
  //     _callId = receivedCallId;
  //     _partnerName = partnerName ?? _partnerName; // Use provided name or default
  //     _isCaller = isCaller;
  //     _initialError = ''; // Clear any previous error
  //   });

  //   // Initialize the controller if callId is valid
  //   final params = CallControllerParams(callId: _callId!, isCaller: _isCaller);
  //   // Use ref.read here as we are calling a method, not listening continuously
  //   // Pass context if controller needs it for permissions/dialogs
  //   ref.read(callControllerProvider(params).notifier).initializeCall(context);
  //   AppLogger.d("[CallScreen Init] CallController initialization triggered for call ID: $_callId");
  // }

  // Remove old WebRTC/Firestore methods:
  // Future<void> _processExtraDataAndInitialize() async { ... }
  // Future<void> _initializeCallSequence(...) async { ... }
  // Future<Map<String, dynamic>?> _fetchOffer() async { ... }
  // Future<bool> _setupPeerConnection() async { ... }
  // void _registerPeerConnectionListeners() { ... }
  // Future<void> _createAndSendOffer() async { ... }
  // Future<void> _processOfferAndCreateAnswer(...) async { ... }
  // Future<void> _sendIceCandidate(...) async { ... }
  // void _listenForRemoteCandidates() { ... }
  // Future<void> _processAnswer(...) async { ... }
  // void _listenForCallDocumentChanges() { ... }
  // void _updateStatus(...) { ... }
  // void _toggleMute() { ... } // Replaced by controller call
  // void _hangUp(...) { ... } // Replaced by controller call
  // Future<void> _cleanup() async { ... } // Controller handles cleanup

  @override
  void dispose() {
    AppLogger.d("[CallScreen Dispose] Disposing renderers");
    try {
      _callDurationTimer?.cancel();
      
      // Release any stream assignments first
      if (_renderersInitialized) {
        try {
          if (_localRenderer.srcObject != null) {
            AppLogger.d("Clearing local renderer source object");
            _localRenderer.srcObject = null;
          }
          
          if (_remoteRenderer.srcObject != null) {
            AppLogger.d("Clearing remote renderer source object");
            _remoteRenderer.srcObject = null;
          }
        } catch (e) {
          AppLogger.e("Error clearing renderer source objects: $e");
          // Continue with disposal anyway
        }
      }
      
      // Then dispose renderers
      try {
        AppLogger.d("Disposing local renderer");
        _localRenderer.dispose();
     } catch (e) {
        AppLogger.e("Error disposing local renderer: $e");
      }
      
      try {
        AppLogger.d("Disposing remote renderer");
        _remoteRenderer.dispose();
     } catch (e) {
        AppLogger.e("Error disposing remote renderer: $e");
      }
      
      AppLogger.d("[CallScreen Dispose] Renderers disposed successfully");
    } catch (e) {
      AppLogger.e("[CallScreen Dispose] Error during cleanup: $e");
    }
    // Controller cleanup is handled by Riverpod's autoDispose
    super.dispose();
  }

  // Create safe error UI for displaying error messages
  Widget createErrorUI(String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (mounted) Navigator.of(context).pop();
              },
              child: Text('common.ok'.tr()),
            )
          ],
        ),
      ),
    );
  }

  // Build method for the UI - Now uses Riverpod state
  @override
  Widget build(BuildContext context) {
    // First, handle parameter validation and extraction
    if (widget.extraData == null) {
      return createErrorUI('Invalid call parameters');
    }

    final callParam = CallParams.fromMap(widget.extraData);
    if (callParam == null) {
      return createErrorUI('Call initialization failed');
    }

    // Watch the controller provider to get updates
    late final CallControllerState callState;
    
    try {
      // Use a local non-nullable variable to simplify the rest of the code
      final state = ref.watch(callControllerProvider(callParam.toRecord()));
      if (state == null) {
        AppLogger.d("Call state is null");
        return createErrorUI('Call initialization failed');
      }
      callState = state;
      AppLogger.d("Call state retrieved successfully");
    } catch (e) {
      AppLogger.e("Error watching call controller: $e");
      return createErrorUI('Error initializing call');
    }

    // Update renderer streams ONLY when renderers are initialized
    // Don't do it directly in build method, use post-frame callback
    if (_renderersInitialized && _localRenderer.textureId != null && _remoteRenderer.textureId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _renderersInitialized) {
          // Only update if the state is still valid
          _updateRendererStreams(callState);
        }
      });
    } else {
      AppLogger.d("Renderers not fully initialized yet. Skipping stream update.");
    }

    // Check connection state and potentially start timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeStartTimer();
    });

    // --- Build UI based on Call State ---
    return Scaffold(
      backgroundColor: Colors.black, // Background for the whole call screen
      body: Stack(
        children: [
          // --- Remote Video ---
          // Only show the video view if all conditions are met
          if (_renderersInitialized && 
              callState.remoteStream != null && 
              _remoteRenderer.textureId != null &&
              callState.connectionState == CallConnectionState.connected)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                mirror: false, // Typically don't mirror remote view
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            // Placeholder when remote video is not available or call not connected
            Container(
              color: Colors.grey[800],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (callState.connectionState == CallConnectionState.connecting || callState.connectionState == CallConnectionState.ringing)
                      const AnimatedLoader() // Replaced LoadingIndicator
                    else if (callState.connectionState != CallConnectionState.ended)
                      const Icon(Icons.person, size: 80, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(
                      callParam.partnerName,
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 8),
            Text(
                      _getStatusText(callState.connectionState),
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ).tr(),
                  ],
                ),
              ),
            ),

          // --- Local Video (Picture-in-Picture) ---
          // Only show if all conditions are met
          if (_renderersInitialized && 
              callState.localStream != null && 
              _localRenderer.textureId != null &&
              callState.connectionState == CallConnectionState.connected)
            Positioned(
              top: 40,
              right: 20,
              width: 100,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true, // Mirror local view
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          // --- Call Controls ---
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                CircularIconButton(
                  icon: callState.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  onPressed: () => ref.read(callControllerProvider(callParam.toRecord()).notifier).toggleSpeaker(),
                  backgroundColor: Colors.white.withValues(alpha: 77.0),
                  iconColor: Colors.white,
                ),
                CircularIconButton(
                  icon: callState.isMuted ? Icons.mic_off : Icons.mic,
                  onPressed: () => ref.read(callControllerProvider(callParam.toRecord()).notifier).toggleMute(),
                  backgroundColor: Colors.white.withValues(alpha: 77.0),
                  iconColor: Colors.white,
                ),
                CircularIconButton(
                  icon: Icons.call_end,
                  onPressed: () async {
                    await ref.read(callControllerProvider(callParam.toRecord()).notifier).hangUp();
                    // Consider navigating back after hangup, potentially checking mounted state
                    // if (mounted) {
                    //   context.pop();
                    // }
                  },
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),

           // --- Call Status Overlay ---
          // Removed the previous status overlay logic, integrated into the main placeholder

          // --- Error Display ---
          if (callState.connectionState == CallConnectionState.failed)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 179.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        'chat.call_error_title'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                       const SizedBox(height: 5),
                      Text(
                        callState.errorMessage ?? 'chat.call_error_generic'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                           if (mounted) {
                             Navigator.of(context).pop(); // Go back on error
                           }
                        },
                        child: Text('common.ok'.tr()),
                      )
                    ],
                  ),
                ),
              ),
            ),
             // --- Call Ended Display ---
             if (callState.connectionState == CallConnectionState.ended)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 204.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            callState.callStatus == 'missed' ? 'chat.call_missed'.tr() : 'chat.call_ended'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            callParam.partnerName,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 10),
                          // Only show duration if the call was actually connected (not missed)
                          if (callState.callStatus != 'missed' && _callDuration.inSeconds > 0)
                            Text(
                              _formatCallDuration(_callDuration),
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 120, // Fixed width button instead of full width
                            child: ElevatedButton(
                              onPressed: () {
                                if (mounted) {
                                  Navigator.of(context).pop(); // Go back when call ends
                                }
                              },
                              child: Text('common.close'.tr()),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),

        ],
      ),
    );
  }

  String _getStatusText(CallConnectionState status) {
    switch (status) {
      case CallConnectionState.connecting:
        return 'chat.call_status_connecting';
      case CallConnectionState.ringing:
        return 'chat.call_status_ringing';
      case CallConnectionState.connected:
        return 'chat.call_status_connected'; // Usually hidden when video shows
      case CallConnectionState.ended:
        return 'chat.call_ended'; // Or handled by the overlay
      case CallConnectionState.failed:
        return 'chat.call_error_title'; // Or handled by the overlay
    }
  }

  void _startCallTimer() {
    _callDurationTimer?.cancel(); // Cancel any existing timer
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Check if the call is still active before incrementing
      final params = CallParams.fromMap(widget.extraData);
      if(params == null) { // Safety check
          timer.cancel();
          return;
      }
      final callState = ref.read(callControllerProvider(params.toRecord())); // Read current state
      // Use string comparison for callStatus
      if (callState.connectionState == CallConnectionState.connected && callState.callStatus == 'active') {
        setState(() {
          _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
        });
      } else {
        // Stop timer if call is no longer active/connected
        timer.cancel();
        AppLogger.d("Call timer stopped. State: ${callState.connectionState}, Status: ${callState.callStatus}");
      }
    });
  }

  // Format call duration as MM:SS
  String _formatCallDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

   // Helper to check state and start timer
   void _maybeStartTimer() {
     if (!mounted) return;
     final params = CallParams.fromMap(widget.extraData);
     if (params == null) return;
     final callState = ref.read(callControllerProvider(params.toRecord()));
     // Use string comparison
     if (callState.connectionState == CallConnectionState.connected && callState.callStatus == 'active') {
       _startCallTimer();
     }
   }

   // Helper method to log renderer state for debugging
   void _logRendererState() {
     AppLogger.d("=== Renderer State ===");
     AppLogger.d("Renderers initialized: $_renderersInitialized");
     AppLogger.d("Local renderer texture ID: ${_localRenderer.textureId}");
     AppLogger.d("Remote renderer texture ID: ${_remoteRenderer.textureId}");
     if (_renderersInitialized) {
       AppLogger.d("Local stream assigned: ${_localRenderer.srcObject != null}");
       AppLogger.d("Remote stream assigned: ${_remoteRenderer.srcObject != null}");
     }
     AppLogger.d("=====================");
   }

  // Call this after setting renderer streams - with improved error handling
  void _updateRendererStreams(CallControllerState callState) {
    if (!_renderersInitialized) {
      AppLogger.d("Cannot update renderer streams: Renderers not initialized");
      return;
    }

    // Verify texture IDs are valid
    if (_localRenderer.textureId == null || _remoteRenderer.textureId == null) {
      AppLogger.d("Cannot update renderer streams: Texture IDs are null");
      // Try to re-initialize renderers
      _initRenderers();
      return;
    }

    // Local stream assignment with proper guards
    if (callState.localStream != null) {
      try {
        // Only set srcObject if it's different from the current one
        if (_localRenderer.srcObject != callState.localStream) {
          AppLogger.d("Setting local renderer source object");
          // Initialize the renderer first if needed
          if (_localRenderer.textureId == null) {
            AppLogger.e("Error: Local renderer not initialized before setting stream");
            return;
          }
          _localRenderer.srcObject = callState.localStream;
          
          // Verify the source object was set correctly
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_localRenderer.srcObject == null) {
              AppLogger.w("WARNING: Local renderer source object is null after setting");
            } else {
              AppLogger.d("Local renderer source object set successfully");
            }
          });
        }
      } catch (e) {
        AppLogger.e("Error setting local renderer source: $e");
        // Mark as uninitialized to trigger a potential re-init
        if (mounted) {
          setState(() {
            _renderersInitialized = false;
          });
          
          // Try to re-initialize renderers after an error
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _initRenderers();
            }
          });
        }
      }
    }
    
    // Remote stream assignment with proper guards
    if (callState.remoteStream != null) {
      try {
        // Only set srcObject if it's different from the current one
        if (_remoteRenderer.srcObject != callState.remoteStream) {
          AppLogger.d("Setting remote renderer source object");
          // Initialize the renderer first if needed
          if (_remoteRenderer.textureId == null) {
            AppLogger.e("Error: Remote renderer not initialized before setting stream");
            return;
          }
          _remoteRenderer.srcObject = callState.remoteStream;
          
          // Verify the source object was set correctly
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_remoteRenderer.srcObject == null) {
              AppLogger.w("WARNING: Remote renderer source object is null after setting");
            } else {
              AppLogger.d("Remote renderer source object set successfully");
            }
          });
        }
      } catch (e) {
        AppLogger.e("Error setting remote renderer source: $e");
        // Handle error, but don't try to re-init here to avoid infinite loops
      }
    }
    
    // Log state after update
    _logRendererState();
  }
}

// Remove helper function if no longer needed
// int min(int a, int b) => a < b ? a : b;

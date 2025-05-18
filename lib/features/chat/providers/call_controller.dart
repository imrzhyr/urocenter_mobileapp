import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:urocenter/core/services/call_service.dart';

// Define an enum for call connection states
enum CallConnectionState {
  connecting,
  ringing,
  connected,
  ended,
  failed,
}

// CallControllerState to track call state
class CallControllerState {
  final CallConnectionState connectionState;
  final bool isMuted;
  final bool isSpeakerOn;
  final String? errorMessage;
  final String callStatus; // 'pending', 'ringing', 'answered', 'rejected', 'ended'
  final int callDuration; // Duration in seconds
  final DateTime? callStartTime; // When the call was actually connected

  CallControllerState({
    this.connectionState = CallConnectionState.connecting,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.errorMessage,
    this.callStatus = 'pending',
    this.callDuration = 0,
    this.callStartTime,
  });

  CallControllerState copyWith({
    CallConnectionState? connectionState,
    bool? isMuted,
    bool? isSpeakerOn,
    String? errorMessage,
    String? callStatus,
    int? callDuration,
    DateTime? callStartTime,
  }) {
    return CallControllerState(
      connectionState: connectionState ?? this.connectionState,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      errorMessage: errorMessage ?? this.errorMessage,
      callStatus: callStatus ?? this.callStatus,
      callDuration: callDuration ?? this.callDuration,
      callStartTime: callStartTime ?? this.callStartTime,
    );
  }
}

// Record type for parameters
typedef CallControllerParams = ({String callId, bool isCaller});

final callControllerProvider = StateNotifierProvider.family<CallController, CallControllerState, CallControllerParams>(
  (ref, params) => CallController(ref, params.callId, params.isCaller),
);

class CallController extends StateNotifier<CallControllerState> {
  final String callId;
  final bool isCaller;
  final Ref ref;
  
  // Agora engine instance
  RtcEngine? _agoraEngine;
  StreamSubscription? _callDocSubscription;
  RtcEngineEventHandler? _eventHandler;
  Timer? _durationTimer;
  
  // Agora app configuration
  final String _appId = "ca991212e7b4432bb35fe5047fd54cb0";
  String _channelName = ""; // Will be set to callId
  
  // Static set to track channels that are in the process of being left
  static final Set<String> _leavingChannels = {};
  
  CallController(this.ref, this.callId, this.isCaller)
      : super(CallControllerState(
          callStatus: isCaller ? 'pending' : 'ringing',
          connectionState: isCaller ? CallConnectionState.connecting : CallConnectionState.ringing,
        )) {
    // Initialize call on creation
    initCall();
  }

  // Initialize a call
  Future<void> initCall() async {
    try {
      AppLogger.d("[CallController] Initializing call with Agora");
      
      // Setup Agora SDK
      await _setupAgoraSDK();
      
      // Start listening for call document changes
      _listenForCallDocumentChanges();
      
      if (isCaller) {
        // Create and send offer - no need to create the call document
        // as the service has already done this
        await _updateCallStatus('ringing');
      }
    } catch (e) {
      AppLogger.e("[CallController] Error initializing call: $e");
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Failed to initialize call: $e",
      );
    }
  }

  // Setup Agora SDK
  Future<void> _setupAgoraSDK() async {
    try {
      // Create RtcEngine instance
      _agoraEngine = createAgoraRtcEngine();
      
      // Initialize the engine
      await _agoraEngine!.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      
      // Setup event handlers
      _registerEventHandlers();
      
      // Set channel name to call ID for easy matching
      _channelName = callId;
      
      // OPTIMIZATION: Pre-configure audio settings for faster setup
      // Enable audio processing with optimized parameters
      await _agoraEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _agoraEngine!.enableAudio();
      await _agoraEngine!.disableVideo();
      
      // Reduce audio processing delay
      await _agoraEngine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioChatroom, // Optimize for voice
      );
      
      // Additional audio optimization
      await _agoraEngine!.setParameters('{"che.audio.enable.agc": true}'); // Auto gain control
      await _agoraEngine!.setParameters('{"che.audio.enable.aec": true}'); // Echo cancellation
      await _agoraEngine!.setParameters('{"che.audio.enable.ns": true}');  // Noise suppression

      // Pre-warm audio system to reduce initial delay
      await _agoraEngine!.startPreview();
      
      AppLogger.d("[CallController] Agora SDK setup complete with optimized audio settings");
    } catch (e) {
      AppLogger.e("[CallController] Error setting up Agora SDK: $e");
      rethrow;
    }
  }

  // Register Agora event handlers - only one place that handles connection events
  void _registerEventHandlers() {
    // First unregister any existing handlers
    _unregisterEventHandlers();
    
    // Create a new event handler
    _eventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        AppLogger.d("[CallController] Successfully joined channel: ${connection.channelId}");
        
        // Record the call start time for duration calculation
        final startTime = DateTime.now();
        
        // Update state to connected
        state = state.copyWith(
          connectionState: CallConnectionState.connected,
          callStatus: 'answered',
          callStartTime: startTime,
        );
        
        // Start the duration timer
        _startDurationTimer();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        AppLogger.d("[CallController] Remote user joined: $remoteUid");
        // No state updates here - we handle connection state in onJoinChannelSuccess
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        AppLogger.d("[CallController] Remote user left: $remoteUid, reason: $reason");
        
        // Only handle remote user leaving as end of call if they quit
        if (reason == UserOfflineReasonType.userOfflineQuit) {
          hangUp(userInitiated: false);
        }
      },
      onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
        AppLogger.d("[CallController] Connection state changed: $state, reason: $reason");
        
        if (state == ConnectionStateType.connectionStateDisconnected || 
            state == ConnectionStateType.connectionStateFailed) {
          this.state = this.state.copyWith(
            connectionState: CallConnectionState.failed,
            errorMessage: "Connection lost. Please try again.",
          );
        }
      },
      onError: (ErrorCodeType err, String msg) {
        AppLogger.e("[CallController] Error occurred: $err, $msg");
        
        // Handle critical errors
        if (err.value() >= 1000 && err.value() < 2000) {
          state = state.copyWith(
            connectionState: CallConnectionState.failed,
            errorMessage: "Call error: $msg",
          );
        }
      },
    );
    
    // Register the new handler
    _agoraEngine?.registerEventHandler(_eventHandler!);
  }
  
  // Unregister event handlers to prevent duplicates
  void _unregisterEventHandlers() {
    if (_eventHandler != null && _agoraEngine != null) {
      try {
        _agoraEngine!.unregisterEventHandler(_eventHandler!);
        _eventHandler = null;
        AppLogger.d("[CallController] Unregistered previous event handlers");
      } catch (e) {
        AppLogger.e("[CallController] Error unregistering event handlers: $e");
      }
    }
  }

  // Start timer to track call duration
  void _startDurationTimer() {
    // Cancel any existing timer
    _durationTimer?.cancel();
    
    // Create a new timer that fires every second
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.callStartTime != null) {
        final now = DateTime.now();
        final durationSeconds = now.difference(state.callStartTime!).inSeconds;
        
        state = state.copyWith(callDuration: durationSeconds);
      }
    });
  }

  // Stop timer tracking call duration
  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  // Listen for call document changes
  void _listenForCallDocumentChanges() {
    final callService = ref.read(callServiceProvider);
    
    _callDocSubscription = callService.getCallDocStream(callId).listen((doc) async {
      if (!doc.exists) {
        AppLogger.d("[CallController] Call document does not exist");
        state = state.copyWith(
          connectionState: CallConnectionState.failed,
          errorMessage: "Call not found or was deleted",
        );
        return;
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final callStatus = data['status'] as String? ?? 'pending';
      
      AppLogger.d("[CallController] Call document updated with status: $callStatus");
      
      switch (callStatus) {
        case 'pending':
          // No action needed, already in pending state
          break;
        case 'ringing':
          if (state.connectionState != CallConnectionState.ringing) {
            state = state.copyWith(
              connectionState: CallConnectionState.ringing,
              callStatus: 'ringing',
            );
          }
          break;
        case 'answered':
          // If we're the caller and call was just answered, join the channel
          if (isCaller && state.connectionState != CallConnectionState.connected) {
            AppLogger.d("[CallController] Callee has answered, caller now joining channel");
            _joinChannel();
          }
          break;
        case 'completed':
        case 'rejected':
        case 'missed':
        case 'no_answer':
        case 'ended':
          if (state.connectionState != CallConnectionState.ended) {
            state = state.copyWith(
              connectionState: CallConnectionState.ended,
              callStatus: callStatus,
            );
            _leaveChannel();
          }
          break;
      }
    }, onError: (e) {
      AppLogger.e("[CallController] Error listening to call document: $e");
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Error monitoring call status",
      );
    });
  }

  // Join the Agora channel
  Future<void> _joinChannel() async {
    try {
      // Get token from call service
      final callService = ref.read(callServiceProvider);
      String? token = await callService.getAgoraToken(_channelName);
      
      // If token is null, use an empty string (works in test mode)
      if (token == null) {
        AppLogger.w("[CallController] No valid token available - using empty token");
        token = "";
      }
      
      const uid = 0; // Let the server assign a UID
      
      // OPTIMIZATION: Use high-priority options for faster connection
      const options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        autoSubscribeAudio: true,    // Auto-subscribe to audio
        publishMicrophoneTrack: true, // Publish microphone by default
        enableAudioRecordingOrPlayout: true, // Enable audio immediately
      );
      
      await _agoraEngine?.joinChannel(
        token: token,
        channelId: _channelName,
        uid: uid,
        options: options,
      );
      
      // OPTIMIZATION: Ensure audio is enabled immediately after joining
      await _agoraEngine?.muteLocalAudioStream(false);
      await _agoraEngine?.setEnableSpeakerphone(true);
      
      AppLogger.d("[CallController] Joined Agora channel: $_channelName");
    } catch (e) {
      AppLogger.e("[CallController] Error joining channel: $e");
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Failed to join call: $e",
      );
    }
  }

  // Leave the Agora channel
  Future<void> _leaveChannel() async {
    try {
      // Stop duration timer
      _stopDurationTimer();
      
      // Skip if engine is null or already left
      if (_agoraEngine == null) {
        AppLogger.d("[CallController] No active Agora engine to leave channel");
        return;
      }
      
      // Only attempt to leave channel once
      if (_leavingChannels.contains(callId)) {
        AppLogger.d("[CallController] Channel leave already in progress for call $callId");
        return;
      }
      
      _leavingChannels.add(callId);
      
      try {
        await _agoraEngine?.leaveChannel();
        AppLogger.d("[CallController] Left Agora channel");
      } finally {
        // Always remove from the set to allow future leave attempts
        _leavingChannels.remove(callId);
      }
    } catch (e) {
      AppLogger.e("[CallController] Error leaving channel: $e");
    }
  }

  // Update call status in Firestore
  Future<void> _updateCallStatus(String status) async {
    try {
      final callService = ref.read(callServiceProvider);
      await callService.updateCallStatus(callId, status);
      
      // Update local state too
      state = state.copyWith(callStatus: status);
      
      AppLogger.d("[CallController] Updated call status to: $status");
    } catch (e) {
      AppLogger.e("[CallController] Error updating call status: $e");
    }
  }

  // Toggle mute
  void toggleMute() {
    final currentMuteState = state.isMuted;
    _agoraEngine?.muteLocalAudioStream(!currentMuteState);
    
    state = state.copyWith(isMuted: !currentMuteState);
    AppLogger.d("[CallController] Mic ${!currentMuteState ? 'muted' : 'unmuted'}");
  }

  // Toggle speaker
  void toggleSpeaker() {
    final currentSpeakerState = state.isSpeakerOn;
    _agoraEngine?.setEnableSpeakerphone(!currentSpeakerState);
    
    state = state.copyWith(isSpeakerOn: !currentSpeakerState);
    AppLogger.d("[CallController] Speaker ${!currentSpeakerState ? 'on' : 'off'}");
  }

  // Answer call
  Future<void> answerCall() async {
    try {
      AppLogger.d("[CallController] Answering call: $callId");
      
      // Update call status to 'answered'
      await _updateCallStatus('answered');
      
      // Join the channel
      await _joinChannel();
      
      AppLogger.d("[CallController] Call answered and joined channel");
    } catch (e) {
      AppLogger.e("[CallController] Error answering call: $e");
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Failed to answer call: $e",
      );
    }
  }

  // Reject call
  Future<void> rejectCall() async {
    try {
      await _updateCallStatus('rejected');
      
      state = state.copyWith(
        connectionState: CallConnectionState.ended,
        callStatus: 'rejected',
      );
      
      AppLogger.d("[CallController] Call rejected");
    } catch (e) {
      AppLogger.e("[CallController] Error rejecting call: $e");
    }
  }

  // Hang up call
  Future<void> hangUp({bool userInitiated = true}) async {
    try {
      // Stop duration timer first
      _stopDurationTimer();

      String finalStatusForFirestoreUpdate;
      bool shouldUpdateFirestore = false;

      if (userInitiated) {
        shouldUpdateFirestore = true;
        if (state.connectionState == CallConnectionState.connected) {
          AppLogger.d("[CallController] Call was connected, local hangup will mark as 'completed'");
          finalStatusForFirestoreUpdate = 'completed';
        } else {
          AppLogger.d("[CallController] Call was not connected (or already ended), local hangup will mark as 'ended'");
          finalStatusForFirestoreUpdate = 'ended';
        }
        // Only update Firestore if the status is changing or needs to be set definitively by this client
        // And avoid updating if the call is already definitively over by some other means.
        final currentFirestoreStatus = await ref.read(callServiceProvider).getCallStatus(callId);
        if (currentFirestoreStatus != 'completed' && currentFirestoreStatus != 'rejected' && currentFirestoreStatus != 'missed' && currentFirestoreStatus != 'no_answer') {
            if (currentFirestoreStatus != finalStatusForFirestoreUpdate) {
                 AppLogger.d("[CallController] Updating Firestore to $finalStatusForFirestoreUpdate from $currentFirestoreStatus");
                 await _updateCallStatus(finalStatusForFirestoreUpdate);
            } else {
                 AppLogger.d("[CallController] Firestore status $currentFirestoreStatus already matches $finalStatusForFirestoreUpdate. No Firestore update from hangUp.");
                 // If it's already 'completed' but we initiated, we might still want to ensure our _updateCallStatus logic runs
                 // if it does more than just set status (e.g. specific duration handling by caller).
                 // For now, let's assume if status matches, it's okay.
            }
        } else {
            AppLogger.d("[CallController] Call already in a final Firestore state ($currentFirestoreStatus). No Firestore update from hangUp.");
        }

      } else {
        // If not user initiated (e.g., remote hangup), we don't update Firestore status from here.
        // We rely on the remote party or other listeners to have set the final status.
        // We just need to update local state and leave the channel.
        AppLogger.d("[CallController] Hangup not user initiated (e.g. remote left). Local state will be updated.");
        finalStatusForFirestoreUpdate = state.callStatus; // Keep current status for local UI
      }
      
      // Leave the channel
      await _leaveChannel(); // This also calls _stopDurationTimer() internally again, which is harmless.
      
      // Update local controller state
      // If user initiated, use the determined finalStatus.
      // If not user initiated, state.callStatus should have been updated by _listenForCallDocumentChanges.
      final newLocalCallStatus = userInitiated 
          ? (state.connectionState == CallConnectionState.connected ? 'completed' : 'ended') 
          : state.callStatus; // Fallback to existing status if not user initiated or use what listener set

      state = state.copyWith(
        connectionState: CallConnectionState.ended,
        callStatus: newLocalCallStatus,
      );
      
      AppLogger.d("[CallController] Call ended. Local controller state updated to: ${state.callStatus}");
    } catch (e) {
      AppLogger.e("[CallController] Error hanging up call: $e");
      // Ensure state reflects failure if hangup process itself fails critically
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Error during hangup: ${e.toString()}",
      );
    }
  }

  @override
  void dispose() {
    AppLogger.d("[CallController] Disposing call controller");
    
    // Clean up resources
    _stopDurationTimer();
    _callDocSubscription?.cancel();
    _unregisterEventHandlers();
    _leaveChannel();
    _agoraEngine?.release();
    
    super.dispose();
  }
} 
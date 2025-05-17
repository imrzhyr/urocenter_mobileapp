import 'dart:async';
import 'package:urocenter/core/utils/logger.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

// Core imports
import 'package:urocenter/core/services/call_service.dart';

// Define an enum for call connection states
enum CallConnectionState {
  connecting,
  ringing,
  connected,
  ended,
  failed,
}

// CallControllerState to track state
class CallControllerState {
  final CallConnectionState connectionState;
  final bool isMuted;
  final bool isSpeakerOn;
  final String? errorMessage;
  final String callStatus; // 'pending', 'ringing', 'answered', 'rejected', 'ended'

  CallControllerState({
    this.connectionState = CallConnectionState.connecting,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.errorMessage,
    this.callStatus = 'pending',
  });

  CallControllerState copyWith({
    CallConnectionState? connectionState,
    bool? isMuted,
    bool? isSpeakerOn,
    String? errorMessage,
    String? callStatus,
  }) {
    return CallControllerState(
      connectionState: connectionState ?? this.connectionState,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      errorMessage: errorMessage ?? this.errorMessage,
      callStatus: callStatus ?? this.callStatus,
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
  // Track the registered event handler
  RtcEngineEventHandler? _eventHandler;
  
  // Agora app configuration
  final String _appId = "ca991212e7b4432bb35fe5047fd54cb0";
  String _channelName = ""; // Will be set to callId
  
  // Static set to track channels that are in the process of being left
  static final Set<String> _leavingChannels = {};
  
  CallController(this.ref, this.callId, this.isCaller)
      : super(CallControllerState(
          callStatus: isCaller ? 'pending' : 'ringing',
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
        // Create and send offer through Firestore to signal the call is pending
        await _createAndSendOffer();
      } else {
        AppLogger.d("[CallController] Waiting for call as callee...");
        // Set initial state to ringing for callee
        state = state.copyWith(
          connectionState: CallConnectionState.ringing,
        );
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
      
      // Setup audio mode
      await _agoraEngine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _agoraEngine!.enableAudio();
      await _agoraEngine!.disableVideo();
      
      AppLogger.d("[CallController] Agora SDK setup complete");
    } catch (e) {
      AppLogger.e("[CallController] Error setting up Agora SDK: $e");
      rethrow;
    }
  }

  // Register Agora event handlers
  void _registerEventHandlers() {
    // First unregister any existing handlers to prevent duplicates
    _unregisterEventHandlers();
    
    // Create a new event handler
    _eventHandler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        AppLogger.d("[CallController] Successfully joined channel: ${connection.channelId}");
        state = state.copyWith(
          connectionState: CallConnectionState.connected,
          callStatus: 'answered',
        );
        
        // Update call status to answered when channel join is successful
        // Only the callee should update the status to answered
        if (!isCaller && state.callStatus != 'answered') {
          _updateCallStatus('answered');
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        AppLogger.d("[CallController] Remote user joined: $remoteUid");
        // User joined, call is now connected
        state = state.copyWith(
          connectionState: CallConnectionState.connected,
          callStatus: 'answered',
        );
        
        // REMOVED: We're now updating call status in onJoinChannelSuccess
        // This avoids both sides trying to update the status simultaneously
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        AppLogger.d("[CallController] Remote user left: $remoteUid, reason: $reason");
        // Handle user leaving - might be end of call
        if (reason == UserOfflineReasonType.userOfflineQuit) {
          // Remote user ended the call
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

  // Listen for call document changes
  void _listenForCallDocumentChanges() {
    final callService = ref.read(callServiceProvider);
    
    _callDocSubscription = callService.getCallDocStream(callId).listen((doc) async {
      if (!doc.exists) {
        AppLogger.d("[CallController] Call document does not exist");
        // Handle case where call document doesn't exist
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
          if (state.connectionState != CallConnectionState.ended) {
            state = state.copyWith(
              connectionState: CallConnectionState.ended,
              callStatus: callStatus,
            );
            _leaveChannel();
          }
          break;
        case 'ended':
          if (state.connectionState != CallConnectionState.ended) {
            state = state.copyWith(
              connectionState: CallConnectionState.ended,
              callStatus: 'ended',
            );
            _leaveChannel();
          }
          break;
      }
    }, onError: (e) {
      AppLogger.e("[CallController] Error listening to call document: $e");
      // Handle error case
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Error monitoring call status",
      );
    });
  }

  // Create and send offer
  Future<void> _createAndSendOffer() async {
    try {
      // We should not be creating a new call document here, as the ChatService already did that.
      // Instead, we should just update the status.
      
      // Update to ringing
      await _updateCallStatus('ringing');
      
      AppLogger.d("[CallController] Sent call offer through Firestore");
      
      state = state.copyWith(
        connectionState: CallConnectionState.ringing,
        callStatus: 'ringing',
      );
    } catch (e) {
      AppLogger.e("[CallController] Error creating and sending offer: $e");
      state = state.copyWith(
        connectionState: CallConnectionState.failed,
        errorMessage: "Failed to initiate call: $e",
      );
    }
  }

  // Join the Agora channel
  Future<void> _joinChannel() async {
    try {
      // Get token from token service
      final callService = ref.read(callServiceProvider);
      String? token = await callService.getAgoraToken(_channelName);
      
      // If token is null, just use an empty string
      // This will only work if app is in test mode in the Agora Console
      if (token == null) {
        AppLogger.w("[CallController] No valid token available - using an empty token. This will only work if test mode is enabled in Agora Console.");
        token = "";
      }
      
      const uid = 0; // 0 means let the server assign one
      const options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
      
      // Log in case of token issues
      AppLogger.d("[CallController] Joining channel with ${token.isEmpty ? 'empty' : 'valid'} token");
      
      await _agoraEngine?.joinChannel(
        token: token,
        channelId: _channelName,
        uid: uid,
        options: options,
      );
      
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
      // Skip if engine is null or already left (not joined)
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
        // Always remove from the set to allow future leave attempts if needed
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
      
      // Update call status in Firestore
      await _updateCallStatus('answered');
      AppLogger.d("[CallController] Call status updated to 'answered'");
      
      // Join the channel
      await _joinChannel();
      
      // Update state to reflect the answered state
      state = state.copyWith(
        connectionState: CallConnectionState.connected,
        callStatus: 'answered',
      );
      
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
      if (userInitiated) {
        // For connected calls, set status to 'completed' to ensure duration gets recorded
        if (state.connectionState == CallConnectionState.connected) {
          AppLogger.d("[CallController] Call was connected, marking as 'completed' instead of 'ended'");
          await _updateCallStatus('completed');
        } else {
          await _updateCallStatus('ended');
        }
      }
      
      await _leaveChannel();
      
      state = state.copyWith(
        connectionState: CallConnectionState.ended,
        callStatus: userInitiated && state.connectionState == CallConnectionState.connected
            ? 'completed'
            : 'ended',
      );
      
      AppLogger.d("[CallController] Call ended");
    } catch (e) {
      AppLogger.e("[CallController] Error hanging up call: $e");
    }
  }

  @override
  void dispose() {
    AppLogger.d("[CallController] Disposing call controller");
    
    // Clean up resources
    _callDocSubscription?.cancel();
    _unregisterEventHandlers(); // Unregister event handlers before releasing
    _leaveChannel();
    _agoraEngine?.release();
    
    super.dispose();
  }
} 

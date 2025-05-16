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
  
  // Agora app configuration
  final String _appId = "bb974772465f4481b6e8430d1d720b0e";
  String _channelName = ""; // Will be set to callId
  
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
    _agoraEngine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          AppLogger.d("[CallController] Successfully joined channel: ${connection.channelId}");
          state = state.copyWith(
            connectionState: CallConnectionState.connected,
            callStatus: 'answered',
          );
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          AppLogger.d("[CallController] Remote user joined: $remoteUid");
          // User joined, call is now connected
          state = state.copyWith(
            connectionState: CallConnectionState.connected,
            callStatus: 'answered',
          );
          
          // Update call document to indicate call is answered
          if (!isCaller) {
            _updateCallStatus('answered');
          }
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
      ),
    );
  }

  // Listen for call document changes
  void _listenForCallDocumentChanges() {
    final callService = ref.read(callServiceProvider);
    
    _callDocSubscription = callService.getCallDocStream(callId).listen((doc) async {
      if (!doc.exists) {
        AppLogger.d("[CallController] Call document does not exist");
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
          state = state.copyWith(
            connectionState: CallConnectionState.ringing,
            callStatus: 'ringing',
          );
          break;
        case 'answered':
          // If we're the caller and call was just answered, join the channel
          if (isCaller && state.callStatus != 'answered') {
            _joinChannel();
          }
          break;
        case 'rejected':
          if (state.connectionState != CallConnectionState.ended) {
            state = state.copyWith(
              connectionState: CallConnectionState.ended,
              callStatus: 'rejected',
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
      const token = null; // Use token for production
      const uid = 0; // 0 means let the server assign one
      const options = ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
      
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
      await _agoraEngine?.leaveChannel();
      AppLogger.d("[CallController] Left Agora channel");
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
      // Update call status in Firestore
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
      if (userInitiated) {
        await _updateCallStatus('ended');
      }
      
      await _leaveChannel();
      
      state = state.copyWith(
        connectionState: CallConnectionState.ended,
        callStatus: 'ended',
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
    _leaveChannel();
    _agoraEngine?.release();
    
    super.dispose();
  }
} 

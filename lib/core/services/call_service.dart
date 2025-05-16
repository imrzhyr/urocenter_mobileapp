import 'dart:async';
import 'package:urocenter/core/utils/logger.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:urocenter/services/chat_service.dart'; // Import ChatService
import 'package:urocenter/providers/service_providers.dart'; // Import service_providers for chatServiceProvider

// Data class to hold incoming call information
class IncomingCall {
  final String callId;
  final String callerId;
  final String callerName;
  // Can add offer SDP here if needed immediately by UI
  final Map<String, dynamic>? offer; 

  IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.offer,
  });
}

// StateNotifier for managing incoming call state
class IncomingCallNotifier extends StateNotifier<IncomingCall?> {
  // Initialize with no incoming call (null state)
  IncomingCallNotifier() : super(null); 

  // Method to set the incoming call
  void setIncomingCall(IncomingCall? call) {
    state = call;
  }

  // Method to clear the incoming call (e.g., when answered or rejected)
  void clearIncomingCall() {
    state = null;
  }
}

// Provider for the IncomingCallNotifier
final incomingCallProvider = StateNotifierProvider<IncomingCallNotifier, IncomingCall?>((ref) {
  return IncomingCallNotifier();
});


class CallService {
  final FirebaseFirestore _firestore;
  final Ref _ref; 

  // Listener subscription - needs to be managed
  StreamSubscription? _callSubscription;

  CallService(this._firestore, this._ref);

  // Method to start listening for calls
  void listenForIncomingCalls(String userId) {
    AppLogger.d("[CallService] Starting listener for incoming calls for user: $userId");
    
    // Cancel any previous subscription
    _callSubscription?.cancel(); 

    final callsRef = _firestore.collection('calls');
    
    _callSubscription = callsRef
        .where('calleeId', isEqualTo: userId)
        .where('status', isEqualTo: 'ringing') // Listen specifically for 'ringing' status
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Usually, there should only be one active incoming call, take the first
        final callDoc = snapshot.docs.first;
        final callData = callDoc.data();
        AppLogger.d("[CallService] Incoming call detected: ${callDoc.id}");

        final incomingCall = IncomingCall(
          callId: callDoc.id,
          callerId: callData['callerId'] ?? 'Unknown Caller',
          callerName: callData['callerName'] ?? 'Unknown',
          offer: callData['offer'] as Map<String, dynamic>?, // Pass offer for immediate use
        );

        // <<< Use Ref to update the StateNotifier >>>
        _ref.read(incomingCallProvider.notifier).setIncomingCall(incomingCall);

      } else {
        // No ringing calls found for this user
        AppLogger.d("[CallService] No active incoming calls found for user: $userId");
        // <<< Use Ref to clear the StateNotifier if no calls are ringing >>>
        _ref.read(incomingCallProvider.notifier).clearIncomingCall();
      }
    }, onError: (error) {
      AppLogger.e("[CallService] Error listening for incoming calls: $error");
      // Optionally clear the provider on error too
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    });
  }

  // Method to stop listening (e.g., on sign out)
  void stopListening() {
    AppLogger.d("[CallService] Stopping listener for incoming calls.");
    _callSubscription?.cancel();
    _callSubscription = null;
     // Clear state when stopping listener
    _ref.read(incomingCallProvider.notifier).clearIncomingCall();
  }

  // --- Call Actions ---

  Future<void> acceptCall(String callId, Map<String, dynamic> sdpAnswerMap) async {
    try {
       AppLogger.d("[CallService] Accepting call: $callId");
       // 1. Update call status in Firestore to 'answered'
       await _firestore.collection('calls').doc(callId).update({
          'status': 'answered',
          'answer': sdpAnswerMap, 
       });
       AppLogger.d("[CallService] Call $callId status updated to answered.");
       // 3. Clear the incomingCallProvider state
       _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    } catch (e) {
       AppLogger.e("[CallService] Error accepting call $callId: $e");
       // Handle error if needed (e.g., show a message)
       // Optionally clear the provider on error too
       _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
       AppLogger.d("[CallService] Rejecting call: $callId");
       await _firestore.collection('calls').doc(callId).update({'status': 'rejected'});
       AppLogger.d("[CallService] Call $callId status updated to rejected.");
       // Notifier will be cleared automatically by the listener finding no 'ringing' calls
       // Or clear explicitly:
       _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    } catch (e) {
       AppLogger.e("[CallService] Error rejecting call $callId: $e");
       // Handle error if needed
    }
  }
  
  // Update call status in Firestore
  Future<void> updateCallStatus(String callId, String status) async {
    try {
      // Get the current call data to determine if we need to generate a chat record
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data();
      
      // Get call start time from document
      DateTime? startTime;
      if (callData != null && callData['startTime'] != null) {
        startTime = (callData['startTime'] as Timestamp).toDate();
      }
      
      // Get current time for end time
      final now = DateTime.now();
      
      // Status update data
      Map<String, dynamic> updateData = {
        'status': status,
      };
      
      // Add end time and calculate duration for completed, rejected, or ended calls
      if (status == 'ended' || status == 'completed' || status == 'rejected' || status == 'missed') {
        updateData['endTime'] = FieldValue.serverTimestamp();
        
        // If we have start time, calculate duration in seconds
        if (startTime != null) {
          final duration = now.difference(startTime).inSeconds;
          updateData['duration'] = duration;
        }
      }
      
      // Update the call document with new status
      await _firestore.collection('calls').doc(callId).update(updateData);
      
      // If the call is ended, completed, rejected, or missed, create a chat message
      if (status == 'ended' || status == 'completed' || status == 'rejected' || status == 'missed') {
        await _createCallEventMessage(callId, status, callData);
      }
      
      AppLogger.d("[CallService] Call $callId status updated to $status");
    } catch (e) {
      AppLogger.e("[CallService] Error updating call status: $e");
    }
  }
  
  // Create a message in chat for a call event
  Future<void> _createCallEventMessage(String callId, String status, Map<String, dynamic>? callData) async {
    try {
      Map<String, dynamic>? data = callData;
      
      // If call data is null or missing critical fields, try to fetch it again
      if (data == null || data['callerId'] == null || data['calleeId'] == null) {
        AppLogger.d("[CallService] Call data missing or incomplete, fetching updated data for call $callId");
        final callDoc = await _firestore.collection('calls').doc(callId).get();
        if (callDoc.exists) {
          data = callDoc.data();
        } else {
          AppLogger.e("[CallService] Cannot create call event message - call document no longer exists");
          return;
        }
      }
      
      if (data == null) {
        AppLogger.e("[CallService] Cannot create call event message - no call data available");
        return;
      }
      
      final callerId = data['callerId'] as String?;
      final calleeId = data['calleeId'] as String?;
      final callType = data['type'] as String? ?? 'audio';
      final duration = data['duration'] as int?;
      
      if (callerId == null || calleeId == null) {
        AppLogger.e("[CallService] Cannot create call event message - missing caller or callee ID even after refetch");
        return;
      }
      
      // Generate chat ID from caller and callee IDs
      List<String> participants = [callerId, calleeId];
      participants.sort(); // Ensure consistent chat ID generation
      final chatId = participants.join('_');
      
      // Construct appropriate message based on call status
      String messageContent;
      if (status == 'completed') {
        String durationText = 'Call ended';
        if (duration != null) {
          durationText = _formatCallDuration(duration);
        }
        messageContent = '$callType call | $durationText';
      } else if (status == 'missed' || status == 'no_answer') {
        messageContent = 'Missed $callType call';
      } else if (status == 'rejected') {
        messageContent = 'Declined $callType call';
      } else {
        messageContent = '$callType call ended';
      }
      
      // Get chat service and send system message
      final chatService = _ref.read(chatServiceProvider);
      await chatService.sendSystemMessage(
        chatId: chatId,
        content: messageContent,
        type: 'call_event',
        metadata: {
          'callId': callId,
          'callType': callType,
          'status': status,
          'duration': duration,
          'callerId': callerId,
          'calleeId': calleeId
        }
      );
      
      AppLogger.d("[CallService] Created call event message in chat $chatId for call $callId");
    } catch (e) {
      AppLogger.e("[CallService] Error creating call event message: $e");
    }
  }
  
  // Format call duration for display
  String _formatCallDuration(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    
    if (duration.inHours > 0) {
      return 'Call duration: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return 'Call duration: ${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return 'Call duration: ${duration.inSeconds}s';
    }
  }

  // Add ICE candidate for caller
  Future<void> addCallerIceCandidate(String callId, Map<String, dynamic> candidate) async {
    try {
      AppLogger.d("[CallService] Adding caller ICE candidate for call $callId");
      await _firestore
          .collection('calls')
          .doc(callId)
          .collection('callerCandidates')
          .add(candidate);
    } catch (e) {
      AppLogger.e("[CallService] Error adding caller ICE candidate: $e");
    }
  }

  // Add ICE candidate for callee
  Future<void> addCalleeIceCandidate(String callId, Map<String, dynamic> candidate) async {
    try {
      AppLogger.d("[CallService] Adding callee ICE candidate for call $callId");
      await _firestore
          .collection('calls')
          .doc(callId)
          .collection('calleeCandidates')
          .add(candidate);
    } catch (e) {
      AppLogger.e("[CallService] Error adding callee ICE candidate: $e");
    }
  }

  // Get call document stream
  Stream<DocumentSnapshot> getCallDocStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  // Get caller ICE candidates stream
  Stream<QuerySnapshot> getCallerCandidatesStream(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .collection('callerCandidates')
        .snapshots();
  }

  // Get callee ICE candidates stream
  Stream<QuerySnapshot> getCalleeCandidatesStream(String callId) {
    return _firestore
        .collection('calls')
        .doc(callId)
        .collection('calleeCandidates')
        .snapshots();
  }
}

// Provider for the CallService itself
final callServiceProvider = Provider<CallService>((ref) {
  final firestore = FirebaseFirestore.instance;
  return CallService(firestore, ref);
}); 

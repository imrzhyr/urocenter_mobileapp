import 'dart:async';
import 'package:urocenter/core/utils/logger.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod

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
  
  // Update call status (e.g., to end the call)
  Future<void> updateCallStatus(String callId, String status) async {
    try {
      AppLogger.d("[CallService] Updating call $callId status to $status");
      await _firestore.collection('calls').doc(callId).update({
        'status': status
      });
      AppLogger.d("[CallService] Call $callId status updated to $status");
    } catch (e) {
      AppLogger.e("[CallService] Error updating call $callId status: $e");
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

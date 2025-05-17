import 'dart:async';
import 'package:urocenter/core/utils/logger.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:urocenter/services/chat_service.dart'; // Import ChatService
import 'package:urocenter/providers/service_providers.dart'; // Import service_providers for chatServiceProvider
import 'package:urocenter/core/models/user_model.dart' as UserModel; // Import UserModel with namespace

// Data class to hold incoming call information
class IncomingCall {
  /// The ID of the call
  final String callId;
  
  /// The ID of the caller
  final String callerId;
  
  /// The name of the caller to display
  final String callerName;
  
  /// The type of call (audio/video)
  final String type;
  
  /// Constructor
  IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.type = 'audio', // Default to audio call
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
  // Track calls that are currently being processed to prevent duplicates
  final Set<String> _activeCallUpdates = {};
  final Set<String> _messageCreationInProgress = {};

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
        .listen((snapshot) async { // Make this callback async
      AppLogger.d("[CallService] Listener update for user $userId: ${snapshot.docs.length} ringing calls found");
      
      if (snapshot.docs.isNotEmpty) {
        // Usually, there should only be one active incoming call, take the first
        final callDoc = snapshot.docs.first;
        final callData = callDoc.data();
        
        AppLogger.d("[CallService] Processing incoming call data: $callData");
        
        // Make sure we get a valid caller name from the callData
        String callerName = callData['callerName'] ?? '';
        String callerId = callData['callerId'] ?? '';
        
        if (callerName.isEmpty && callerId.isNotEmpty) {
          // Try to get caller name from user profile using a proper way
          AppLogger.d("[CallService] Missing caller name, fetching from user profile for callerId: $callerId");
          try {
            // Get user doc directly for the caller
            final userDoc = await _firestore.collection('users').doc(callerId).get();
            
            if (userDoc.exists && userDoc.data() != null) {
              final userData = userDoc.data()!;
              
              // Try different possible name fields
              final name = userData['fullName'] ?? userData['name'] ?? userData['displayName'];
              
              if (name is String && name.isNotEmpty) {
                callerName = name;
                
                // Add "Dr." prefix for admin users if needed
                if (userData['isAdmin'] == true || userData['role'] == 'admin') {
                  // Always use Dr. Ali Kamal for admin users
                  callerName = "Dr. Ali Kamal";
                  AppLogger.d("[CallService] Using fixed admin name: Dr. Ali Kamal");
                }
                
                AppLogger.d("[CallService] Successfully retrieved caller name: $callerName");
                
                // Update the call document with the correct name
                await _firestore.collection('calls').doc(callDoc.id).update({
                  'callerName': callerName
                });
              }
            }
          } catch (e) {
            AppLogger.e("[CallService] Error fetching caller profile: $e");
          }
        }
        
        // If still empty after trying to fetch, use fallback
        if (callerName.isEmpty) {
          callerName = 'Unknown Caller';
          AppLogger.w("[CallService] Still missing caller name for call ${callDoc.id}, using fallback name.");
        }

        AppLogger.d("[CallService] Call from: $callerName (${callData['callerId']}), callData: ${callData.toString()}");

        final incomingCall = IncomingCall(
          callId: callDoc.id,
          callerId: callData['callerId'] ?? '',
          callerName: callerName,
          type: callData['type'] ?? 'audio',
        );
        
        // Update the global provider with the incoming call
        _ref.read(incomingCallProvider.notifier).setIncomingCall(incomingCall);
      } else {
        // No ringing calls, clear the incoming call if any
        _ref.read(incomingCallProvider.notifier).clearIncomingCall();
      }
    });
  }

  // Method to stop listening (e.g., on sign out)
  void stopListening() {
    AppLogger.d("[CallService] Stopping listener for incoming calls.");
    _callSubscription?.cancel();
    _callSubscription = null;
    // Clear state when stopping listener
    _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    // Clear tracking sets
    _activeCallUpdates.clear();
    _messageCreationInProgress.clear();
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
    // Guard against concurrent updates to the same call
    final operationKey = "$callId:$status";
    if (_activeCallUpdates.contains(operationKey)) {
      AppLogger.d("[CallService] Update already in progress for call $callId to status: $status - skipping duplicate");
      return;
    }
    
    try {
      _activeCallUpdates.add(operationKey);
      AppLogger.d("[CallService] Updating call $callId to status: $status");
      
      // Get the current call data
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) {
        AppLogger.e("[CallService] Call document $callId does not exist");
        return;
      }
      
      final callData = callDoc.data()!;
      final currentStatus = callData['status'] as String? ?? 'unknown';
      
      // Don't update if the status is already at the target (except for 'completed' which can override 'ended')
      if (currentStatus == status && !(currentStatus == 'ended' && status == 'completed')) {
        AppLogger.d("[CallService] Call $callId is already in status: $status - skipping update");
        return;
      }
      
      // Get call start time from document - try both startTime and startTimeLocal
      DateTime? startTime;
      
      // Try primary startTime first
      if (callData['startTime'] != null && callData['startTime'] is Timestamp) {
        startTime = (callData['startTime'] as Timestamp).toDate();
        AppLogger.d("[CallService] Using server startTime for call $callId");
      } 
      // Fall back to startTimeLocal if available
      else if (callData['startTimeLocal'] != null && callData['startTimeLocal'] is Timestamp) {
        startTime = (callData['startTimeLocal'] as Timestamp).toDate();
        AppLogger.d("[CallService] Using local startTime for call $callId");
      }
      // Fall back to createdAt if available
      else if (callData['createdAt'] != null) {
        if (callData['createdAt'] is Timestamp) {
          startTime = (callData['createdAt'] as Timestamp).toDate();
        } else if (callData['createdAt'] is DateTime) {
          startTime = callData['createdAt'] as DateTime;
        }
        AppLogger.d("[CallService] Using createdAt as startTime for call $callId");
      }
      
      // Current time for calculations
      final now = DateTime.now();
      
      // Initialize update data with new status
      Map<String, dynamic> updateData = {'status': status};
      
      // If there's no startTime, set it now to prevent issues with duration calculation
      if (startTime == null) {
        AppLogger.w("[CallService] Call $callId has no valid startTime, setting one now");
        final timestamp = Timestamp.fromDate(now);
        updateData['startTime'] = FieldValue.serverTimestamp();
        updateData['startTimeLocal'] = timestamp;
        // Use local time for immediate calculations in this function
        startTime = now;
      }
      
      // State transition logic
      switch (status) {
        // RINGING: Initial outgoing call state
        case 'ringing':
          // Nothing special needed beyond status update
          break;
          
        // ANSWERED: Call was accepted by the callee
        case 'answered':
          // If this is first transition to answered, record the answer time
          if (currentStatus != 'answered') {
            updateData['answerTime'] = FieldValue.serverTimestamp();
          }
          break;
          
        // COMPLETED: Call ended normally after being answered
        case 'completed':
          // Add end time
          updateData['endTime'] = FieldValue.serverTimestamp();
          
          // Calculate duration if we have a valid start time
          if (startTime != null) {
            final duration = now.difference(startTime).inSeconds;
            updateData['duration'] = duration;
            AppLogger.d("[CallService] Call $callId completed with duration: $duration seconds");
          } else {
            // Fallback if startTime is missing
            updateData['duration'] = 0;
            AppLogger.w("[CallService] Call $callId completed but missing startTime");
          }
          break;
          
        // ENDED: Generic call end (might be hung up before being answered)
        case 'ended':
          // Add end time
          updateData['endTime'] = FieldValue.serverTimestamp();
          
          // If call was previously answered, mark as completed instead
          if (currentStatus == 'answered') {
            updateData['status'] = 'completed';
            AppLogger.d("[CallService] Converting 'ended' to 'completed' for answered call $callId");
            
            // Calculate duration from start time
            if (startTime != null) {
              final duration = now.difference(startTime).inSeconds;
              updateData['duration'] = duration;
              AppLogger.d("[CallService] Call $callId ended with duration: $duration seconds");
            } else {
              updateData['duration'] = 0;
            }
          } else {
            // For unanswered calls that ended, set a zero duration
            updateData['duration'] = 0;
          }
          break;
          
        // REJECTED: Call was explicitly declined by recipient
        case 'rejected':
          // Add end time and zero duration
          updateData['endTime'] = FieldValue.serverTimestamp();
          updateData['duration'] = 0;
          break;
          
        // MISSED: Call was not answered (timed out)
        case 'missed':
        case 'no_answer':
          // Add end time and zero duration
          updateData['endTime'] = FieldValue.serverTimestamp();
          updateData['duration'] = 0;
          break;
          
        // DEFAULT: Handle other status values
        default:
          AppLogger.w("[CallService] Unhandled call status update: $status");
          // If ending the call with any other status, add end time
          if (status.contains('end') || status.contains('fail')) {
            updateData['endTime'] = FieldValue.serverTimestamp();
            
            // Calculate duration if appropriate
            if (startTime != null && (currentStatus == 'answered' || currentStatus == 'connected')) {
              final duration = now.difference(startTime).inSeconds;
              updateData['duration'] = duration;
            } else {
              updateData['duration'] = 0;
            }
          }
      }
      
      // Update the call document
      await _firestore.collection('calls').doc(callId).update(updateData);
      AppLogger.d("[CallService] Call $callId updated with data: $updateData");
      
      // Create a chat message for completed, rejected, or missed calls
      final finalStatus = updateData['status'] ?? status;
      if (finalStatus == 'completed' || finalStatus == 'rejected' || 
          finalStatus == 'missed' || finalStatus == 'no_answer' || 
          finalStatus == 'ended') {
        await _createCallEventMessage(callId, finalStatus, callData);
      }
    } catch (e) {
      AppLogger.e("[CallService] Error updating call status: $e");
    } finally {
      // Always remove from active operations set when done
      _activeCallUpdates.remove(operationKey);
    }
  }
  
  // Create a message in chat for a call event
  Future<void> _createCallEventMessage(String callId, String status, Map<String, dynamic>? callData) async {
    // Guard against concurrent message creation for the same call
    if (_messageCreationInProgress.contains(callId)) {
      AppLogger.d("[CallService] Message creation already in progress for call $callId - skipping duplicate");
      return;
    }
    
    try {
      _messageCreationInProgress.add(callId);
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
      final callerName = data['callerName'] as String? ?? 'Unknown Caller';
      final calleeName = data['calleeName'] as String? ?? 'Unknown Recipient';
      final callType = data['type'] as String? ?? 'audio';
      final duration = data['duration'] as int?;
      final startTime = data['startTime'] as Timestamp?;
      final endTime = data['endTime'] as Timestamp?;
      
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
      } else if (status == 'ended') {
        // For 'ended' calls, also show duration if available
        String durationText = 'Call ended';
        if (duration != null && duration > 0) {
          durationText = _formatCallDuration(duration);
          messageContent = '$callType call | $durationText';
        } else {
          messageContent = '$callType call ended';
        }
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
          'calleeId': calleeId,
          'callerName': callerName,
          'calleeName': calleeName,
          'startTime': startTime?.millisecondsSinceEpoch,
          'endTime': endTime?.millisecondsSinceEpoch,
        }
      );
      
      AppLogger.d("[CallService] Created call event message in chat $chatId for call $callId");
    } catch (e) {
      AppLogger.e("[CallService] Error creating call event message: $e");
    } finally {
      // Always remove from in-progress set when done
      _messageCreationInProgress.remove(callId);
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
  
  // Get Agora token from Firestore or server
  Future<String?> getAgoraToken(String channelName) async {
    try {
      AppLogger.d("[CallService] Getting Agora token for channel: $channelName");
      
      // Check if there's a token in Firestore first
      final tokenDoc = await _firestore
          .collection('agora_tokens')
          .doc(channelName)
          .get();
      
      if (tokenDoc.exists && tokenDoc.data() != null) {
        final tokenData = tokenDoc.data()!;
        final token = tokenData['token'] as String?;
        
        if (token != null && token.isNotEmpty) {
          AppLogger.d("[CallService] Found existing Agora token for channel");
          return token;
        }
      }
      
      // If no token in Firestore, try to get it from your token server
      // This is where you would typically make an API call to your token service
      // For example:
      // final response = await http.get(Uri.parse('https://your-token-server.com/token?channelName=$channelName'));
      // if (response.statusCode == 200) {
      //   final data = jsonDecode(response.body);
      //   return data['token'];
      // }
      
      // For development without a token server - use null which will fall back to empty string
      AppLogger.w("[CallService] No token found or token server available for channel: $channelName");
      return null;
      
    } catch (e) {
      AppLogger.e("[CallService] Error getting Agora token: $e");
      return null;
    }
  }

  /// Start a new audio call and return the call ID.
  Future<String?> startAudioCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
  }) async {
    try {
      AppLogger.d("[CallService] Starting audio call from $callerId ($callerName) to $calleeId ($calleeName)");
      
      // Validate inputs to prevent issues
      if (callerId.isEmpty || calleeId.isEmpty) {
        AppLogger.e("[CallService] Cannot start call with empty caller or callee ID");
        return null;
      }
      
      // Create a new call document in Firestore
      final callDoc = _firestore.collection('calls').doc();
      final callId = callDoc.id;
      
      // Current timestamp for call start
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      
      // Call data with explicit startTime (both as Timestamp and server timestamp)
      final callData = {
        'callerId': callerId,
        'callerName': callerName,
        'calleeId': calleeId,
        'calleeName': calleeName,
        'type': 'audio', // Always audio for now
        'status': 'pending', // Initial status
        'startTime': FieldValue.serverTimestamp(), // Server timestamp for consistency
        'startTimeLocal': timestamp, // Explicit timestamp as backup for duration calculations
        'createdAt': now, // Local timestamp for immediate use
        'platform': 'mobile', // Add platform information
        'offer': null, // Will be set later by WebRTC if needed
        'duration': 0, // Initialize duration to 0
      };
      
      // Write to Firestore
      await callDoc.set(callData);
      AppLogger.d("[CallService] Call document created with ID: $callId");
      
      // Update status to ringing after creation
      await updateCallStatus(callId, 'ringing');
      
      // Return the call ID
      return callId;
    } catch (e) {
      AppLogger.e("[CallService] Error starting audio call: $e");
      return null;
    }
  }
}

// Provider for the CallService itself
final callServiceProvider = Provider<CallService>((ref) {
  final firestore = FirebaseFirestore.instance;
  return CallService(firestore, ref);
}); 

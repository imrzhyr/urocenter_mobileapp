import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'package:urocenter/providers/service_providers.dart';

// Data class to hold incoming call information
class IncomingCall {
  final String callId;
  final String callerId;
  final String callerName;
  final String type;
  
  IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.type = 'audio',
  });
}

// StateNotifier for managing incoming call state
class IncomingCallNotifier extends StateNotifier<IncomingCall?> {
  IncomingCallNotifier() : super(null);
  
  void setIncomingCall(IncomingCall? call) => state = call;
  void clearIncomingCall() => state = null;
}

// Provider for the IncomingCallNotifier
final incomingCallProvider = StateNotifierProvider<IncomingCallNotifier, IncomingCall?>((ref) {
  return IncomingCallNotifier();
});

class CallService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  // Track active operations to prevent duplicates
  final Set<String> _activeCallUpdates = {};
  final Set<String> _messageCreationInProgress = {};
  
  // Call subscription
  StreamSubscription? _callSubscription;

  CallService(this._firestore, this._ref);

  // Method to get the current status of a call from Firestore
  Future<String?> getCallStatus(String callId) async {
    try {
      final doc = await _firestore.collection('calls').doc(callId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['status'] as String?;
      }
      return null; // Call document doesn't exist or has no data
    } catch (e) {
      AppLogger.e("[CallService] Error getting call status for $callId: $e");
      return null; // Return null on error
    }
  }

  // Listen for incoming calls for a specific user
  void listenForIncomingCalls(String userId) {
    AppLogger.d("[CallService] Starting listener for incoming calls for user: $userId");
    
    // Cancel any previous subscription
    _callSubscription?.cancel();

    _callSubscription = _firestore.collection('calls')
      .where('calleeId', isEqualTo: userId)
      .where('status', isEqualTo: 'ringing')
      .snapshots()
      .listen((snapshot) async {
        // Process call documents that are ringing
        if (snapshot.docs.isNotEmpty) {
          final callDoc = snapshot.docs.first;
          final callData = callDoc.data();
          
          // Skip if call data is invalid
          if (callData['callerId'] == null) {
            AppLogger.callWarning("[CallService] Invalid call document found: ${callDoc.id}, missing callerId");
            return;
          }
          
          // Extract data from the call document
          String callerName = callData['callerName'] ?? '';
          final callerId = callData['callerId'] as String;
          
          // If caller name not set, fetch it from the users collection
          if (callerName.isEmpty) {
            try {
              final userDoc = await _firestore.collection('users').doc(callerId).get();
              
              if (userDoc.exists && userDoc.data() != null) {
                final userData = userDoc.data()!;
                
                // Try different name fields
                final name = userData['fullName'] ?? userData['name'] ?? userData['displayName'];
                
                if (name is String && name.isNotEmpty) {
                  callerName = name;
                  
                  // Add "Dr." prefix for admin users
                  if (userData['isAdmin'] == true || userData['role'] == 'admin') {
                    callerName = "Dr. Ali Kamal";
                  }
                  
                  // Update the call document with correct name
                  await _firestore.collection('calls').doc(callDoc.id).update({
                    'callerName': callerName
                  });
                }
              }
            } catch (e) {
              AppLogger.e("[CallService] Error fetching caller profile: $e");
            }
          }
          
          // Use fallback name if still empty
          if (callerName.isEmpty) {
            callerName = 'Unknown Caller';
          }

          // Create and set incoming call
          final incomingCall = IncomingCall(
            callId: callDoc.id,
            callerId: callerId,
            callerName: callerName,
            type: callData['type'] ?? 'audio',
          );
          
          _ref.read(incomingCallProvider.notifier).setIncomingCall(incomingCall);
        } else {
          // No ringing calls, clear the incoming call
          _ref.read(incomingCallProvider.notifier).clearIncomingCall();
        }
      });
  }

  // Stop listening for incoming calls
  void stopListening() {
    AppLogger.d("[CallService] Stopping listener for incoming calls");
    _callSubscription?.cancel();
    _callSubscription = null;
    _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    _activeCallUpdates.clear();
    _messageCreationInProgress.clear();
  }

  // Accept a call with SDP answer (for WebRTC implementation)
  Future<void> acceptCall(String callId, Map<String, dynamic> sdpAnswerMap) async {
    try {
      AppLogger.d("[CallService] Accepting call: $callId");
      await _firestore.collection('calls').doc(callId).update({
        'status': 'answered',
        'answer': sdpAnswerMap,
      });
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    } catch (e) {
      AppLogger.e("[CallService] Error accepting call $callId: $e");
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    }
  }

  // Update call status and handle duration calculation
  Future<void> updateCallStatus(String callId, String status) async {
    final operationKey = "$callId-$status";
    
    // Skip if already processing this update
    if (_activeCallUpdates.contains(operationKey)) {
      AppLogger.d("[CallService] Update for call $callId to status $status already in progress - skipping duplicate");
      return;
    }
    
    try {
      _activeCallUpdates.add(operationKey);
      AppLogger.d("[CallService] Updating call $callId to status: $status");
      
      // Get current call document
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) {
        AppLogger.e("[CallService] Call document $callId does not exist");
        return;
      }
      
      final callData = callDoc.data()!;
      final currentStatus = callData['status'] as String? ?? 'unknown';
      
      // If we already have a 'completed' status, don't downgrade to 'ended'
      if (currentStatus == 'completed' && status == 'ended') {
        AppLogger.d("[CallService] Not downgrading status from 'completed' to 'ended' for call $callId");
        return;
      }
      
      // Special case for ringing calls that end - mark as missed instead
      if (currentStatus == 'ringing' && status == 'ended') {
        AppLogger.d("[CallService] Converting 'ended' to 'missed' for ringing call $callId");
        status = 'missed';
      }
      
      // Don't update if status is already set (except for completed which can override ended)
      if (currentStatus == status && !(currentStatus == 'ended' && status == 'completed')) {
        AppLogger.d("[CallService] Call $callId is already in status: $status - skipping update");
        return;
      }
      
      // Get call start time - single consistent approach
      DateTime? startTime;
      
      // Try primary startTime first, then fallbacks
      if (callData['startTime'] != null && callData['startTime'] is Timestamp) {
        startTime = (callData['startTime'] as Timestamp).toDate();
      } else if (callData['startTimeLocal'] != null && callData['startTimeLocal'] is Timestamp) {
        startTime = (callData['startTimeLocal'] as Timestamp).toDate();
      } else if (callData['createdAt'] != null) {
        if (callData['createdAt'] is Timestamp) {
          startTime = (callData['createdAt'] as Timestamp).toDate();
        } else if (callData['createdAt'] is DateTime) {
          startTime = callData['createdAt'] as DateTime;
        }
      }
      
      // Current time for calculations
      final now = DateTime.now();
      
      // Update data with new status
      final updateData = <String, dynamic>{
        'status': status,
      };
      
      // State transition logic based on status
      switch (status) {
        case 'ringing':
          // Nothing special needed beyond status update
          break;
          
        case 'answered':
          // If this is first transition to answered, record the answer time
          if (currentStatus != 'answered') {
            updateData['answerTime'] = FieldValue.serverTimestamp();
            // Store a local answer time for immediate duration calculations
            final answerTimestamp = Timestamp.fromDate(now);
            updateData['answerTimeLocal'] = answerTimestamp;
          }
          break;
          
        case 'completed':
          // Add end time
          updateData['endTime'] = FieldValue.serverTimestamp();
          final endTimestamp = Timestamp.fromDate(now);
          updateData['endTimeLocal'] = endTimestamp;
          
          // Calculate duration correctly using answer time if available
          DateTime? answerTime;
          if (callData['answerTimeLocal'] != null && callData['answerTimeLocal'] is Timestamp) {
            answerTime = (callData['answerTimeLocal'] as Timestamp).toDate();
            AppLogger.d("[CallService] Using answerTimeLocal for duration calculation");
          } else if (callData['answerTime'] != null && callData['answerTime'] is Timestamp) {
            answerTime = (callData['answerTime'] as Timestamp).toDate();
            AppLogger.d("[CallService] Using answerTime for duration calculation");
          }
          
          // Use answer time for duration calculation if available
          if (answerTime != null) {
            final duration = now.difference(answerTime).inSeconds;
            // Ensure duration is at least 1 second if the call was connected
            updateData['duration'] = duration > 0 ? duration : 1;
            AppLogger.d("[CallService] Call $callId completed with duration: ${updateData['duration']} seconds (using answer time)");
          } else if (startTime != null) {
            // Fall back to start time if answer time not available
            final duration = now.difference(startTime).inSeconds;
            // Ensure duration is at least 1 second if the call was connected
            updateData['duration'] = duration > 0 ? duration : 1;
            AppLogger.d("[CallService] Call $callId completed with duration: ${updateData['duration']} seconds (using start time)");
          } else {
            // Fallback if startTime is missing - use 1 second minimum
            updateData['duration'] = 1;
            AppLogger.callWarning("[CallService] Call $callId completed but missing time references");
          }
          break;
          
        case 'ended':
          // Add end time
          updateData['endTime'] = FieldValue.serverTimestamp();
          final endTimestamp = Timestamp.fromDate(now);
          updateData['endTimeLocal'] = endTimestamp;
          
          // If call was previously answered, mark as completed instead
          if (currentStatus == 'answered') {
            updateData['status'] = 'completed';
            AppLogger.d("[CallService] Converting 'ended' to 'completed' for answered call $callId");
            
            // Calculate duration using answer time if available
            DateTime? answerTime;
            if (callData['answerTimeLocal'] != null && callData['answerTimeLocal'] is Timestamp) {
              answerTime = (callData['answerTimeLocal'] as Timestamp).toDate();
            } else if (callData['answerTime'] != null && callData['answerTime'] is Timestamp) {
              answerTime = (callData['answerTime'] as Timestamp).toDate();
            }
            
            if (answerTime != null) {
              final duration = now.difference(answerTime).inSeconds;
              // Ensure duration is at least 1 second if the call was connected
              updateData['duration'] = duration > 0 ? duration : 1;
              AppLogger.d("[CallService] Call $callId ended with duration: ${updateData['duration']} seconds (using answer time)");
            } else if (startTime != null) {
              // Fall back to start time if answer time not available
              final duration = now.difference(startTime).inSeconds;
              // Ensure duration is at least 1 second if the call was connected
              updateData['duration'] = duration > 0 ? duration : 1;
              AppLogger.d("[CallService] Call $callId ended with duration: ${updateData['duration']} seconds (using start time)");
            } else {
              // Fallback if startTime is missing - use 1 second minimum
              updateData['duration'] = 1;
              AppLogger.callWarning("[CallService] Call $callId ended but missing time references");
            }
          } else {
            // For unanswered calls that ended, set a zero duration
            updateData['duration'] = 0;
          }
          break;
          
        case 'rejected':
        case 'missed':
        case 'no_answer':
          // Add end time and zero duration
          updateData['endTime'] = FieldValue.serverTimestamp();
          updateData['duration'] = 0;
          break;
          
        default:
          // Handle other status values
          AppLogger.callWarning("[CallService] Unhandled call status update: $status");
          // If ending the call with any other status, add end time
          if (status.contains('end') || status.contains('fail')) {
            updateData['endTime'] = FieldValue.serverTimestamp();
            
            // Calculate duration if appropriate
            if (startTime != null && (currentStatus == 'answered' || currentStatus == 'connected')) {
              final duration = now.difference(startTime).inSeconds;
              // Ensure duration is at least 1 second if the call was connected
              updateData['duration'] = duration > 0 ? duration : 1;
            } else {
              updateData['duration'] = 0;
            }
          }
      }
      
      // Update document with new status and duration if available
      await _firestore.collection('calls').doc(callId).update(updateData);
      
      // Update call data with our new values for message creation
      Map<String, dynamic> updatedCallData = Map<String, dynamic>.from(callData);
      updateData.forEach((key, value) {
        if (value is! FieldValue) { // Don't try to copy server timestamps
          updatedCallData[key] = value;
        }
      });
      
      // Create system message in chat for the call event
      await _createCallEventMessage(callId, updateData['status'] as String? ?? status, updatedCallData);
      
    } catch (e) {
      AppLogger.e("[CallService] Error updating call status: $e");
    } finally {
      _activeCallUpdates.remove(operationKey);
    }
  }

  // Create system message in chat for call events
  Future<void> _createCallEventMessage(String callId, String status, Map<String, dynamic> callData) async {
    // Guard against concurrent message creation
    if (_messageCreationInProgress.contains(callId)) {
      AppLogger.d("[CallService] Message creation already in progress for call $callId - skipping duplicate");
      return;
    }

    // Skip 'ended' status messages completely - only show completed and missed/rejected
    if (status == 'ended') {
      AppLogger.d("[CallService] Skipping 'ended' message creation - only showing completed and missed calls");
      return;
    }

    // Only create messages for completed, missed, or rejected calls
    final isFinalStatus = status == 'completed' || status == 'missed' || status == 'rejected' || status == 'no_answer';
    if (!isFinalStatus) {
      AppLogger.d("[CallService] Skipping message creation for non-final status: $status");
      return;
    }

    // Additional guard to prevent creating too many call event messages in rapid succession
    final lastMessageKey = "last_message_$callId";
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastMessageTime = callData[lastMessageKey] as int? ?? 0;
    final timeSinceLastMessage = now - lastMessageTime;
    
    if (timeSinceLastMessage < 2000) {
      AppLogger.d("[CallService] Suppressing rapid message creation for call $callId - last message was only ${timeSinceLastMessage}ms ago");
      return;
    }
    
    try {
      _messageCreationInProgress.add(callId);
      
      // Get fresh call data if needed
      Map<String, dynamic> data = callData;
      if (data['callerId'] == null || data['calleeId'] == null) {
        final callDoc = await _firestore.collection('calls').doc(callId).get();
        if (callDoc.exists) {
          data = callDoc.data()!;
        } else {
          AppLogger.e("[CallService] Cannot create call event message - call document no longer exists");
          return;
        }
      }
      
      // Extract call information
      final callerId = data['callerId'] as String?;
      final calleeId = data['calleeId'] as String?;
      
      if (callerId == null || calleeId == null) {
        AppLogger.e("[CallService] Cannot create call event message - missing caller or callee ID");
        return;
      }
      
      final callerName = data['callerName'] as String? ?? 'Unknown Caller';
      final calleeName = data['calleeName'] as String? ?? 'Unknown Recipient';
      final callType = data['type'] as String? ?? 'audio';
      int? duration = data['duration'] as int?;
      final startTime = data['startTime'] as Timestamp?;
      final endTime = data['endTime'] as Timestamp?;
      
      // Special handling for duration on connected calls
      if ((status == 'completed' || (status == 'ended' && data['answerTime'] != null)) && 
          (duration == null || duration == 0)) {
        // If this was an answered call, make sure it has at least 1 second duration
        duration = 1;
        AppLogger.d("[CallService] Setting minimum duration of 1s for connected call $callId");
      }
      
      // NEVER create 'ended' messages for calls that were ever connected
      if (status == 'ended') {
          // Check if there was an answer time (call was connected)
          final wasConnected = data['answerTime'] != null || data['answerTimeLocal'] != null || (duration != null && duration > 0);
          if (wasConnected) {
              AppLogger.d("[CallService] Skipping 'ended' message creation for call that was connected");
              return; // Skip creating any message
          }
      }
      
      // Check for very recent messages about the same call and status
      final chatId = _generateChatId(callerId, calleeId);
      
      // Do a more thorough check for existing call messages (even older ones)
      final existingMessages = await _firestore.collection('chats').doc(chatId).collection('messages')
        .where('type', isEqualTo: 'call_event')
        .where('metadata.callId', isEqualTo: callId)
        .orderBy('createdAt', descending: true)
        .limit(3)
        .get();
      
      // If this call has any 'completed' messages already, don't create an 'ended' message
      if (status == 'ended' && existingMessages.docs.isNotEmpty) {
        for (final doc in existingMessages.docs) {
          final msgData = doc.data();
          if (msgData['metadata'] != null && 
              (msgData['metadata']['status'] == 'completed' || 
               (msgData['metadata']['duration'] != null && msgData['metadata']['duration'] > 0))) {
            AppLogger.d("[CallService] Found existing completed message for call $callId - skipping 'ended' message");
            return; // Skip creating message
          }
        }
      }
      
      // Also check for very recent messages (to avoid rapid duplicate messages)
      final recentMessages = await _checkForRecentCallMessage(chatId, callId, status);
      if (recentMessages.isNotEmpty) {
        // Only update the existing message if duration increased
        final recentMessage = recentMessages.first;
        final recentData = recentMessage.data() as Map<String, dynamic>?;
        
        // Safely access metadata with null checks
        final metadata = recentData != null ? recentData['metadata'] as Map<String, dynamic>? : null;
        final oldDuration = metadata != null ? metadata['duration'] as int? ?? 0 : 0;
        
        if (duration != null && duration > oldDuration && (status == 'completed' || status == 'ended')) {
          // Update the existing message with new duration
          await _firestore.collection('chats').doc(chatId).collection('messages').doc(recentMessage.id).update({
            'metadata.duration': duration,
            'metadata.endTime': endTime?.millisecondsSinceEpoch,
          });
          
          AppLogger.d("[CallService] Updated existing call message ${recentMessage.id} with new duration: $duration seconds");
          return; // Skip creating new message
        } else if (!isFinalStatus) {
          // Don't create duplicate message for non-final status
          AppLogger.d("[CallService] Found recent message about call $callId with status $status - skipping duplicate");
          return;
        }
      }
      
      // Generate chat ID
      List<String> participants = [callerId, calleeId];
      participants.sort(); // Ensure consistent chat ID generation
      
      // Construct message content based on call status
      String messageContent;
      if (status == 'completed') {
        // Always show duration for completed calls
        if (duration != null && duration > 0) {
          String durationText = _formatCallDuration(duration);
          messageContent = '$callType call | $durationText';
        } else {
          // Use minimum 1 second for completed calls
          messageContent = '$callType call | Call duration: 1s';
          duration = 1; // Ensure minimum duration
        }
      } else if (status == 'missed' || status == 'no_answer') {
        messageContent = 'Missed $callType call';
        AppLogger.d("[CallService] Creating missed call message: $messageContent for call $callId");
      } else if (status == 'rejected') {
        messageContent = 'Declined $callType call';
      } else {
        // This should never be reached due to the early returns above,
        // but just in case, default to a completed call with 1s
        AppLogger.d("[CallService] Using fallback message content for unexpected status: $status");
        messageContent = '$callType call | Call duration: 1s';
        duration = 1;
      }
      
      // Send system message
      final chatService = _ref.read(chatServiceProvider);
      await chatService.sendSystemMessage(
        chatId: chatId,
        content: messageContent,
        type: 'call_event',
        metadata: {
          'callId': callId,
          'callType': callType,
          'status': status,
          'duration': duration ?? 0, // Ensure duration is never null in metadata
          'callerId': callerId,
          'calleeId': calleeId,
          'callerName': callerName,
          'calleeName': calleeName,
          'startTime': startTime?.millisecondsSinceEpoch,
          'endTime': endTime?.millisecondsSinceEpoch,
          'messageCreatedAt': now, // Track when this message was created
        }
      );
      
      // Update the timestamp in call data to prevent rapid message creation
      await _firestore.collection('calls').doc(callId).update({
        lastMessageKey: now,
      });
      
      AppLogger.d("[CallService] Created call event message in chat $chatId for call $callId with status $status");
    } catch (e) {
      AppLogger.e("[CallService] Error creating call event message: $e");
    } finally {
      _messageCreationInProgress.remove(callId);
    }
  }
  
  // Helper to check for recent call messages to avoid duplicates
  Future<List<DocumentSnapshot>> _checkForRecentCallMessage(String chatId, String callId, String status) async {
    try {
      // Look for messages from the last minute about the same call
      final lastMinute = DateTime.now().subtract(const Duration(minutes: 1));
      final lastMinuteTimestamp = Timestamp.fromDate(lastMinute);
      
      final query = await _firestore.collection('chats').doc(chatId).collection('messages')
        .where('type', isEqualTo: 'call_event')
        .where('metadata.callId', isEqualTo: callId)
        .where('createdAt', isGreaterThan: lastMinuteTimestamp)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        
      return query.docs;
    } catch (e) {
      AppLogger.e("[CallService] Error checking for recent call messages: $e");
      return [];
    }
  }
  
  // Generate chat ID consistently
  String _generateChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort(); // Sort to ensure consistent order
    return ids.join('_');
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

  // Mark a call as missed (when caller hangs up before callee answers)
  Future<void> markCallAsMissed(String callId) async {
    try {
      AppLogger.d("[CallService] Marking call as missed: $callId");
      await updateCallStatus(callId, 'missed');
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    } catch (e) {
      AppLogger.e("[CallService] Error marking call as missed $callId: $e");
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    }
  }

  // Reject an incoming call
  Future<void> rejectCall(String callId) async {
    try {
      AppLogger.d("[CallService] Rejecting call: $callId");
      await updateCallStatus(callId, 'rejected');
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    } catch (e) {
      AppLogger.e("[CallService] Error rejecting call $callId: $e");
      _ref.read(incomingCallProvider.notifier).clearIncomingCall();
    }
  }

  // Get Agora token for joining a call channel
  Future<String?> getAgoraToken(String channelName) async {
    try {
      // Example token generation - in production this would likely call a secure API
      // For development, can return null to use tokenless mode if enabled in Agora console
      return null;
    } catch (e) {
      AppLogger.e("[CallService] Error getting Agora token: $e");
      return null;
    }
  }

  // Get call document stream
  Stream<DocumentSnapshot> getCallDocStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  // Start a new audio call
  Future<String?> startAudioCall({
    required String callerId,
    required String callerName,
    required String calleeId,
    required String calleeName,
  }) async {
    try {
      AppLogger.d("[CallService] Starting audio call from $callerId ($callerName) to $calleeId ($calleeName)");
      
      // Validate inputs
      if (callerId.isEmpty || calleeId.isEmpty) {
        AppLogger.e("[CallService] Cannot start call with empty caller or callee ID");
        return null;
      }
      
      // Create call document
      final callDoc = _firestore.collection('calls').doc();
      final callId = callDoc.id;
      
      // Current timestamp for call start
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      
      // Call data with consistent timestamps
      final callData = {
        'callerId': callerId,
        'callerName': callerName,
        'calleeId': calleeId,
        'calleeName': calleeName,
        'type': 'audio',
        'status': 'pending',
        'startTime': FieldValue.serverTimestamp(),
        'startTimeLocal': timestamp,
        'createdAt': timestamp,
        'platform': 'mobile',
        'duration': 0,
      };
      
      // Create call document
      await callDoc.set(callData);
      AppLogger.d("[CallService] Call document created with ID: $callId");
      
      // Update status to ringing
      await updateCallStatus(callId, 'ringing');
      
      return callId;
    } catch (e) {
      AppLogger.e("[CallService] Error starting audio call: $e");
      return null;
    }
  }
}

// Provider for the CallService
final callServiceProvider = Provider<CallService>((ref) {
  final firestore = FirebaseFirestore.instance;
  return CallService(firestore, ref);
}); 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'dart:async';

/// Provider for call history data
/// Returns a list of calls with caller/callee details, timestamps and status information
final callHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  AppLogger.d('[CallHistoryProvider] Initializing call history for user: $currentUserId');
  
  if (currentUserId == null) {
    // Return empty list if no user is logged in
    AppLogger.w('[CallHistoryProvider] No current user, returning empty call history');
    return Stream.value([]);
  }

  // Use a single stream as the primary source, but periodically merge in both outgoing and incoming calls
  final controller = StreamController<List<Map<String, dynamic>>>();
  
  // Function to fetch and merge all calls
  Future<void> fetchAndMergeCalls() async {
    try {
      // Get outgoing calls
      final outgoingSnapshot = await FirebaseFirestore.instance
          .collection('calls')
          .where('callerId', isEqualTo: currentUserId)
          .orderBy('startTime', descending: true)
          .limit(30)
          .get();
      
      // Get incoming calls
      final incomingSnapshot = await FirebaseFirestore.instance
          .collection('calls')
          .where('calleeId', isEqualTo: currentUserId)
          .orderBy('startTime', descending: true)
          .limit(30)
          .get();
      
      AppLogger.d('[CallHistoryProvider] Fetched ${outgoingSnapshot.docs.length} outgoing and ${incomingSnapshot.docs.length} incoming calls');
      
      final List<Map<String, dynamic>> callList = [];
      final Set<String> processedIds = {}; // To avoid duplicates
      
      // Process outgoing calls
      for (final doc in outgoingSnapshot.docs) {
        if (processedIds.contains(doc.id)) continue;
        processedIds.add(doc.id);
        
        final data = doc.data();
        if (data['callerId'] == null || data['calleeId'] == null) {
          AppLogger.w('[CallHistoryProvider] Skipping outgoing call ${doc.id} - missing caller/callee ID');
          continue;
        }
        
        callList.add(_processCallData(doc.id, data));
      }
      
      // Process incoming calls
      for (final doc in incomingSnapshot.docs) {
        if (processedIds.contains(doc.id)) continue;
        processedIds.add(doc.id);
        
        final data = doc.data();
        if (data['callerId'] == null || data['calleeId'] == null) {
          AppLogger.w('[CallHistoryProvider] Skipping incoming call ${doc.id} - missing caller/callee ID');
          continue;
        }
        
        callList.add(_processCallData(doc.id, data));
      }
      
      // Sort by start time (newest first)
      callList.sort((a, b) => (b['startTime'] as DateTime).compareTo(a['startTime'] as DateTime));
      
      AppLogger.d('[CallHistoryProvider] Processed ${callList.length} valid calls');
      if (callList.isNotEmpty) {
        AppLogger.d('[CallHistoryProvider] Sample call: ${callList.first}');
      }
      
      // Add to stream if controller is still active
      if (!controller.isClosed) {
        controller.add(callList);
      }
    } catch (e) {
      AppLogger.e('[CallHistoryProvider] Error fetching calls: $e');
      if (!controller.isClosed) {
        // Add empty list on error to avoid breaking the UI
        controller.add([]);
      }
    }
  }
  
  // Initial fetch
  fetchAndMergeCalls();
  
  // Set up listeners for both collections to trigger refreshes
  final outgoingListener = FirebaseFirestore.instance
      .collection('calls')
      .where('callerId', isEqualTo: currentUserId)
      .orderBy('startTime', descending: true)
      .limit(1) // Just listen for changes, not the full data
      .snapshots()
      .listen((_) {
        AppLogger.d('[CallHistoryProvider] Outgoing calls changed, refreshing data');
        fetchAndMergeCalls();
      });
      
  final incomingListener = FirebaseFirestore.instance
      .collection('calls')
      .where('calleeId', isEqualTo: currentUserId)
      .orderBy('startTime', descending: true)
      .limit(1) // Just listen for changes, not the full data
      .snapshots()
      .listen((_) {
        AppLogger.d('[CallHistoryProvider] Incoming calls changed, refreshing data');
        fetchAndMergeCalls();
      });
  
  // Clean up on dispose
  ref.onDispose(() {
    AppLogger.d('[CallHistoryProvider] Disposing call history provider');
    outgoingListener.cancel();
    incomingListener.cancel();
    controller.close();
  });
  
  return controller.stream;
});

// Helper function to process call data
Map<String, dynamic> _processCallData(String docId, Map<String, dynamic> data) {
  // Convert Timestamp to DateTime with fallbacks
  DateTime? startTime;
  
  // Try different timestamp fields with fallbacks
  if (data['startTime'] != null && data['startTime'] is Timestamp) {
    startTime = (data['startTime'] as Timestamp).toDate();
  } 
  else if (data['startTimeLocal'] != null && data['startTimeLocal'] is Timestamp) {
    startTime = (data['startTimeLocal'] as Timestamp).toDate();
  }
  else if (data['createdAt'] != null) {
    if (data['createdAt'] is Timestamp) {
      startTime = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is DateTime) {
      startTime = data['createdAt'] as DateTime;
    }
  }
  
  // Always provide a valid start time (fallback to current time if all else fails)
  if (startTime == null) {
    startTime = DateTime.now();
    AppLogger.w('[CallHistoryProvider] Call $docId has no valid start time, using current time');
  }
  
  // Convert end time if available
  DateTime? endTime;
  if (data['endTime'] != null) {
    if (data['endTime'] is Timestamp) {
      endTime = (data['endTime'] as Timestamp).toDate();
    }
  }
  
  // Ensure duration is valid
  int duration = 0;
  if (data['duration'] != null && data['duration'] is int) {
    duration = data['duration'] as int;
  } else if (startTime != null && endTime != null) {
    // Calculate duration from timestamps if not provided
    duration = endTime.difference(startTime).inSeconds;
    if (duration < 0) duration = 0; // Ensure no negative durations
  }
  
  // For debugging
  AppLogger.d('[CallHistoryProvider] Processing call $docId: status=${data['status']}, duration=$duration');
  
  return {
    'id': docId,
    'callerId': data['callerId'] as String,
    'callerName': data['callerName'] ?? 'Unknown Caller',
    'calleeId': data['calleeId'] as String,
    'calleeName': data['calleeName'] ?? 'Unknown User',
    'status': data['status'] ?? 'unknown',
    'type': data['type'] ?? 'audio', // 'audio' or 'video'
    'startTime': startTime,
    'endTime': endTime,
    'duration': duration,
  };
}

/// Provider for call statistics - total calls, completed calls, etc.
final callStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return {
        'totalCalls': 0,
        'completedCalls': 0,
        'missedCalls': 0,
        'totalDuration': 0,
        'avgDuration': 0,
        'completionRate': 0.0,
      };
    }
    
    // Get outgoing calls
    final outgoingSnapshot = await FirebaseFirestore.instance
        .collection('calls')
        .where('callerId', isEqualTo: currentUserId)
        .get();
    
    // Get incoming calls
    final incomingSnapshot = await FirebaseFirestore.instance
        .collection('calls')
        .where('calleeId', isEqualTo: currentUserId)
        .get();
    
    // Calculate stats - combine both queries
    int totalCalls = outgoingSnapshot.docs.length + incomingSnapshot.docs.length;
    int completedCalls = 0;
    int missedCalls = 0; 
    int totalDuration = 0;
    
    // Process outgoing calls
    for (final doc in outgoingSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      
      if (status == 'completed') {
        completedCalls++;
        final duration = data['duration'] as int?;
        if (duration != null) {
          totalDuration += duration;
        }
      } else if (status == 'missed' || status == 'no_answer' || status == 'rejected') {
        missedCalls++;
      }
    }
    
    // Process incoming calls
    for (final doc in incomingSnapshot.docs) {
      final data = doc.data();
      final status = data['status'] as String?;
      
      if (status == 'completed') {
        completedCalls++;
        final duration = data['duration'] as int?;
        if (duration != null) {
          totalDuration += duration;
        }
      } else if (status == 'missed' || status == 'no_answer' || status == 'rejected') {
        missedCalls++;
      }
    }
    
    // Calculate average call duration
    final avgDuration = completedCalls > 0 
        ? (totalDuration / completedCalls).round() 
        : 0;
    
    return {
      'totalCalls': totalCalls,
      'completedCalls': completedCalls,
      'missedCalls': missedCalls,
      'totalDuration': totalDuration,
      'avgDuration': avgDuration,
      'completionRate': totalCalls > 0 
          ? (completedCalls / totalCalls) * 100 
          : 0.0,
    };
  } catch (e) {
    AppLogger.e('Error fetching call stats: $e');
    return {
      'totalCalls': 0,
      'completedCalls': 0,
      'missedCalls': 0,
      'totalDuration': 0,
      'avgDuration': 0,
      'completionRate': 0.0,
    };
  }
}); 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urocenter/core/utils/logger.dart';
import 'dart:async';

// Model class for call history items
class CallHistoryItem {
  final String id;
  final String callerId;
  final String callerName;
  final String calleeId;
  final String calleeName;
  final String status;
  final String type;
  final DateTime startTime;
  final DateTime? endTime;
  final int duration;
  
  const CallHistoryItem({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.status,
    required this.type,
    required this.startTime,
    this.endTime,
    required this.duration,
  });
  
  // Convert Firestore document to CallHistoryItem
  factory CallHistoryItem.fromFirestore(String docId, Map<String, dynamic> data) {
    // Extract start time with fallbacks
    DateTime startTime = DateTime.now(); // Default fallback
    
    if (data['startTime'] != null && data['startTime'] is Timestamp) {
      startTime = (data['startTime'] as Timestamp).toDate();
    } else if (data['startTimeLocal'] != null && data['startTimeLocal'] is Timestamp) {
      startTime = (data['startTimeLocal'] as Timestamp).toDate();
    } else if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        startTime = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is DateTime) {
        startTime = data['createdAt'] as DateTime;
      }
    }
    
    // Extract end time if available
    DateTime? endTime;
    if (data['endTime'] != null && data['endTime'] is Timestamp) {
      endTime = (data['endTime'] as Timestamp).toDate();
    }
    
    // Ensure duration is valid
    int duration = 0;
    if (data['duration'] != null && data['duration'] is int) {
      duration = data['duration'] as int;
    } else if (startTime != null && endTime != null) {
      // Calculate duration from timestamps if not explicitly provided
      duration = endTime.difference(startTime).inSeconds;
      if (duration < 0) duration = 0;
    }
    
    return CallHistoryItem(
      id: docId,
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? 'Unknown Caller',
      calleeId: data['calleeId'] as String? ?? '',
      calleeName: data['calleeName'] as String? ?? 'Unknown User',
      status: data['status'] as String? ?? 'unknown',
      type: data['type'] as String? ?? 'audio',
      startTime: startTime,
      endTime: endTime,
      duration: duration,
    );
  }
  
  // Convert to a simple Map for UI and other uses
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'status': status,
      'type': type,
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
    };
  }
}

/// Provider for call history - combines incoming and outgoing calls efficiently
final callHistoryProvider = StreamProvider<List<CallHistoryItem>>((ref) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  AppLogger.d('[CallHistoryProvider] Initializing call history for user: $currentUserId');
  
  if (currentUserId == null) {
    AppLogger.w('[CallHistoryProvider] No current user, returning empty call history');
    return Stream.value([]);
  }

  // Create a stream controller to emit combined results
  final controller = StreamController<List<CallHistoryItem>>();
  
  // Set up an efficient query that finds both incoming and outgoing calls in one
  // Firestore query by using two different OR conditions
  Query query = FirebaseFirestore.instance.collection('calls')
    .where(Filter.or(
      Filter('callerId', isEqualTo: currentUserId),
      Filter('calleeId', isEqualTo: currentUserId)
    ))
    .orderBy('startTime', descending: true)
    .limit(50);
  
  // Set up the listener for the query
  final subscription = query.snapshots().listen((snapshot) {
    try {
      final List<CallHistoryItem> callList = [];
      
      // Process all calls
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Skip invalid calls
        if (data['callerId'] == null || data['calleeId'] == null) {
          AppLogger.w('[CallHistoryProvider] Skipping call ${doc.id} - missing caller/callee ID');
          continue;
        }
        
        // Convert to CallHistoryItem
        callList.add(CallHistoryItem.fromFirestore(doc.id, data));
      }
      
      AppLogger.d('[CallHistoryProvider] Processed ${callList.length} calls');
      if (callList.isNotEmpty) {
        AppLogger.d('[CallHistoryProvider] Most recent call: ${callList.first.id} (${callList.first.status})');
      }
      
      // Add to stream if controller is still active
      if (!controller.isClosed) {
        controller.add(callList);
      }
    } catch (e) {
      AppLogger.e('[CallHistoryProvider] Error processing calls: $e');
      if (!controller.isClosed) {
        // Add empty list on error
        controller.add([]);
      }
    }
  }, onError: (e) {
    AppLogger.e('[CallHistoryProvider] Error in call history stream: $e');
    if (!controller.isClosed) {
      controller.add([]);
    }
  });
  
  // Clean up on dispose
  ref.onDispose(() {
    AppLogger.d('[CallHistoryProvider] Disposing call history provider');
    subscription.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// Provider for call statistics - more efficient queries
final callStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return _getEmptyStats();
    }
    
    // Use a more efficient query that gets both incoming and outgoing calls
    final snapshot = await FirebaseFirestore.instance.collection('calls')
      .where(Filter.or(
        Filter('callerId', isEqualTo: currentUserId),
        Filter('calleeId', isEqualTo: currentUserId)
      ))
      .get();
    
    // Calculate statistics
    int totalCalls = snapshot.docs.length;
    int completedCalls = 0;
    int missedCalls = 0;
    int totalDuration = 0;
    
    for (final doc in snapshot.docs) {
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
    
    // Calculate average duration
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
    AppLogger.e('[CallStatsProvider] Error fetching call stats: $e');
    return _getEmptyStats();
  }
});

// Helper function to get empty stats
Map<String, dynamic> _getEmptyStats() {
  return {
    'totalCalls': 0,
    'completedCalls': 0,
    'missedCalls': 0,
    'totalDuration': 0,
    'avgDuration': 0,
    'completionRate': 0.0,
  };
} 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Provider for call history data
/// Returns a list of calls with caller/callee details, timestamps and status information
final callHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('calls')
      .orderBy('startTime', descending: true)
      .limit(50)
      .snapshots()
      .asyncMap((snapshot) async {
        final callsList = <Map<String, dynamic>>[];
        
        try {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final callerId = data['callerId'] as String?;
            final calleeId = data['calleeId'] as String?;
            
            if (callerId == null || calleeId == null) continue;
            
            // Fetch caller and callee information if needed
            String callerName = data['callerName'] ?? 'Unknown Caller';
            String calleeName = data['calleeName'] ?? 'Unknown User';
            
            // Add this call to the list
            callsList.add({
              'id': doc.id,
              'callerId': callerId,
              'callerName': callerName,
              'calleeId': calleeId,
              'calleeName': calleeName,
              'status': data['status'] ?? 'unknown',
              'startTime': (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'endTime': (data['endTime'] as Timestamp?)?.toDate(),
              'duration': data['duration'],
              'type': data['type'] ?? 'audio', // 'audio' or 'video'
            });
          }
        } catch (e) {
          AppLogger.e('Error fetching call history: $e');
        }
        
        return callsList;
      });
});

/// Provider for call statistics - total calls, completed calls, etc.
final callStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final totalCalls = await FirebaseFirestore.instance
        .collection('calls')
        .count()
        .get();
        
    final completedCalls = await FirebaseFirestore.instance
        .collection('calls')
        .where('status', isEqualTo: 'completed')
        .count()
        .get();
        
    final missedCalls = await FirebaseFirestore.instance
        .collection('calls')
        .where('status', whereIn: ['missed', 'no_answer'])
        .count()
        .get();
        
    final totalDuration = await FirebaseFirestore.instance
        .collection('calls')
        .where('status', isEqualTo: 'completed')
        .get()
        .then((snapshot) {
          int totalSeconds = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final duration = data['duration'] as int?;
            if (duration != null) {
              totalSeconds += duration;
            }
          }
          return totalSeconds;
        });
    
    // Calculate average call duration
    final avgDuration = completedCalls.count! > 0 
        ? (totalDuration / completedCalls.count!).round() 
        : 0;
    
    return {
      'totalCalls': totalCalls.count ?? 0,
      'completedCalls': completedCalls.count ?? 0,
      'missedCalls': missedCalls.count ?? 0,
      'totalDuration': totalDuration,
      'avgDuration': avgDuration,
      'completionRate': totalCalls.count! > 0 
          ? (completedCalls.count! / totalCalls.count!) * 100 
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
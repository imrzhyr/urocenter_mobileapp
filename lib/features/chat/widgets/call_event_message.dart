import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urocenter/core/models/message_model.dart';
import 'package:urocenter/core/utils/logger.dart';

/// A widget for displaying call events in chat in a consistent format
class CallEventMessage extends StatelessWidget {
  final Message message;

  const CallEventMessage({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Extract call information from the message
    final callStatus = message.metadata?['status'] as String? ?? 'ended';
    final callType = message.metadata?['callType'] as String? ?? 'audio';
    int? duration = message.metadata?['duration'] as int?;
    final callerId = message.metadata?['callerId'] as String?;
    final wasAnswered = callStatus == 'completed' || 
                      (callStatus == 'ended' && (duration != null && duration > 0));
    
    // Fix missing duration for answered calls by calculating from timestamps
    final startTimeMs = message.metadata?['startTime'] as int?;
    final endTimeMs = message.metadata?['endTime'] as int?;
    if (duration == null && startTimeMs != null && endTimeMs != null && wasAnswered) {
      // Calculate duration from timestamps - convert milliseconds to seconds
      duration = ((endTimeMs - startTimeMs) / 1000).round();
      AppLogger.d("[CallEventMessage] Calculated missing duration: $duration seconds");
    }
    
    // Ensure minimum duration of 1s for connected calls
    if (wasAnswered && (duration == null || duration == 0)) {
      duration = 1;
      // AppLogger.d("[CallEventMessage] Applied minimum duration of 1s for connected call");
    }
    
    // Determine if this was an outgoing or incoming call
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOutgoing = callerId == currentUserId;
    
    // Get date/time of the call
    final callTime = message.createdAt;
    final timeString = DateFormat.jm().format(callTime);

    // Define status-based styling
    IconData callIcon;
    IconData? directionIcon = isOutgoing ? Icons.call_made : Icons.call_received;
    Color iconColor;
    Color bgColor;
    String statusText;
    
    // Set colors and icons based on call status and duration
    if (wasAnswered) {
      // Connected call (completed or ended with duration)
      callIcon = Icons.call;
      iconColor = Colors.green;
      bgColor = Colors.green.withAlpha(26); // 10% opacity (255 * 0.1 = 25.5)
      statusText = formatDuration(duration ?? 1); // Use at least 1s
    } else if (callStatus == 'missed' || callStatus == 'no_answer') {
      // Missed call
      callIcon = Icons.call_missed;
      iconColor = Colors.red;
      bgColor = Colors.red.withAlpha(26); // 10% opacity
      statusText = 'Missed';
    } else if (callStatus == 'rejected') {
      // Rejected call
      callIcon = Icons.call_end;
      iconColor = Colors.red;
      bgColor = Colors.red.withAlpha(26); // 10% opacity
      statusText = 'Declined';
    } else {
      // Default for other statuses (ringing, ended without connection)
      callIcon = Icons.call_end;
      iconColor = Colors.orange;
      bgColor = Colors.orange.withAlpha(26); // 10% opacity
      statusText = 'Call ended';
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Call type icon
            Icon(callIcon, color: iconColor, size: 18),
            const SizedBox(width: 6),
            
            // Direction icon (call made/received)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(directionIcon, color: iconColor, size: 14),
            ),
            
            // Call info text
            Text(
              '$callType call · $statusText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(width: 6),
            
            // Time info
            Text(
              timeString,
              style: theme.textTheme.bodySmall?.copyWith(
                color: iconColor.withAlpha(178), // 70% opacity (255 * 0.7 = 178.5)
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Format call duration in a human-readable format
  String formatDuration(int seconds) {
    // Ensure we never format a zero duration
    final Duration duration = Duration(seconds: seconds > 0 ? seconds : 1);
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
} 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Add import for HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:urocenter/core/utils/logger.dart';

import '../theme/app_colors.dart';
import '../services/call_service.dart'; // Import CallService and IncomingCall
import '../utils/haptic_utils.dart';
import '../../app/routes.dart'; // Import RouteNames

/// Widget to display incoming call UI overlay
class IncomingCallWidget extends ConsumerWidget {
  /// The incoming call data to display
  final IncomingCall incomingCall;

  /// Constructor
  const IncomingCallWidget({
    Key? key,
    required this.incomingCall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use Riverpod to access the call service
    
    return Container(
      color: Colors.black.withValues(alpha: 217.0),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated caller icon or avatar
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            // Incoming call text
            Text(
              'chat.incoming_call'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            // Caller name
            Text(
              incomingCall.callerName, // Display caller's name
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 40),
            // Call actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject button
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      AppLogger.d("[IncomingCallWidget] Rejecting call: ${incomingCall.callId}");
                      ref.read(callServiceProvider).rejectCall(incomingCall.callId);
                      // The notification will be dismissed automatically when state updates
                    },
                  ),
                ),
                // Accept button
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.green,
                  child: IconButton(
                    icon: const Icon(Icons.call, color: Colors.white, size: 30),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      AppLogger.d("[IncomingCallWidget] Accepting call: ${incomingCall.callId}");
                      
                      // Navigate to call screen first, so the CallController 
                      // can handle the SDP answer creation
                      final Map<String, dynamic> extraData = {
                        'callId': incomingCall.callId,
                        'partnerName': incomingCall.callerName,
                        'isCaller': false,
                      };
                      
                      AppLogger.d("[IncomingCallWidget] Navigating to CallScreen with data: $extraData");
                      context.pushNamed(
                        RouteNames.callScreen,
                        extra: extraData,
                      );
                      
                      // No need to explicitly call acceptCall here - the CallController
                      // will create and send the SDP answer when initialized
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 

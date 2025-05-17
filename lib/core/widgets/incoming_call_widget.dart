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
import '../../providers/service_providers.dart'; // Add this import for routerProvider

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
    // Get the router instance from the provider
    final router = ref.read(routerProvider);
    final theme = Theme.of(context);
    
    return Container(
      // Use a completely opaque background to prevent any UI from showing through
      color: AppColors.primary,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animated caller icon or avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            // Incoming call text
            const Text(
              'Incoming Call',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            // Caller name
            Text(
              incomingCall.callerName.isNotEmpty ? incomingCall.callerName : 'Unknown Caller',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                decoration: TextDecoration.none,
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
                  backgroundColor: AppColors.error,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    onPressed: () {
                      HapticUtils.mediumTap();
                      AppLogger.d("[IncomingCallWidget] Rejecting call: ${incomingCall.callId}");
                      ref.read(callServiceProvider).rejectCall(incomingCall.callId);
                      // The notification will be dismissed automatically when state updates
                    },
                  ),
                ),
                // Accept button
                CircleAvatar(
                  radius: 35,
                  backgroundColor: AppColors.success,
                  child: IconButton(
                    icon: const Icon(Icons.call, color: Colors.white, size: 30),
                    onPressed: () async {
                      HapticUtils.mediumTap();
                      AppLogger.d("[IncomingCallWidget] Accepting call: ${incomingCall.callId}");
                      
                      // Ensure we have a valid caller name
                      String partnerName = incomingCall.callerName;
                      if (partnerName.isEmpty) {
                        partnerName = "Unknown Caller";
                        AppLogger.w("[IncomingCallWidget] Empty caller name for call ${incomingCall.callId}, using fallback");
                      }
                      
                      // Explicitly clear the incoming call notification
                      ref.read(incomingCallProvider.notifier).clearIncomingCall();
                      
                      // Navigate to call screen first, so the CallController 
                      // can handle the SDP answer creation
                      final Map<String, dynamic> extraData = {
                        'callId': incomingCall.callId,
                        'partnerName': partnerName,
                        'isCaller': false,
                      };
                      
                      AppLogger.d("[IncomingCallWidget] Navigating to CallScreen with data: $extraData");
                      
                      // Use the router directly instead of context.pushNamed
                      router.pushNamed(
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

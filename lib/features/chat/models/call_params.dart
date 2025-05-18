import 'package:flutter/material.dart';
import 'package:urocenter/core/utils/logger.dart';
/// Data class to hold parameters needed to initialize the CallController.
/// This helps pass required data cleanly, especially through GoRouter's 'extra' field.
class CallParams {
  final String callId;
  final String partnerName;
  final bool isCaller;
  final bool isIncoming;

  CallParams({
    required this.callId,
    required this.partnerName,
    required this.isCaller,
    this.isIncoming = false,
  });

  /// Factory constructor to create CallParams from a Map (e.g., GoRouter extra).
  /// Returns null if the map is invalid or missing required fields.
  static CallParams? fromMap(dynamic data) {
    if (data is! Map<String, dynamic>) {
      AppLogger.e("CallParams Error: Provided data is not a Map<String, dynamic>.");
      return null;
    }
    
    final String? callId = data['callId'] as String?;
    final String? partnerName = data['partnerName'] as String?;
    final bool? isCaller = data['isCaller'] as bool?;
    final bool? isIncoming = data['isIncoming'] as bool?;
    
    if (callId == null || callId.isEmpty) {
      AppLogger.e("CallParams Error: Missing required field callId in map: $data");
      return null;
    }
    
    return CallParams(
      callId: callId,
      partnerName: partnerName ?? '',
      isCaller: isCaller ?? true,
      isIncoming: isIncoming ?? false,
    );
  }

  /// Converts the CallParams instance to a record.
  /// This is useful for passing parameters to the family StateNotifierProvider.
  ({String callId, bool isCaller}) toRecord() {
    return (callId: callId, isCaller: isCaller);
  }

  /// Converts the CallParams instance back to a Map.
  /// Useful for passing as 'extra' in GoRouter navigation.
  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'partnerName': partnerName,
      'isCaller': isCaller,
      'isIncoming': isIncoming,
    };
  }
} 
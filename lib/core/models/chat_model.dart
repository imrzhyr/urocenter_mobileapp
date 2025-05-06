import 'dart:convert';
import 'message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Chat model representing a conversation between two users
class Chat {
  final String id;
  final String patientId;
  final String doctorId;
  final String? lastMessageContent;
  final MessageType? lastMessageType;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final int unreadCount;
  final bool isActive;
  final String? typingUserId;
  final DateTime? typingUntil;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;
  
  Chat({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.lastMessageContent,
    this.lastMessageType,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isActive = true,
    this.typingUserId,
    this.typingUntil,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });
  
  /// Create a copy of this Chat with specified fields updated
  Chat copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? lastMessageContent,
    MessageType? lastMessageType,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    int? unreadCount,
    bool? isActive,
    String? typingUserId,
    DateTime? typingUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Chat(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
      typingUserId: typingUserId ?? this.typingUserId,
      typingUntil: typingUntil ?? this.typingUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Update last message details from a Message object
  Chat updateLastMessage(Message message) {
    return copyWith(
      lastMessageContent: message.content,
      lastMessageType: message.type,
      lastMessageTime: message.createdAt,
      updatedAt: DateTime.now(),
    );
  }
  
  /// Convert Chat object to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'last_message_content': lastMessageContent,
      'last_message_type': lastMessageType?.value,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'last_message_sender_id': lastMessageSenderId,
      'unread_count': unreadCount,
      'is_active': isActive,
      'typing_user_id': typingUserId,
      'typing_until': typingUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// Create Chat object from Map (Firestore data)
  factory Chat.fromMap(Map<String, dynamic> map) {
    // Determine patientId and doctorId from participants list
    // Assumes 'participants' field exists and contains two IDs, one of which is the current user.
    // This logic might need adjustment if chat structure changes.
    List<String> participants = map['participants'] != null ? List<String>.from(map['participants']) : [];
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String determinedPatientId = '';
    String determinedDoctorId = '';

    if (participants.length == 2) {
      if (participants.contains(currentUserId)) {
        determinedPatientId = currentUserId;
        determinedDoctorId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
      } else {
        // Fallback if currentUserId isn't in participants? Should not happen in user-doctor chat.
        // Assign based on a known ID convention if possible, or leave blank.
        // For now, assume first is patient, second is doctor if current user unknown.
        determinedPatientId = participants.isNotEmpty ? participants[0] : '';
        determinedDoctorId = participants.length > 1 ? participants[1] : '';
        AppLogger.w("[WARN] Chat.fromMap: Current user ID ($currentUserId) not found in participants: $participants. Assigning IDs based on list order.");
      }
    } else {
       AppLogger.w("[WARN] Chat.fromMap: Participants list does not contain exactly 2 IDs: $participants");
    }


    // Helper function to safely parse Timestamps
    DateTime? parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is String) {
        // Allow parsing from ISO string as a fallback if needed, but prioritize Timestamp
        try {
           return DateTime.parse(timestamp);
        } catch (_) {
           return null; // Handle invalid string format
        }
      }
      return null;
    }

    // <<< ADD DETAILED DEBUGGING >>>
    AppLogger.d("[DEBUG Chat.fromMap] Raw lastMessageContent value: ${map['lastMessageContent']}");
    AppLogger.d("[DEBUG Chat.fromMap] Type of lastMessageContent: ${map['lastMessageContent']?.runtimeType}");
    // <<< END DETAILED DEBUGGING >>>

    final createdChat = Chat(
      id: map['id'] ?? '', // Usually added manually after fetching doc.id
      patientId: determinedPatientId, // Use determined ID
      doctorId: determinedDoctorId,   // Use determined ID
      lastMessageContent: map['lastMessageContent'], 
      lastMessageType: map.containsKey('lastMessageType') && map['lastMessageType'] != null
          ? MessageType.fromString(map['lastMessageType'])
          : null,
      lastMessageTime: parseTimestamp(map['lastMessageTime']), 
      lastMessageSenderId: map['lastMessageSenderId'], 
      unreadCount: map['unreadCount'] ?? 0, 
      isActive: map['isActive'] ?? true, 
      typingUserId: map['typingUserId'], 
      typingUntil: parseTimestamp(map['typingUntil']), 
      createdAt: parseTimestamp(map['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0), 
      updatedAt: parseTimestamp(map['updatedAt']), 
      metadata: map['metadata'], // Assuming this key is correct if used
    );

    // <<< ADD DETAILED DEBUGGING >>>
    AppLogger.d("[DEBUG Chat.fromMap] Created chat lastMessageContent: ${createdChat.lastMessageContent}");
    // <<< END DETAILED DEBUGGING >>>

    return createdChat;
  }
  
  /// Convert Chat object to JSON string
  String toJson() => json.encode(toMap());
  
  /// Create Chat object from JSON string
  factory Chat.fromJson(String source) => Chat.fromMap(json.decode(source));
  
  @override
  String toString() {
    return 'Chat(id: $id, patientId: $patientId, doctorId: $doctorId, unreadCount: $unreadCount)';
  }
  
  /// Check if a user is currently typing in this chat
  bool get hasUserTyping => typingUserId != null && typingUntil != null && typingUntil!.isAfter(DateTime.now());
  
  /// Get the other participant's ID based on the current user's ID
  String getOtherParticipantId(String currentUserId) {
    return currentUserId == patientId ? doctorId : patientId;
  }
} 

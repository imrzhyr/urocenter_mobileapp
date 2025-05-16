import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Message types supported in the app
enum MessageType {
  text('text'),
  image('image'),
  voice('voice'),
  document('document'),
  call_event('call_event'); // Add call_event type for displaying call status in chat
  
  final String value;
  const MessageType(this.value);
  
  factory MessageType.fromString(String value) {
    return MessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Message status for tracking delivery
enum MessageStatus {
  sending('sending'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed');
  
  final String value;
  const MessageStatus(this.value);
  
  factory MessageStatus.fromString(String value) {
    return MessageStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MessageStatus.sending,
    );
  }
}

/// Message model representing a chat message
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String? recipientId;
  final String content;
  final MessageType type;
  final String? mediaUrl; // For URL after upload
  final String? localFilePath; // For local path before upload
  final MessageStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  
  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.recipientId,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.localFilePath, // Add to constructor
    this.status = MessageStatus.sending,
    required this.createdAt,
    this.metadata,
  });
  
  /// Create a copy of this Message with specified fields updated
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? recipientId,
    String? content,
    MessageType? type,
    String? mediaUrl,
    String? localFilePath, // Add to copyWith
    MessageStatus? status,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      localFilePath: localFilePath ?? this.localFilePath, // Add to copyWith logic
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  /// Convert Message object to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'type': type.value,
      'mediaUrl': mediaUrl,
      'localFilePath': localFilePath,
      'status': status.value,
      'metadata': metadata,
    };
  }
  
  /// Create Message object from Map
  factory Message.fromMap(Map<String, dynamic> map) {
    // Helper to handle potential Timestamp objects from Firestore
    DateTime parseTimestamp(dynamic timestampData) {
      if (timestampData is Timestamp) {
        return timestampData.toDate();
      } else if (timestampData is String) {
        return DateTime.parse(timestampData);
      } else {
        // Fallback if data is missing or unexpected type
        return DateTime.now(); 
      }
    }
    
    return Message(
      id: map['id'] ?? '', // Firestore often doesn't store the ID in the doc data
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'],
      content: map['content'] ?? '',
      type: MessageType.fromString(map['type'] ?? 'text'),
      mediaUrl: map['mediaUrl'],
      localFilePath: map['localFilePath'],
      status: MessageStatus.fromString(map['status'] ?? 'sending'),
      createdAt: parseTimestamp(map['timestamp'] ?? map['createdAt']),
      metadata: map['metadata'] != null 
          ? Map<String, dynamic>.from(map['metadata']) 
          : null, // Ensure metadata is correctly typed
    );
  }
  
  /// Convert Message object to JSON string
  String toJson() => json.encode(toMap());
  
  /// Create Message object from JSON string
  factory Message.fromJson(String source) => Message.fromMap(json.decode(source));
  
  @override
  String toString() {
    return 'Message(id: $id, chatId: $chatId, senderId: $senderId, type: ${type.value}, status: ${status.value})';
  }
  
  /// Create a temporary message before sending to server
  factory Message.createTemp({
    required String chatId,
    required String senderId,
    String? recipientId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) {
    final now = DateTime.now();
    return Message(
      id: 'temp_${now.millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: senderId,
      recipientId: recipientId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      status: MessageStatus.sending,
      createdAt: now,
    );
  }
  
  /// Check if this is a temporary message that hasn't been sent to server yet
  bool get isTemp => id.startsWith('temp_');
} 
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of notifications in the app
enum NotificationType {
  /// Chat message notification
  message,
  
  /// Document related notification
  document,
  
  /// General notification
  general
}

/// Model representing a notification
class NotificationModel {
  /// Unique identifier
  final String id;
  
  /// Notification title
  final String title;
  
  /// Notification body text
  final String body;
  
  /// Type of notification
  final NotificationType type;
  
  /// When the notification was created/received
  final DateTime timestamp;
  
  /// Whether the notification has been read by the user
  final bool isRead;
  
  /// Additional data related to the notification
  final Map<String, dynamic>? data;
  
  /// Constructor
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });
  
  /// Create a copy of this notification with updated fields
  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }
  
  /// Create a notification from a map
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: _typeFromString(map['type'] as String? ?? 'general'),
      timestamp: map['timestamp'] is DateTime 
          ? map['timestamp'] as DateTime
          : map['timestamp'] is Timestamp 
              ? (map['timestamp'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      isRead: map['isRead'] as bool? ?? false,
      data: map['data'] as Map<String, dynamic>?,
    );
  }
  
  /// Convert notification to a map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'timestamp': timestamp,
      'isRead': isRead,
      'data': data,
    };
  }
  
  /// Helper to convert string to NotificationType
  static NotificationType _typeFromString(String typeStr) {
    switch (typeStr) {
      case 'message':
        return NotificationType.message;
      case 'document':
        return NotificationType.document;
      default:
        return NotificationType.general;
    }
  }
} 
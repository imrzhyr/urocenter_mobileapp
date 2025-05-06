import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart'; // Removed unused import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import 'package:urocenter/core/utils/logger.dart';

/// Service for managing user notifications
class NotificationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  // final Ref? _ref; // Removed unused field

  StreamSubscription? _notificationSubscription;
  
  /// Constructor
  NotificationService(this._firestore, this._auth);

  /// Get the current user ID or null if not logged in
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Reference to the notifications collection
  CollectionReference get _notificationsRef => 
      _firestore.collection('users')
                .doc(_currentUserId)
                .collection('notifications');

  /// Get all notifications for the current user
  Future<List<NotificationModel>> getNotifications() async {
    if (_currentUserId == null) {
      return [];
    }

    try {
      final snapshot = await _notificationsRef
          .orderBy('timestamp', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // Ensure ID is set
            return NotificationModel.fromMap(data);
          })
          .toList();
    } catch (e) {
      AppLogger.e('Error fetching notifications: $e');
      return [];
    }
  }
  
  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await _notificationsRef.doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      AppLogger.e('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;

    try {
      final batch = _firestore.batch();
      final snapshot = await _notificationsRef
          .where('isRead', isEqualTo: false)
          .get();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      AppLogger.e('Error marking all notifications as read: $e');
    }
  }

  /// Create a message notification in Firestore
  Future<void> createMessageNotification({
    required String senderId,
    required String senderName,
    required String messageContent,
    required String chatId,
  }) async {
    if (_currentUserId == null) return;

    try {
      final notification = NotificationModel(
        id: const Uuid().v4(),
        title: 'New message from $senderName',
        body: messageContent,
        type: NotificationType.message,
        timestamp: DateTime.now(),
        isRead: false,
        data: {
          'senderId': senderId,
          'chatId': chatId,
        },
      );

      await _notificationsRef.doc(notification.id).set(notification.toMap());
    } catch (e) {
      AppLogger.e('Error creating message notification: $e');
    }
  }

  /// Create a document notification in Firestore
  Future<void> createDocumentNotification({
    required String title,
    required String body,
    required String documentId,
  }) async {
    if (_currentUserId == null) return;

    try {
      final notification = NotificationModel(
        id: const Uuid().v4(),
        title: title,
        body: body,
        type: NotificationType.document,
        timestamp: DateTime.now(),
        isRead: false,
        data: {
          'documentId': documentId,
        },
      );

      await _notificationsRef.doc(notification.id).set(notification.toMap());
    } catch (e) {
      AppLogger.e('Error creating document notification: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    if (_currentUserId == null) return;

    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (e) {
      AppLogger.e('Error deleting notification: $e');
    }
  }

  /// Listen for new notifications
  Stream<List<NotificationModel>> notificationsStream() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _notificationsRef
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return NotificationModel.fromMap(data);
          }).toList();
        });
  }

  /// Dispose of any active subscriptions
  void dispose() {
    _notificationSubscription?.cancel();
  }
} 

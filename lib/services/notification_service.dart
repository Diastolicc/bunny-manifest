import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/notification.dart';
import '../config/firebase_config.dart';

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final List<AppNotification> _notifications = [];
  bool _isInitialized = false;
  String? _currentUserId;
  StreamSubscription? _notificationsSubscription;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Get notifications collection reference for a user
  CollectionReference<Map<String, dynamic>> _notificationsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('notifications');

  // Initialize and load notifications for a user
  Future<void> initializeForUser(String userId) async {
    // If already initialized for this user, skip
    if (_isInitialized && _currentUserId == userId) return;

    // Cancel previous subscription if switching users
    if (_currentUserId != userId) {
      _notificationsSubscription?.cancel();
      _notifications.clear();
      _currentUserId = userId;
    }

    try {
      // Load existing notifications from Firestore
      final snapshot = await _notificationsCollection(userId)
          .orderBy('timestamp', descending: true)
          .limit(100) // Load last 100 notifications
          .get();

      _notifications.clear();
      for (var doc in snapshot.docs) {
        _notifications.add(AppNotification.fromJson(doc.data(), doc.id));
      }

      _isInitialized = true;
      notifyListeners();

      // Listen for real-time updates - store the subscription
      _notificationsSubscription = _notificationsCollection(userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen((snapshot) {
        _notifications.clear();
        for (var doc in snapshot.docs) {
          _notifications.add(AppNotification.fromJson(doc.data(), doc.id));
        }
        notifyListeners();
      }, onError: (e) {
        print('Error in notifications listener: $e');
      });
    } catch (e) {
      print('Error initializing notifications: $e');
      _isInitialized = true; // Still mark as initialized to prevent retry loops
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _notificationsCollection(userId)
          .doc(notificationId)
          .update({'isRead': true});
      
      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final unreadDocs = await _notificationsCollection(userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();

      // Update local state
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      notifyListeners();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Add a new notification
  Future<void> addNotification(AppNotification notification, String userId) async {
    try {
      // Add to Firestore
      await _notificationsCollection(userId).add(notification.toJson());
      
      // Local state will be updated via the snapshot listener
    } catch (e) {
      print('Error adding notification: $e');
      // Fallback to local only
      _notifications.insert(0, notification);
      notifyListeners();
    }
  }

  // Create and send notification to a specific user
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    String type = 'system',
    String? relatedId,
    String? imageUrl,
  }) async {
    final notification = AppNotification(
      id: '', // Will be set by Firestore
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      relatedId: relatedId,
      imageUrl: imageUrl,
      targetUserId: targetUserId,
    );

    await addNotification(notification, targetUserId);
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId, String userId) async {
    try {
      await _notificationsCollection(userId).doc(notificationId).delete();
      
      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Reset service (e.g., on logout)
  void reset() {
    _notificationsSubscription?.cancel();
    _notifications.clear();
    _isInitialized = false;
    _currentUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
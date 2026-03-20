import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'party_invite', 'party_update', 'system', 'reminder'
  final String? relatedId; // partyId, userId, etc.
  final String? imageUrl;
  final String? targetUserId; // Limit visibility to a specific user when set

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.type = 'system',
    this.relatedId,
    this.imageUrl,
    this.targetUserId,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? relatedId,
    String? imageUrl,
    String? targetUserId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      imageUrl: imageUrl ?? this.imageUrl,
      targetUserId: targetUserId ?? this.targetUserId,
    );
  }

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type,
      'relatedId': relatedId,
      'imageUrl': imageUrl,
      'targetUserId': targetUserId,
    };
  }

  // Create from Firestore document
  factory AppNotification.fromJson(Map<String, dynamic> json, String docId) {
    return AppNotification(
      id: docId,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      type: json['type'] as String? ?? 'system',
      relatedId: json['relatedId'] as String?,
      imageUrl: json['imageUrl'] as String?,
      targetUserId: json['targetUserId'] as String?,
    );
  }
}
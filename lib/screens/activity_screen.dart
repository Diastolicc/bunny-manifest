import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    final authService = context.read<AuthService>();
    final currentUserId = authService.firebaseUser?.uid;
    
    if (currentUserId != null) {
      await context.read<NotificationService>().initializeForUser(currentUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.colors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
              color: AppTheme.colors.primary,
              tooltip: 'Back',
            ),
          ),
        ),
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.colors.background,
        elevation: 0,
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          final notifications = notificationService.notifications;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationItem(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().firebaseUser?.uid;
    
    return GestureDetector(
      onTap: () {
        if (currentUserId != null) {
          context.read<NotificationService>().markAsRead(notification.id, currentUserId);
        }

        // Navigate to related party when available
        if (notification.relatedId != null && notification.relatedId!.isNotEmpty) {
          if (notification.type == 'party_invite' || notification.type == 'party_update') {
            context.push('/party-details?id=${notification.relatedId}');
          } else if (notification.type == 'participant_request') {
            // Navigate to participants screen for the party
            context.push('/participants/${notification.relatedId}');
          }
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.colors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.colors.text,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: notification.isRead 
                              ? AppTheme.colors.textSecondary 
                              : AppTheme.colors.text,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Left accent stripe for unread
          if (!notification.isRead)
            Positioned(
              left: 8,
              top: 8,
              bottom: 8,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppTheme.colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          // Small unread badge (dot)
          if (!notification.isRead)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.colors.card, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (notification.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          notification.imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'party_invite':
        iconData = Icons.mail;
        iconColor = AppTheme.colors.primary;
        break;
      case 'party_update':
        iconData = Icons.event;
        iconColor = AppTheme.colors.primary;
        break;
      case 'participant_request':
        iconData = Icons.person_add;
        iconColor = Colors.orange;
        break;
      case 'reminder':
        iconData = Icons.alarm;
        iconColor = AppTheme.colors.primary;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = AppTheme.colors.primary;
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Icon(
          iconData,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
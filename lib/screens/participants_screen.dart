import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/chat_service.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/models/user_profile.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:bunny/services/notification_service.dart';
import 'package:bunny/models/notification.dart';

class ParticipantsScreen extends StatefulWidget {
  final String partyId;

  const ParticipantsScreen({super.key, required this.partyId});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  Party? _party;
  bool _loading = true;
  Map<String, UserProfile> _userMap = {};
  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<PartyService>();
    final party = await service.getById(widget.partyId);
    if (party != null) {
      final profiles = await context
          .read<UserService>()
          .getUserProfiles(party.attendeeUserIds);
      final applications = await service.listApplications(widget.partyId);
      setState(() {
        _party = party;
        _userMap = profiles;
        _applications = applications;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.colors.primary,
        foregroundColor: Colors.white,
        title: const Text('Participants'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _party == null
              ? const Center(child: Text('Party not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Applications section
                    if (_applications.isNotEmpty) ...[
                      Text(
                        'Applications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.colors.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._applications.map((app) {
                        final user = _userMap[app['userId'] as String];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppTheme.colors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: user?.profileImageUrl != null
                                    ? NetworkImage(user!.profileImageUrl!)
                                    : null,
                                child: user?.profileImageUrl == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ??
                                          (app['userId'] as String),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Requested to join',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      await context
                                          .read<PartyService>()
                                          .rejectApplication(
                                              applicationId:
                                                  app['id'] as String);
                                      await _load();
                                    },
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await context
                                          .read<PartyService>()
                                          .approveApplication(
                                              applicationId:
                                                  app['id'] as String);

                                      // Notify the applicant their request was approved
                                      final userId = app['userId'] as String;
                                      final partyTitle = _party?.title ?? 'this party';
                                      await context.read<NotificationService>().sendNotificationToUser(
                                            targetUserId: userId,
                                            title: 'Join request approved',
                                            body: 'You can now join "$partyTitle".',
                                            type: 'party_update',
                                            relatedId: widget.partyId,
                                          );

                                      await _load();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.colors.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],

                    Text(
                      'Participants',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.colors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._party!.attendeeUserIds.map((userId) {
                      final user = _userMap[userId];
                      final isHost = userId == _party!.hostUserId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.colors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: user?.profileImageUrl != null
                                  ? NetworkImage(user!.profileImageUrl!)
                                  : null,
                              child: user?.profileImageUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user?.displayName ?? userId,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isHost) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.colors.primary,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Host',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (user?.email != null)
                                    Text(
                                      user!.email!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!isHost) ...[
                              IconButton(
                                onPressed: () => _showKickConfirmation(
                                    context, user, userId),
                                icon: const Icon(Icons.person_remove,
                                    color: Colors.red),
                                tooltip: 'Kick participant',
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
    );
  }

  // Show kick confirmation dialog
  void _showKickConfirmation(
      BuildContext context, UserProfile? user, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_remove, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Kick Participant'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to kick ${user?.displayName ?? 'this participant'} from the party?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will remove them from the party and the chat group.',
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _kickParticipant(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kick Participant',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Kick participant from party and chat
  Future<void> _kickParticipant(String userId) async {
    try {
      final partyService = context.read<PartyService>();
      final chatService = context.read<ChatService>();

      // Get current party data
      final currentParty = await partyService.getById(widget.partyId);
      if (currentParty == null) {
        throw Exception('Party not found');
      }

      // Remove user from party attendees list
      final updatedAttendees = List<String>.from(currentParty.attendeeUserIds)
        ..remove(userId);

      await partyService.updateParty(widget.partyId, {
        'attendeeUserIds': updatedAttendees,
      });

      // Remove user from chat group and send system message
      final chatGroup = await chatService.getChatGroupForParty(widget.partyId);
      if (chatGroup != null) {
        // Update chat group members
        final updatedMembers = List<String>.from(chatGroup.memberIds)
          ..remove(userId);

        await chatService.updateChatGroupMembers(chatGroup.id, updatedMembers);

        // Send system message about the kick
        await chatService.sendSystemMessage(
          groupId: chatGroup.id,
          text:
              '👋 ${_userMap[userId]?.displayName ?? 'A participant'} has been removed from the party by the host.',
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_userMap[userId]?.displayName ?? 'Participant'} has been kicked from the party'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the participants list
      await _load();
    } catch (e) {
      print('Error kicking participant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to kick participant: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

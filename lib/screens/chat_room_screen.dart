import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/services/chat_service.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/reminder_service.dart';
import 'package:bunny/services/club_service.dart';
import 'package:bunny/models/chat_group.dart';
import 'package:bunny/models/message.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/models/user_profile.dart';

class ChatRoomScreen extends StatefulWidget {
  final String groupId;
  const ChatRoomScreen({super.key, required this.groupId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ChatGroup? _group;
  Future<void> _fetchGroupFromFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final doc =
        await firestore.collection('chat_groups').doc(widget.groupId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _group = ChatGroup(
          id: doc.id,
          name: data['name'] ?? 'Chat',
          groupPhotoUrl: data['groupPhotoUrl'] ?? '',
          memberIds: List<String>.from(data['memberIds'] ?? []),
          lastMessage: data['lastMessage'] ?? '',
          lastMessageTime: (data['lastMessageTime'] is Timestamp)
              ? (data['lastMessageTime'] as Timestamp).toDate()
              : DateTime.now(),
          unreadCount: 0, // derived in ChatService; unused here
          unreadByUser: (data['unreadByUser'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())),
          isActive: data['isActive'] ?? true,
          hostUserId: data['hostUserId'] as String?,
          hostName: data['hostName'] as String?,
          partyId: data['partyId'] as String?,
        );
      });
    }
  }

  void _showUserOptionsBottomSheet(String userId) {
    if (!mounted) return;
    final navigatorContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.message, color: Colors.blue),
                title: const Text('Send Private Message'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (navigatorContext.mounted) {
                    await _openDirectMessage(navigatorContext, userId);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text('Visit Profile'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (navigatorContext.mounted && userId.isNotEmpty) {
                    try {
                      final encodedUserId = Uri.encodeComponent(userId);
                      print('Navigating to user profile: $userId');
                      navigatorContext.push('/user-profile/$encodedUserId');
                    } catch (e) {
                      print('Error navigating to profile: $e');
                      if (navigatorContext.mounted) {
                        ScaffoldMessenger.of(navigatorContext).showSnackBar(
                          SnackBar(
                            content: Text('Error opening profile: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else if (navigatorContext.mounted) {
                    ScaffoldMessenger.of(navigatorContext).showSnackBar(
                      const SnackBar(content: Text('Invalid user ID')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirectMessage(BuildContext context, String userId) async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send messages')),
        );
        return;
      }

      if (currentUser.id == userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot message yourself')),
        );
        return;
      }

      // Get user profile
      final userService = context.read<UserService>();
      final userProfile = await userService.getUserProfile(userId);

      if (userProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      // Check if direct message chat group already exists
      // Direct messages should have exactly 2 members and NO partyId
      final firestore = FirebaseFirestore.instance;
      final chatGroupsSnapshot = await firestore
          .collection('chat_groups')
          .where('memberIds', arrayContains: currentUser.id)
          .get();

      String? groupId;
      for (var doc in chatGroupsSnapshot.docs) {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        final hasPartyId = data['partyId'] != null;

        // Only match groups with exactly 2 members, both users, and no partyId
        if (memberIds.contains(userId) &&
            memberIds.length == 2 &&
            !hasPartyId) {
          groupId = doc.id;
          break;
        }
      }

      // Create new direct message group if it doesn't exist
      if (groupId == null) {
        final groupRef = await firestore.collection('chat_groups').add({
          'name': userProfile.displayName,
          'groupPhotoUrl': userProfile.profileImageUrl ?? '',
          'memberIds': [currentUser.id, userId],
          'lastMessage': '',
          'lastMessageTime': Timestamp.now(),
          'unreadCount': 0,
            'unreadByUser': {
              currentUser.id: 0,
              userId: 0,
            },
          'isActive': true,
          'createdAt': Timestamp.now(),
          // Explicitly set partyId to null to ensure it's a direct message
          'partyId': null,
        });
        groupId = groupRef.id;
      }

      // Navigate to the chat room
      if (context.mounted) {
        final encodedGroupId = Uri.encodeComponent(groupId);
        print('Navigating to direct message chat room: $groupId');
        try {
          context.push('/chat/room/$encodedGroupId');
        } catch (e) {
          print('Error navigating to chat room: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error opening chat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error opening direct message: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = context.read<ChatService>();
      final all = service.chatGroups;
      ChatGroup? found;
      try {
        found = all.firstWhere((g) => g.id == widget.groupId);
      } catch (_) {
        found = null;
      }
      if (found != null && found.memberIds.isNotEmpty) {
        setState(() {
          _group = found;
        });
      } else {
        await _fetchGroupFromFirestore();
      }
      // Load messages for this group
      service.loadMessagesForGroup(widget.groupId);
      // Mark as read for current user
      await service.markGroupAsRead(widget.groupId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios,
                      color: Colors.black54, size: 18),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: (group?.groupPhotoUrl.isNotEmpty ?? false)
                      ? NetworkImage(group!.groupPhotoUrl)
                      : null,
                  child: (group?.groupPhotoUrl.isEmpty ?? true)
                      ? const Icon(Icons.group_rounded,
                          color: Colors.black54, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showChatDetailsBottomSheet(context, group),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group?.name ?? 'Chat',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          group == null
                              ? ''
                              : '${group.memberIds.length} members',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),

                // Reminders Button
                // Show Reminders button only for group chats (with partyId)
                if (group != null && group.partyId != null)
                  GestureDetector(
                    onTap: () {
                      print('Reminders button tapped');
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) =>
                            _RemindersBottomSheet(group: group),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.orange.shade200, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active,
                              size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Reminders',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: Consumer<ChatService>(
                builder: (context, chatService, child) {
                  final messages =
                      chatService.getMessagesForGroup(widget.groupId);
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  // Build list with date dividers
                  // Messages come from Firestore newest first (descending order)
                  // We want: older messages at top, newer at bottom, with dividers above messages
                  // Strategy: Reverse messages to get oldest first, then build items with dividers before messages
                  final List<Widget> items = [];
                  DateTime? currentDate;

                  // Reverse messages to get oldest first (since they come newest first)
                  final reversedMessages = messages.reversed.toList();

                  // Iterate from oldest to newest
                  for (int i = 0; i < reversedMessages.length; i++) {
                    final message = reversedMessages[i];
                    final messageDate = DateTime(
                      message.timestamp.year,
                      message.timestamp.month,
                      message.timestamp.day,
                    );

                    final authService = context.read<AuthService>();
                    final currentUserId = authService.currentUser?.id;
                    final bool isSystem = message.senderId == 'system';
                    final bool isMe = currentUserId != null &&
                        message.senderId == currentUserId;

                    // Check if this is the first message of a new date
                    // Add divider before the messages of this date
                    if (currentDate == null ||
                        !_isSameDay(messageDate, currentDate)) {
                      items.add(_DateDivider(date: message.timestamp));
                      currentDate = messageDate;
                    }

                    items.add(_SpaciousMessageBubble(
                      message: message,
                      isMe: isMe,
                      isSystem: isSystem,
                      onUserTap: (userId) =>
                          _showUserOptionsBottomSheet(userId),
                    ));
                  }

                  // Auto-scroll to bottom when messages are loaded
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController
                          .jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: false, // Oldest at top, newest at bottom
                    padding: EdgeInsets.fromLTRB(
                        20, 20, 20, MediaQuery.of(context).padding.bottom + 80),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return items[index];
                    },
                  );
                },
              ),
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                      ),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (text) {
                        final t = text.trim();
                        if (t.isNotEmpty) {
                          context
                              .read<ChatService>()
                              .sendMessage(groupId: widget.groupId, text: t);
                          _messageController.clear();
                          // Auto-scroll to bottom after sending message
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    final t = _messageController.text.trim();
                    if (t.isNotEmpty) {
                      context
                          .read<ChatService>()
                          .sendMessage(groupId: widget.groupId, text: t);
                      _messageController.clear();
                      // Auto-scroll to bottom after sending message
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0.0, // Since reverse: true, 0.0 is the bottom
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8d58b5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child:
                        const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChatDetailsBottomSheet(BuildContext context, ChatGroup? group) {
    // Only show details bottom sheet for group chats (with partyId)
    if (group == null || group.partyId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatDetailsBottomSheet(group: group),
    );
  }
}

class _ChatDetailsBottomSheet extends StatelessWidget {
  final ChatGroup group;

  const _ChatDetailsBottomSheet({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: group.groupPhotoUrl.isNotEmpty
                      ? NetworkImage(group.groupPhotoUrl)
                      : null,
                  child: group.groupPhotoUrl.isEmpty
                      ? const Icon(Icons.group_rounded,
                          color: Colors.black54, size: 20)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${group.memberIds.length} members',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _navigateToPartyDetails(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Party Details Section
          FutureBuilder<Party?>(
            future: _getPartyForGroup(context),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final party = snapshot.data!;
                return _buildPartyDetailsSection(party);
              }
              return _buildNoPartySection();
            },
          ),
          // Members Section
          _buildMembersSection(context),
          // Bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Future<Party?> _getPartyForGroup(BuildContext context) async {
    try {
      final partyService = context.read<PartyService>();
      final parties = await partyService.getAllParties();
      print('ChatRoom: Searching for party matching chat group: ${group.name}');
      print(
          'ChatRoom: Available parties: ${parties.map((p) => p.title).toList()}');

      // Try exact match first
      for (final party in parties) {
        if (party.title.toLowerCase() == group.name.toLowerCase()) {
          print('ChatRoom: Found exact match: ${party.title}');
          return party;
        }
      }

      // Try partial match
      for (final party in parties) {
        if (party.title.toLowerCase().contains(group.name.toLowerCase()) ||
            group.name.toLowerCase().contains(party.title.toLowerCase())) {
          print('ChatRoom: Found partial match: ${party.title}');
          return party;
        }
      }

      // If no match found, return the first party as fallback for testing
      if (parties.isNotEmpty) {
        print(
            'ChatRoom: No match found, using first party as fallback: ${parties.first.title}');
        return parties.first;
      }

      print('ChatRoom: No parties available');
      return null;
    } catch (e) {
      print('ChatRoom: Error getting party for group: $e');
      return null;
    }
  }

  Widget _buildPartyDetailsSection(Party party) {
    return Builder(
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Party Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.event, 'Event', party.title),
              FutureBuilder<String?>(
                future: _getClubName(party.clubId, context),
                builder: (context, snapshot) {
                  return _buildDetailRow(Icons.location_on, 'Venue',
                      snapshot.data ?? 'Loading...');
                },
              ),
              _buildDetailRow(
                  Icons.calendar_today, 'Date', _formatDate(party.dateTime)),
              _buildDetailRow(Icons.people, 'Capacity',
                  '${party.attendeeUserIds.length}/${party.capacity}'),
              if (party.budgetPerHead != null)
                _buildDetailRow(Icons.attach_money, 'Budget',
                    '₱${party.budgetPerHead} per person'),
              // Entrance fee information
              if (party.hasEntranceFee)
                _buildDetailRow(Icons.attach_money, 'Entrance Fee',
                    '₱${party.entranceFeeAmount}'),
              if (!party.hasEntranceFee)
                _buildDetailRow(Icons.free_breakfast, 'Entrance Fee', 'FREE'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoPartySection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Party Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'No party details available for this chat',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black54),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Members',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Party?>(
            future: _getPartyForGroup(context),
            builder: (context, partySnapshot) {
              if (!partySnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              final party = partySnapshot.data;
              return FutureBuilder<List<UserProfile>>(
                future: _getMemberProfiles(context),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final members = snapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return FutureBuilder<String>(
                          future: _getMemberStatus(member, party, group),
                          builder: (context, statusSnapshot) {
                            final status = statusSnapshot.data ?? 'Member';
                            return _buildMemberItem(member, party, status);
                          },
                        );
                      },
                    );
                  }
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<UserProfile>> _getMemberProfiles(BuildContext context) async {
    try {
      final userService = context.read<UserService>();
      final profilesMap = await userService.getUserProfiles(group.memberIds);
      return profilesMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> _getMemberStatus(
      UserProfile member, Party? party, ChatGroup group) async {
    if (party == null) return 'Member';
    if (party.isCancelled == true) {
      return 'Cancelled';
    }

    // Check if user has arrived
    try {
      final firestore = FirebaseFirestore.instance;
      final chatGroupDoc =
          await firestore.collection('chat_groups').doc(group.id).get();
      final data = chatGroupDoc.data() ?? {};
      final arrivedUserIds = List<String>.from(data['arrivedUserIds'] ?? []);

      if (arrivedUserIds.contains(member.id)) {
        return 'Arrived';
      }
    } catch (e) {
      print('Error checking arrival status: $e');
    }

    if (member.id == party.hostUserId) {
      return 'Host';
    }
    if (party.attendeeUserIds.contains(member.id)) {
      return 'Going';
    }
    return 'Member';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Host':
        return Colors.purple;
      case 'Going':
        return Colors.blue;
      case 'Arrived':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMemberItem(UserProfile member, Party? party, String status) {
    final statusColor = _getStatusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade100,
            backgroundImage: member.profileImageUrl != null &&
                    member.profileImageUrl!.isNotEmpty
                ? NetworkImage(member.profileImageUrl!)
                : null,
            child: member.profileImageUrl == null ||
                    member.profileImageUrl!.isEmpty
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Member since ${_formatDate(member.createdAt ?? DateTime.now())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPartyDetails(BuildContext context) {
    print('ChatRoom: Starting navigation to party details...');

    // Close the bottom sheet first
    Navigator.of(context).pop();

    // Get the party for this chat group asynchronously
    _getPartyForGroup(context).then((party) {
      print('ChatRoom: Found party for navigation: ${party?.id}');

      if (party != null) {
        print('ChatRoom: Attempting navigation...');
        print('ChatRoom: Party title: ${party.title}');

        // Use GoRouter for consistent navigation
        Future.delayed(const Duration(milliseconds: 200), () {
          try {
            // Use GoRouter to navigate to party details
            context.push('/party-details/${party.id}');
            print('ChatRoom: Navigation completed successfully');
          } catch (e) {
            print('ChatRoom: Navigation failed with error: $e');
            print('ChatRoom: Error type: ${e.runtimeType}');
            print('ChatRoom: Error details: $e');
          }
        });
      } else {
        print('ChatRoom: No party found for chat group: ${group.name}');
        print('ChatRoom: Error - No party found for this chat');
      }
    }).catchError((error) {
      print('ChatRoom: Error in _getPartyForGroup: $error');
      print('ChatRoom: Error type: ${error.runtimeType}');
    });
  }

  Future<String?> _getClubName(String clubId, BuildContext context) async {
    try {
      final clubService = context.read<ClubService>();
      final club = await clubService.getById(clubId);
      return club?.name ?? 'Unknown Venue';
    } catch (e) {
      print('Error getting club name: $e');
      return 'Unknown Venue';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

Future<void> _handleJoinParty(BuildContext context, String inviteCode) async {
  if (inviteCode.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid invite code')),
    );
    return;
  }

  try {
    final authService = context.read<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join a party')),
      );
      return;
    }

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('Joining party with code: $inviteCode'),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    final partyService = context.read<PartyService>();
    final party = await partyService.joinViaInviteCode(
      inviteCode: inviteCode.trim().toUpperCase(),
      userId: currentUser.id,
    );

    if (party != null) {
      // Success - navigate to party details
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the party!'),
            backgroundColor: Colors.green,
          ),
        );
        context.push('/party-details?id=${party.id}');
      }
    } else {
      // Party not found
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Party not found or invite code is invalid'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining party: $e')),
      );
    }
  }
}

String _formatMessageTime(DateTime time) {
  // Only show time, no date
  final hour = time.hour;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return '$displayHour:$minute $period';
}

String _formatDateDivider(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDate = DateTime(date.year, date.month, date.day);

  // If message was sent today
  if (messageDate == today) {
    return 'Today';
  }

  // If message was sent yesterday
  final yesterday = today.subtract(const Duration(days: 1));
  if (messageDate == yesterday) {
    return 'Yesterday';
  }

  // If message was sent this week (within 7 days)
  final difference = today.difference(messageDate).inDays;
  if (difference < 7) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return weekdays[date.weekday - 1];
  }

  // For older messages, show full date
  final months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

bool _isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.shade300,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDateDivider(date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaciousMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isSystem;
  final Function(String)? onUserTap;
  const _SpaciousMessageBubble({
    required this.message,
    required this.isMe,
    required this.isSystem,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    // Party invite messages have a special card appearance
    // If from sender, align to right and style like sender's messages
    if (message.type == 'party_invite' && message.partyId != null) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(
            left: isMe ? 60 : 0,
            right: isMe ? 0 : 60,
            bottom: 16,
            top: 4,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border:
                isMe ? null : Border.all(color: Colors.grey.shade300, width: 1),
            boxShadow: [
              BoxShadow(
                color: (isMe ? Colors.blue : Colors.black)
                    .withOpacity(isMe ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMe) ...[
                // Show "You" label for sender
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'You',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                children: [
                  Icon(
                    Icons.party_mode,
                    color: isMe ? Colors.white : Colors.grey.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message.partyTitle ?? 'Party Invitation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isMe
                      ? null
                      : () async {
                          if (message.inviteCode == null ||
                              message.inviteCode!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Invalid invite code')),
                            );
                            return;
                          }
                          await _handleJoinParty(context, message.inviteCode!);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMe
                        ? Colors.white.withOpacity(0.3)
                        : Colors.blue.shade600,
                    foregroundColor: isMe ? Colors.white : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isMe ? 'Sent by You' : 'Join Party',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatMessageTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withOpacity(0.8)
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // System messages have a special centered, announcement-style appearance
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF8d58b5) : Colors.white,
        borderRadius: BorderRadius.circular(24).copyWith(
          bottomLeft:
              isMe ? const Radius.circular(24) : const Radius.circular(8),
          bottomRight:
              isMe ? const Radius.circular(8) : const Radius.circular(24),
        ),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: const Color(0xFF8d58b5).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message.senderName,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500),
              ),
            ),
          Text(
            message.text,
            style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: isMe ? Colors.white : Colors.black87),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );

    final avatarKey = GlobalKey();
    final avatar = GestureDetector(
      onTap: isMe
          ? null
          : () {
              onUserTap?.call(message.senderId);
            },
      child: CircleAvatar(
        key: avatarKey,
        radius: 16,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          message.senderName.isNotEmpty
              ? message.senderName[0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    bubble,
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        _formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Read status indicator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Icon(
                      message.readBy.length > 1
                          ? Icons.done_all // Multiple people read it
                          : Icons.done, // Only sender read it
                      size: 14,
                      color: message.readBy.length > 1
                          ? Colors.blue
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      child: bubble,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            avatar,
          ],
        ],
      ),
    );
  }
}

class _RemindersBottomSheet extends StatefulWidget {
  final ChatGroup group;

  const _RemindersBottomSheet({required this.group});

  @override
  State<_RemindersBottomSheet> createState() => _RemindersBottomSheetState();
}

class _RemindersBottomSheetState extends State<_RemindersBottomSheet> {
  final List<Map<String, dynamic>> _reminders = [];
  final TextEditingController _reminderController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  Map<String, UserProfile> _memberProfiles = {};
  bool _isLoading = true;
  bool _isHost = false;
  final ReminderService _reminderService = ReminderService();

  @override
  void initState() {
    super.initState();
    _checkIfHost();
    _loadMemberProfiles();
    _loadReminders();
  }

  void _checkIfHost() {
    try {
      final authService = context.read<AuthService>();
      final currentUserId = authService.currentUser?.id;
      final hostUserId = widget.group.hostUserId;

      setState(() {
        _isHost = currentUserId != null && currentUserId == hostUserId;
      });

      print(
          'Host check: currentUserId=$currentUserId, hostUserId=$hostUserId, isHost=$_isHost');
    } catch (e) {
      print('Error checking host status: $e');
      setState(() {
        _isHost = false;
      });
    }
  }

  @override
  void dispose() {
    _reminderController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberProfiles() async {
    try {
      final userService = context.read<UserService>();
      final profiles =
          await userService.getUserProfiles(widget.group.memberIds);
      setState(() {
        _memberProfiles = profiles;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadReminders() async {
    try {
      final reminders =
          await _reminderService.getRemindersForGroup(widget.group.id);
      setState(() {
        _reminders.clear();
        _reminders.addAll(reminders);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reminders: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addReminder() async {
    if (_reminderController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reminder')),
      );
      return;
    }

    try {
      final currentUser = context.read<AuthService>().currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      final reminderId = await _reminderService.addReminder(
        groupId: widget.group.id,
        text: _reminderController.text,
        time:
            _timeController.text.isNotEmpty ? _timeController.text : 'General',
        createdBy: currentUser.id,
      );

      if (reminderId != null) {
        // Reload reminders from database
        await _loadReminders();

        _reminderController.clear();
        _timeController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder added successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add reminder')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add reminder: $e')),
        );
      }
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      final success = await _reminderService.deleteReminder(id);

      if (success) {
        // Reload reminders from database
        await _loadReminders();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete reminder')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete reminder: $e')),
        );
      }
    }
  }

  String _getDisplayName(String userId) {
    final profile = _memberProfiles[userId];
    return profile?.displayName ?? 'Member $userId';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.notifications_active,
                    color: Colors.orange.shade700, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Party Reminders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 24),
                ),
              ],
            ),
          ),

          // Add new reminder form (host only)
          if (_isHost) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Reminder',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  // Reminder text
                  TextField(
                    controller: _reminderController,
                    decoration: const InputDecoration(
                      labelText: 'Reminder text',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Meet at the entrance at 8:00 PM',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Time (optional)
                  TextField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 8:00 PM, Before leaving',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addReminder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Reminder'),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Non-host message
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only the party host can add and manage reminders',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Reminders list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _reminders.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No reminders yet',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = _reminders[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reminder['text'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Time: ${reminder['time']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Added by ${_getDisplayName(reminder['createdBy'])}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_isHost)
                                  IconButton(
                                    onPressed: () =>
                                        _deleteReminder(reminder['id']),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

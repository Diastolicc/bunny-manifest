//
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/local_cache_service.dart';
import '../models/chat_group.dart';
import '../theme/app_theme.dart';

String formatTimeStatic(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.inDays > 0) {
    return '${difference.inDays}d';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m';
  } else {
    return 'now';
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Calculate unread count for a group based on messages
  Future<int> _getUnreadCountForGroup(String groupId, String userId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .get();
      
      int unreadCount = 0;
      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        // Handle both old (isRead) and new (readBy) structure
        if (data.containsKey('readBy')) {
          final readBy = List<String>.from(data['readBy'] as List<dynamic>? ?? []);
          // Count messages this user hasn't read
          if (!readBy.contains(userId)) {
            unreadCount++;
          }
        } else if (data.containsKey('isRead')) {
          // Old structure: if message is not read by anyone, count as unread
          final isRead = data['isRead'] as bool? ?? false;
          if (!isRead) {
            unreadCount++;
          }
        } else {
          // No read status field - assume unread for safety
          unreadCount++;
        }
      }
      return unreadCount;
    } catch (e) {
      print('Error calculating unread count: $e');
      return 0;
    }
  }

  // Cache chat groups locally
  Future<void> _cacheChatGroups(List<ChatGroup> groups) async {
    try {
      final jsonList = groups.map((g) => {
        'id': g.id,
        'name': g.name,
        'groupPhotoUrl': g.groupPhotoUrl,
        'memberIds': g.memberIds,
        'lastMessage': g.lastMessage,
        'lastMessageTime': g.lastMessageTime.toIso8601String(),
        'unreadCount': g.unreadCount,
        'isActive': g.isActive,
        'hostUserId': g.hostUserId,
        'hostName': g.hostName,
        'partyId': g.partyId,
      }).toList();
      await LocalCacheService.cacheJsonData('chat_groups', jsonList);
    } catch (e) {
      print('Error caching chat groups: $e');
    }
  }

  // Load cached chat groups
  Future<List<ChatGroup>?> _loadCachedChatGroups() async {
    try {
      final jsonList = await LocalCacheService.getCachedJsonData('chat_groups');
      if (jsonList != null && jsonList is List) {
        return jsonList.map((item) => ChatGroup(
          id: item['id'] ?? '',
          name: item['name'] ?? 'Chat',
          groupPhotoUrl: item['groupPhotoUrl'] ?? '',
          memberIds: List<String>.from(item['memberIds'] ?? []),
          lastMessage: item['lastMessage'] ?? '',
          lastMessageTime: DateTime.tryParse(item['lastMessageTime'] ?? '') ?? DateTime.now(),
          unreadCount: item['unreadCount'] ?? 0,
          isActive: item['isActive'] ?? true,
          hostUserId: item['hostUserId'],
          hostName: item['hostName'],
          partyId: item['partyId'],
        )).toList();
      }
    } catch (e) {
      print('Error loading cached chat groups: $e');
    }
    return null;
  }

  Future<void> _deleteConversation(BuildContext context, ChatGroup group) async {
    try {
      // Delete the chat group document
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(group.id)
          .delete();
      
      // Delete all messages in the subcollection
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(group.id)
          .collection('messages')
          .get();
      
      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Clear cache
      await LocalCacheService.cacheJsonData('chat_groups', null);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation "${group.name}" deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error deleting conversation: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete conversation'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<bool> _confirmDelete(BuildContext context, ChatGroup group) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Conversation?'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildChatGroupsList(
      List<ChatGroup> chatGroups, BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredGroups = query.isEmpty
        ? chatGroups
        : chatGroups.where((group) {
            final name = group.name.toLowerCase();
            final message = group.lastMessage.toLowerCase();
            return name.contains(query) || message.contains(query);
          }).toList();

    final sortedGroups = List<ChatGroup>.from(filteredGroups)
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    if (sortedGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              Text(
                query.isEmpty ? 'No conversations yet' : 'No chats found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                query.isEmpty
                    ? 'Start a conversation to see it here.'
                    : 'Try a different keyword.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final unreadTotal = sortedGroups.fold<int>(
      0,
      (sum, group) => sum + group.unreadCount,
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: sortedGroups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6EAF3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_left_rounded,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Swipe left to delete a conversation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (unreadTotal > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unreadTotal unread',
                      style: TextStyle(
                        color: AppTheme.colors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        final group = sortedGroups[index - 1];
        return Dismissible(
          key: Key(group.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            final confirmed = await _confirmDelete(context, group);
            if (confirmed) {
              await _deleteConversation(context, group);
            }
            return confirmed;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5B5B),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: 6),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          child: InkWell(
            onTap: () => context.push('/chat/room/${group.id}'),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE8ECF3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.colors.primary.withOpacity(0.14),
                    backgroundImage: group.groupPhotoUrl.isNotEmpty
                        ? NetworkImage(group.groupPhotoUrl)
                        : null,
                    child: group.groupPhotoUrl.isEmpty
                        ? Icon(
                            group.memberIds.length > 2
                                ? Icons.groups_rounded
                                : Icons.person_rounded,
                            color: AppTheme.colors.primary,
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1F2A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FB),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                formatTimeStatic(group.lastMessageTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.lastMessage.isEmpty
                                    ? 'No messages yet'
                                    : group.lastMessage,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: group.unreadCount > 0
                                      ? const Color(0xFF2A2F3B)
                                      : Colors.grey.shade600,
                                  fontWeight: group.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  height: 1.35,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (group.unreadCount > 0) ...[
                              const SizedBox(width: 10),
                              Container(
                                constraints: const BoxConstraints(minWidth: 22),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.colors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${group.unreadCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final currentUser = authService.currentUser;
        final isGuest = authService.isGuest;
        
        return Scaffold(
          backgroundColor: const Color(0xFFF6F8FC),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 18,
                  left: 20,
                  right: 20,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1F2A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep up with your party conversations',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6FB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE1E7F2)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search chats',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade600,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: currentUser == null || isGuest
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0xFFE7EBF4)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.colors.primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppTheme.colors.primary,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Log In To Open Chats',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'You need to be logged in to start or join a conversation.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade600,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.colors.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () => context.push('/login'),
                                    child: const Text(
                                      'Log In / Create Account',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : FutureBuilder<List<ChatGroup>?>(
                    future: _loadCachedChatGroups(),
                    builder: (context, cacheSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('chat_groups')
                            .where('memberIds', arrayContains: currentUser.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          // Use cache data while loading from Firebase
                          List<ChatGroup>? displayGroups = cacheSnapshot.data;

                          if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                              displayGroups == null) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          // If Firebase has data, use that and cache it
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                            final groupFutures =
                                snapshot.data!.docs.map((doc) async {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final unreadCount =
                                  await _getUnreadCountForGroup(
                                      doc.id, currentUser.id);

                              return ChatGroup(
                                id: doc.id,
                                name: data['name'] ?? 'Chat',
                                groupPhotoUrl: data['groupPhotoUrl'] ?? '',
                                memberIds: List<String>.from(
                                    data['memberIds'] ?? []),
                                lastMessage: data['lastMessage'] ?? '',
                                lastMessageTime: (data['lastMessageTime']
                                        is Timestamp)
                                    ? (data['lastMessageTime'] as Timestamp)
                                        .toDate()
                                    : DateTime.now(),
                                unreadCount: unreadCount,
                                isActive: data['isActive'] ?? true,
                                hostUserId: data['hostUserId'] as String?,
                                hostName: data['hostName'] as String?,
                                partyId: data['partyId'] as String?,
                              );
                            }).toList();

                            return FutureBuilder<List<ChatGroup>>(
                              future: Future.wait(groupFutures),
                              builder: (context, groupSnapshot) {
                                if (!groupSnapshot.hasData) {
                                  // Show cached data while loading
                                  if (displayGroups != null &&
                                      displayGroups.isNotEmpty) {
                                    return _buildChatGroupsList(
                                        displayGroups, context);
                                  }
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                final chatGroups = groupSnapshot.data!;
                                // Cache the new data
                                _cacheChatGroups(chatGroups);

                                return _buildChatGroupsList(
                                    chatGroups, context);
                              },
                            );
                          }

                          // No Firebase data, show cache if available
                          if (displayGroups != null &&
                              displayGroups.isNotEmpty) {
                            return _buildChatGroupsList(
                                displayGroups, context);
                          }

                          // No cache and no Firebase data
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    color: AppTheme.colors.primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.forum_outlined,
                                    size: 38,
                                    color: AppTheme.colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No conversations',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B1F2A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start a conversation to see it here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
              ),
            ],
          ),
        );
      },
    );
  }
}

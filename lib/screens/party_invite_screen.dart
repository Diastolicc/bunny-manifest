import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/party.dart';
import '../models/user_profile.dart';
import '../models/chat_group.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class PartyInviteScreen extends StatefulWidget {
  final Party party;

  const PartyInviteScreen({
    super.key,
    required this.party,
  });

  @override
  State<PartyInviteScreen> createState() => _PartyInviteScreenState();
}

class _PartyInviteScreenState extends State<PartyInviteScreen> {
  List<UserProfile> _recommendedUsers = [];
  List<String> _invitedUserIds = [];
  bool _isLoadingUsers = false;
  bool _isSendingInvite = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendedUsers();
  }

  Future<void> _loadRecommendedUsers() async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser == null) return;

      final userService = context.read<UserService>();
      
      // Show loading state only if data is still empty
      if (_recommendedUsers.isEmpty) {
        setState(() {
          _isLoadingUsers = true;
        });
      }
      
      final allUsers = await userService.getAllUsers();

      // Get Firestore to check for admin users
      final firestore = FirebaseFirestore.instance;

      // Filter out current user, users already in the party, guest users, and admin users
      final recommended = <UserProfile>[];
      for (final user in allUsers) {
        // Skip if current user or already in party
        if (user.id == currentUser.id ||
            widget.party.attendeeUserIds.contains(user.id)) {
          continue;
        }

        // Skip guest users (no email)
        if (user.email == null || user.email!.isEmpty) {
          continue;
        }

        // Check if user is admin by checking Firestore directly
        try {
          final userDoc =
              await firestore.collection('users').doc(user.id).get();
          final userData = userDoc.data();
          final isAdmin = userData?['isAdmin'] == true;
          if (isAdmin) {
            continue; // Skip admin users
          }
        } catch (e) {
          // If error checking, include user (better to show than hide)
          print('Error checking admin status for ${user.id}: $e');
        }

        recommended.add(user);
        
        // Update UI with initial batch of 5 users immediately
        if (recommended.length == 5 && _recommendedUsers.isEmpty) {
          if (mounted) {
            setState(() {
              _recommendedUsers = List.from(recommended);
              _isLoadingUsers = false;
            });
          }
        }
        
        if (recommended.length >= 20) break; // Limit to 20 recommendations
      }

      if (mounted) {
        setState(() {
          _recommendedUsers = recommended;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Error loading recommended users: $e');
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _sendInvite(UserProfile user) async {
    if (_isSendingInvite || _invitedUserIds.contains(user.id)) return;

    setState(() {
      _isSendingInvite = true;
      _invitedUserIds.add(user.id);
    });

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to send invites')),
        );
        return;
      }

      // Send invite message via direct message
      final inviteMessage =
          '🎉 You\'re invited to join "${widget.party.title}"!\n\n'
          'Date: ${DateFormat('MMM dd, yyyy • hh:mm a').format(widget.party.dateTime)}\n'
          'Invite Code: ${widget.party.inviteCode}\n\n'
          'Tap the button below to join!';

      await _sendDirectInvite(user, inviteMessage);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${user.displayName}!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error sending invite: $e');
      _invitedUserIds.remove(user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingInvite = false;
      });
    }
  }

  Future<void> _sendDirectInvite(UserProfile user, String message) async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) return;

      // Create a direct message chat group between current user and invited user
      // Check if chat group already exists
      final firestore = FirebaseFirestore.instance;
      final chatGroupsSnapshot = await firestore
          .collection('chat_groups')
          .where('memberIds', arrayContains: currentUser.id)
          .get();

      ChatGroup? existingGroup;
      for (var doc in chatGroupsSnapshot.docs) {
        final data = doc.data();
        final memberIds = List<String>.from(data['memberIds'] ?? []);
        if (memberIds.contains(user.id) && memberIds.length == 2) {
          existingGroup = ChatGroup(
            id: doc.id,
            name: user.displayName,
            groupPhotoUrl: user.profileImageUrl ?? '',
            memberIds: memberIds,
            lastMessage: message,
            lastMessageTime: DateTime.now(),
            unreadCount: 0,
            isActive: true,
          );
          break;
        }
      }

      String groupId;
      if (existingGroup != null) {
        groupId = existingGroup.id;
      } else {
        // Create new direct message group
        final groupRef = await firestore.collection('chat_groups').add({
          'name': user.displayName,
          'groupPhotoUrl': user.profileImageUrl ?? '',
          'memberIds': [currentUser.id, user.id],
          'lastMessage': message,
          'lastMessageTime': Timestamp.now(),
          'unreadCount': 0,
          'isActive': true,
          'createdAt': Timestamp.now(),
        });
        groupId = groupRef.id;
      }

      // Send invite message with party data
      await firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': currentUser.id,
        'senderName': currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : 'Anonymous',
        'text': message,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'type': 'party_invite',
        'partyId': widget.party.id,
        'partyTitle': widget.party.title,
        'partyDate': widget.party.dateTime.toIso8601String(),
        'inviteCode': widget.party.inviteCode,
      });

      // Update chat group last message
      await firestore.collection('chat_groups').doc(groupId).update({
        'lastMessage': message,
        'lastMessageTime': Timestamp.now(),
      });
    } catch (e) {
      print('Error sending direct invite: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Invite Friends',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Party Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Party Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.party.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a')
                            .format(widget.party.dateTime),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.vpn_key,
                          size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Invite Code: ${widget.party.inviteCode}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.colors.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          // Copy invite code to clipboard
                          // You can add clipboard functionality here
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recommended Friends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingUsers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recommendedUsers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No users available to invite',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recommendedUsers.length,
                itemBuilder: (context, index) {
                  final user = _recommendedUsers[index];
                  final isInvited = _invitedUserIds.contains(user.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isInvited
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: user.profileImageUrl != null &&
                                  user.profileImageUrl!.isNotEmpty
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                          child: user.profileImageUrl == null ||
                                  user.profileImageUrl!.isEmpty
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 18,
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
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              if (user.isVerified)
                                Row(
                                  children: [
                                    Icon(Icons.verified,
                                        size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (isInvited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check,
                                    size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  'Invited',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: _isSendingInvite
                                ? null
                                : () => _sendInvite(user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.colors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: _isSendingInvite &&
                                    _invitedUserIds.contains(user.id)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text('Invite'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            // Skip button
            Center(
              child: TextButton(
                onPressed: () {
                  // Navigate to home screen
                  context.go('/');
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

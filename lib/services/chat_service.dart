import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_group.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class ChatService extends ChangeNotifier {
  UserProfile? get currentUser => _authService.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  List<ChatGroup> _chatGroups = [];
  List<Message> _messages = [];
  String _searchQuery = '';
  StreamSubscription<List<ChatGroup>>? _chatGroupsSubscription;
  StreamSubscription<List<Message>>? _messagesSubscription;
  int _retryCount = 0;
  static const int _maxRetries = 5;

  List<ChatGroup> get chatGroups => _chatGroups;
  List<Message> get messages => _messages;
  String get searchQuery => _searchQuery;

  // Filtered chat groups based on search
  List<ChatGroup> get filteredChatGroups {
    final Iterable<ChatGroup> activeGroups =
        _chatGroups.where((g) => g.isActive);
    if (_searchQuery.isEmpty) return activeGroups.toList();
    return activeGroups
        .where((group) =>
            group.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            group.lastMessage
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<ChatGroup> get archivedChatGroups =>
      _chatGroups.where((g) => !g.isActive).toList();

  // Initialize Firebase listeners
  void initializeFirebase() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        print(
            'ChatService: No current user found, retrying in 1 second... (attempt $_retryCount/$_maxRetries)');
        // Retry after a short delay to allow auth to initialize
        Future.delayed(const Duration(seconds: 1), () {
          initializeFirebase();
        });
      } else {
        print('ChatService: Max retries reached, giving up on initialization');
      }
      return;
    }

    print('ChatService: Initializing Firebase for user: ${currentUser.id}');
    _retryCount = 0; // Reset retry count on success
    _setupChatGroupsListener(currentUser.id);
    
    // Migrate existing chat groups without unreadByUser field
    _migrateUnreadByUserField(currentUser.id);
  }

  // Migrate existing chat groups to have unreadByUser field
  Future<void> _migrateUnreadByUserField(String userId) async {
    try {
      final groupsSnapshot = await _firestore
          .collection('chat_groups')
          .where('memberIds', arrayContains: userId)
          .get();

      for (var groupDoc in groupsSnapshot.docs) {
        final data = groupDoc.data();
        
        // Check if unreadByUser field exists
        if (!data.containsKey('unreadByUser') || data['unreadByUser'] == null) {
          print('Migrating chat group ${groupDoc.id} to add unreadByUser field');
          
          // Get all messages to calculate unread counts
          final messagesSnapshot = await _firestore
              .collection('chat_groups')
              .doc(groupDoc.id)
              .collection('messages')
              .get();
          
          // Initialize unreadByUser for all members
          final memberIds = List<String>.from(data['memberIds'] ?? []);
          final unreadByUser = <String, int>{};
          
          for (final memberId in memberIds) {
            int unreadCount = 0;
            for (var msgDoc in messagesSnapshot.docs) {
              final msgData = msgDoc.data();
              final readBy = List<String>.from(msgData['readBy'] as List<dynamic>? ?? []);
              final isRead = msgData['isRead'] as bool? ?? false;
              
              // Count unread messages for this member
              if (!readBy.contains(memberId) && !isRead) {
                unreadCount++;
              }
            }
            unreadByUser[memberId] = unreadCount;
          }
          
          // Update the chat group with unreadByUser field
          await _firestore
              .collection('chat_groups')
              .doc(groupDoc.id)
              .update({
            'unreadByUser': unreadByUser,
          });
          
          print('Successfully migrated chat group ${groupDoc.id}');
        }
      }
    } catch (e) {
      print('Error migrating unreadByUser field: $e');
    }
  }

  // Manually refresh chat groups (useful for testing)
  Future<void> refreshChatGroups() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    print('Manually refreshing chat groups for user: ${currentUser.id}');
    _setupChatGroupsListener(currentUser.id);
  }

  // Test method to create a chat group manually
  Future<void> createTestChatGroup() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    try {
      final chatGroupData = {
        'partyId': 'test-party-${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Test Party Chat',
        'groupPhotoUrl': '',
        'memberIds': [currentUser.id],
        'lastMessage': 'Welcome to the test chat! 🎉',
        'lastMessageTime': Timestamp.now(),
        'unreadCount': 0,
        'unreadByUser': {currentUser.id: 0},
        'isActive': true,
        'createdAt': Timestamp.now(),
        'createdBy': currentUser.id,
        'hostUserId': currentUser.id,
        'hostName': currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : 'Test User',
      };

      final chatGroupRef =
          await _firestore.collection('chat_groups').add(chatGroupData);
      print('Created test chat group with ID: ${chatGroupRef.id}');

      // Add welcome message
      await _firestore
          .collection('chat_groups')
          .doc(chatGroupRef.id)
          .collection('messages')
          .add({
        'senderId': currentUser.id,
        'senderName': currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : 'Test User',
        'text': 'Welcome to the test chat! 🎉',
        'timestamp': Timestamp.now(),
        'readBy': [currentUser.id],
      });
      print('Added welcome message to test chat group');
    } catch (e) {
      print('Error creating test chat group: $e');
    }
  }

  void _setupChatGroupsListener(String userId) {
    print('Setting up chat groups listener for user: $userId');
    _chatGroupsSubscription?.cancel();
    _chatGroupsSubscription = _firestore
        .collection('chat_groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
                final Map<String, dynamic>? unreadMapRaw =
                  data['unreadByUser'] as Map<String, dynamic>?;
                final currentUserId = _authService.currentUser?.id;
                final Map<String, int>? unreadByUser = unreadMapRaw
                  ?.map((k, v) => MapEntry(k, (v as num).toInt()));
                final int userUnread = currentUserId != null
                  ? (unreadByUser?[currentUserId] ?? 0)
                  : 0;

                return ChatGroup(
                id: doc.id,
                name: data['name'] ?? 'Chat',
                groupPhotoUrl: data['groupPhotoUrl'] ?? '',
                memberIds: List<String>.from(data['memberIds'] ?? []),
                lastMessage: data['lastMessage'] ?? '',
                lastMessageTime:
                  (data['lastMessageTime'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                unreadCount: userUnread,
                unreadByUser: unreadByUser,
                isActive: data['isActive'] ?? true,
                hostUserId: data['hostUserId'] as String?,
                hostName: data['hostName'] as String?,
                partyId: data['partyId'] as String?,
                );
            }).toList())
        .listen((chatGroups) {
      print('Chat groups updated: ${chatGroups.length} groups found');
      // Sort by lastMessageTime ascending (oldest first, newest last)
      _chatGroups = chatGroups
        ..sort((a, b) => a.lastMessageTime.compareTo(b.lastMessageTime));
      notifyListeners();
    });
  }

  void _setupMessagesListener(String groupId) {
    _messagesSubscription?.cancel();
    
    // First, try to load messages from local cache
    _loadMessagesFromCache(groupId).then((cachedMessages) {
      if (cachedMessages.isNotEmpty) {
        _messages = cachedMessages;
        notifyListeners();
        print('Loaded ${cachedMessages.length} messages from cache for group $groupId');
      }

      // Then listen for new messages from Firestore
      _messagesSubscription = _firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                return Message(
                  id: doc.id,
                  chatGroupId: groupId,
                  senderId: data['senderId'] ?? '',
                  senderName: data['senderName'] ?? '',
                  text: data['text'] ?? '',
                  timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  readBy: List<String>.from(data['readBy'] as List<dynamic>? ?? []),
                  type: data['type'] as String?,
                  partyId: data['partyId'] as String?,
                  partyTitle: data['partyTitle'] as String?,
                  inviteCode: data['inviteCode'] as String?,
                );
              }).toList())
          .listen((messages) {
        // Update messages and save to cache
        _messages = messages;
        _saveMessagesToCache(groupId, messages);
        notifyListeners();
      });
    });
  }

  // Save messages to shared preferences
  Future<void> _saveMessagesToCache(String groupId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_messages_$groupId';
      final List<Map<String, dynamic>> messagesJson = messages.map((m) => {
        'id': m.id,
        'chatGroupId': m.chatGroupId,
        'senderId': m.senderId,
        'senderName': m.senderName,
        'text': m.text,
        'timestamp': m.timestamp.toIso8601String(),
        'readBy': m.readBy,
        'type': m.type,
        'partyId': m.partyId,
        'partyTitle': m.partyTitle,
        'inviteCode': m.inviteCode,
      }).toList();
      
      await prefs.setString(key, jsonEncode(messagesJson));
    } catch (e) {
      print('Error saving messages to cache: $e');
    }
  }

  // Load messages from shared preferences
  Future<List<Message>> _loadMessagesFromCache(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_messages_$groupId';
      final jsonString = prefs.getString(key);
      
      if (jsonString == null) return [];
      
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((data) => Message(
        id: data['id'],
        chatGroupId: data['chatGroupId'],
        senderId: data['senderId'],
        senderName: data['senderName'],
        text: data['text'],
        timestamp: DateTime.parse(data['timestamp']),
        readBy: List<String>.from(data['readBy'] as List<dynamic>? ?? []),
        type: data['type'],
        partyId: data['partyId'],
        partyTitle: data['partyTitle'],
        inviteCode: data['inviteCode'],
      )).toList();
    } catch (e) {
      print('Error loading messages from cache: $e');
      return [];
    }
  }

  // Create a chat group for a party
  Future<String?> createPartyChatGroup({
    required String partyId,
    required String partyTitle,
    required String hostUserId,
    required String hostName,
    required List<String> attendeeUserIds,
  }) async {
    try {
      final chatGroupData = {
        'partyId': partyId,
        'name': partyTitle,
        'groupPhotoUrl': '',
        'memberIds': attendeeUserIds,
        'lastMessage': 'Welcome to the party chat! 🎉',
        'lastMessageTime': Timestamp.now(),
        'unreadCount': 0,
        'unreadByUser': {for (final id in attendeeUserIds) id: 0},
        'isActive': true,
        'createdAt': Timestamp.now(),
        'createdBy': hostUserId,
      };

      final docRef =
          await _firestore.collection('chat_groups').add(chatGroupData);

      // Add welcome message
      await _firestore
          .collection('chat_groups')
          .doc(docRef.id)
          .collection('messages')
          .add({
        'senderId': hostUserId,
        'senderName': hostName,
        'text': 'Welcome to the party chat! 🎉',
        'timestamp': Timestamp.now(),
        'readBy': [hostUserId],
      });

      return docRef.id;
    } catch (e) {
      print('Error creating party chat group: $e');
      return null;
    }
  }

  // Add user to existing chat group
  Future<void> addUserToChatGroup({
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    try {
      await _firestore.collection('chat_groups').doc(groupId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'unreadByUser.$userId': 0,
      });

      // Add welcome message for the new user
      await _firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'text': '$userName joined the chat! 👋',
        'timestamp': Timestamp.now(),
        'readBy': [],
      });
    } catch (e) {
      print('Error adding user to chat group: $e');
    }
  }

  // Get chat group for a party
  Future<ChatGroup?> getChatGroupForParty(String partyId) async {
    try {
        final snapshot = await _firestore
          .collection('chat_groups')
          .where('partyId', isEqualTo: partyId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();

      final Map<String, dynamic>? unreadMapRaw =
          data['unreadByUser'] as Map<String, dynamic>?;
      final Map<String, int>? unreadByUser = unreadMapRaw
          ?.map((k, v) => MapEntry(k, (v as num).toInt()));
      final currentUserId = _authService.currentUser?.id;
      final int userUnread = currentUserId != null
          ? (unreadByUser?[currentUserId] ?? 0)
          : 0;

      return ChatGroup(
        id: doc.id,
        name: data['name'] ?? 'Chat',
        groupPhotoUrl: data['groupPhotoUrl'] ?? '',
        memberIds: List<String>.from(data['memberIds'] ?? []),
        lastMessage: data['lastMessage'] ?? '',
        lastMessageTime:
            (data['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        unreadCount: userUnread,
        unreadByUser: unreadByUser,
        isActive: data['isActive'] ?? true,
        partyId: data['partyId'] as String?,
      );
    } catch (e) {
      print('Error getting chat group for party: $e');
      return null;
    }
  }

  // Load messages for a specific group
  void loadMessagesForGroup(String groupId) {
    _setupMessagesListener(groupId);
  }

  // Send a message
  Future<void> sendMessage({
    required String groupId,
    required String text,
  }) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final messageData = {
        'senderId': currentUser.id,
        'senderName': currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : 'Anonymous',
        'text': text,
        'timestamp': Timestamp.now(),
        'readBy': [currentUser.id], // Sender has read it
      };

      final groupRef = _firestore.collection('chat_groups').doc(groupId);

      await groupRef.collection('messages').add(messageData);

      // Atomically bump unread for all members except sender
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(groupRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final List<dynamic> members = data['memberIds'] ?? [];
        final Map<String, dynamic> unreadRaw =
            Map<String, dynamic>.from(data['unreadByUser'] ?? {});

        for (final m in members) {
          final id = m.toString();
          if (id == currentUser.id) {
            unreadRaw[id] = 0; // sender has no unread
          } else {
            final prev = (unreadRaw[id] ?? 0) as num;
            unreadRaw[id] = prev.toInt() + 1;
          }
        }

        txn.update(groupRef, {
          'lastMessage': text,
          'lastMessageTime': Timestamp.now(),
          'unreadByUser': unreadRaw,
        });
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  // Send a system message
  Future<void> sendSystemMessage({
    required String groupId,
    required String text,
  }) async {
    try {
      final messageData = {
        'senderId': 'system',
        'senderName': 'System',
        'text': text,
        'timestamp': Timestamp.now(),
        'readBy': [],
      };

      await _firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .add(messageData);

      // Update the chat group's last message
      await _firestore.collection('chat_groups').doc(groupId).update({
        'lastMessage': text,
        'lastMessageTime': Timestamp.now(),
      });
    } catch (e) {
      print('Error sending system message: $e');
    }
  }

  // Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // Mark group as read
  Future<void> markGroupAsRead(String groupId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final index = _chatGroups.indexWhere((group) => group.id == groupId);
    if (index != -1) {
      final updatedMap = Map<String, int>.from(
          _chatGroups[index].unreadByUser ?? <String, int>{});
      updatedMap[currentUser.id] = 0;
      _chatGroups[index] =
          _chatGroups[index].copyWith(unreadCount: 0, unreadByUser: updatedMap);
      notifyListeners();
    }

    // Persist to Firestore
    try {
      await _firestore.collection('chat_groups').doc(groupId).update({
        'unreadByUser.${currentUser.id}': 0,
      });

      // Mark all messages from other users as read
      await _markAllMessagesAsRead(groupId, currentUser.id);
    } catch (e) {
      print('Error marking group as read: $e');
    }
  }

  // Mark all messages in a group as read for current user
  Future<void> _markAllMessagesAsRead(String groupId, String userId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        // Handle messages that might not have readBy field yet
        if (data.containsKey('readBy')) {
          final readBy = List<String>.from(data['readBy'] as List<dynamic>? ?? []);
          if (!readBy.contains(userId)) {
            readBy.add(userId);
            batch.update(doc.reference, {'readBy': readBy});
          }
        } else {
          // Message doesn't have readBy field - create it with this user
          batch.update(doc.reference, {'readBy': [userId]});
        }
      }
      await batch.commit();

      // Update local messages
      final messagesInGroup = _messages.where((m) => m.chatGroupId == groupId).toList();
      for (var msg in messagesInGroup) {
        if (!msg.readBy.contains(userId)) {
          final index = _messages.indexWhere((m) => m.id == msg.id);
          if (index != -1) {
            final updatedReadBy = [...msg.readBy, userId];
            _messages[index] = _messages[index].copyWith(readBy: updatedReadBy);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error marking all messages as read: $e');
    }
  }

  // Mark a single message as read
  Future<void> markMessageAsRead(String groupId, String messageId, String userId) async {
    try {
      final docRef = _firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .doc(messageId);
      
      final doc = await docRef.get();
      final data = doc.data();
      
      List<String> readBy = [];
      if (data != null && data.containsKey('readBy')) {
        readBy = List<String>.from(data['readBy'] as List<dynamic>? ?? []);
      }
      
      if (!readBy.contains(userId)) {
        readBy.add(userId);
        await docRef.update({'readBy': readBy});
      }

      // Update local state
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(readBy: readBy);
        notifyListeners();
      }
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  // Archive group
  void archiveGroup(String groupId) {
    _firestore.collection('chat_groups').doc(groupId).update({
      'isActive': false,
    });
  }

  // Unarchive group
  void unarchiveGroup(String groupId) {
    _firestore.collection('chat_groups').doc(groupId).update({
      'isActive': true,
    });
  }

  // Update chat group members
  Future<void> updateChatGroupMembers(
      String groupId, List<String> memberIds) async {
    try {
      await _firestore.collection('chat_groups').doc(groupId).update({
        'memberIds': memberIds,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating chat group members: $e');
      throw Exception('Failed to update chat group members: $e');
    }
  }

  // Permanently delete group and all its messages
  Future<void> permanentlyDeleteGroup(String groupId) async {
    try {
      // Delete all messages in the group
      final messagesSnapshot = await _firestore
          .collection('chat_groups')
          .doc(groupId)
          .collection('messages')
          .get();

      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the group itself
      await _firestore.collection('chat_groups').doc(groupId).delete();
    } catch (e) {
      print('Error permanently deleting group: $e');
    }
  }

  // Get messages for a specific group
  List<Message> getMessagesForGroup(String chatGroupId) {
    return _messages
        .where((message) => message.chatGroupId == chatGroupId)
        .toList();
  }

  @override
  void dispose() {
    _chatGroupsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}

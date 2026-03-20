import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/config/firebase_config.dart';
import 'package:bunny/utils/invite_code_generator.dart';
import 'package:bunny/services/notification_service.dart';
import 'package:bunny/services/user_service.dart';

class PartyService {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final NotificationService _notificationService;
  final UserService _userService;

  PartyService({
    required NotificationService notificationService,
    required UserService userService,
  })  : _notificationService = notificationService,
        _userService = userService;

  // Get parties collection reference
  CollectionReference<Map<String, dynamic>> get _partiesCollection =>
      _firestore.collection('parties');
  CollectionReference<Map<String, dynamic>> get _applicationsCollection =>
      _firestore.collection('party_applications');

  // Get current user ID for mock data (unused)

  // Ensure sample users exist in database
  Future<void> _ensureSampleUsers() async {
    final sampleUsers = [
      {
        'id': 'sample-host-1',
        'displayName': 'Alex Johnson',
        'email': 'alex@example.com',
        'profileImageUrl':
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100&h=100&fit=crop&crop=face'
      },
      {
        'id': 'sample-host-2',
        'displayName': 'Sarah Chen',
        'email': 'sarah@example.com',
        'profileImageUrl':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop&crop=face'
      },
      {
        'id': 'sample-host-3',
        'displayName': 'Mike Rodriguez',
        'email': 'mike@example.com',
        'profileImageUrl':
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face'
      },
      {
        'id': 'sample-host-4',
        'displayName': 'Emma Wilson',
        'email': 'emma@example.com',
        'profileImageUrl':
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop&crop=face'
      },
      {
        'id': 'sample-host-5',
        'displayName': 'David Kim',
        'email': 'david@example.com',
        'profileImageUrl':
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop&crop=face'
      },
    ];

    for (final user in sampleUsers) {
      final docRef = _firestore.collection('users').doc(user['id']);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'id': user['id'],
          'displayName': user['displayName'],
          'email': user['email'],
          'profileImageUrl': user['profileImageUrl'],
          'createdAt': Timestamp.now(),
        });
      }
    }
  }

  // Mock data as fallback
  List<Party> get _mockParties => <Party>[
        Party(
          id: 'p1',
          clubId: '1',
          hostUserId: 'sample-host-1',
          hostName: 'Alex Johnson',
          title: 'EDM Night',
          dateTime: DateTime.now().add(const Duration(hours: 3)),
          capacity: 80,
          attendeeUserIds: <String>[
            'sample-host-1',
            'sample-user-1',
            'sample-user-2'
          ],
          description: 'High-energy EDM music with amazing light show!',
          preferredGender: 'Any',
          inviteCode: 'A1B2',
        ),
        Party(
          id: 'p2',
          clubId: '2',
          hostUserId: 'sample-host-2',
          hostName: 'Sarah Chen',
          title: 'Cocktail Social',
          dateTime: DateTime.now().add(const Duration(hours: 2, minutes: 30)),
          capacity: 40,
          attendeeUserIds: <String>['sample-host-2', 'sample-user-3'],
          description: 'Sophisticated cocktail evening with jazz music',
          preferredGender: 'Mixed',
          inviteCode: 'C3D4',
        ),
        Party(
          id: 'p3',
          clubId: '3',
          hostUserId: 'sample-host-3',
          hostName: 'Mike Rodriguez',
          title: 'Rooftop Sunset',
          dateTime: DateTime.now().add(const Duration(hours: 4)),
          capacity: 60,
          attendeeUserIds: <String>['sample-host-3'],
          description: 'Beautiful sunset views with chill vibes',
          preferredGender: 'Any',
          inviteCode: 'E5F6',
        ),
        Party(
          id: 'p4',
          clubId: '1',
          hostUserId: 'sample-host-4',
          hostName: 'Emma Wilson',
          title: 'Techno Underground',
          dateTime: DateTime.now().add(const Duration(hours: 6)),
          capacity: 100,
          attendeeUserIds: <String>[
            'sample-host-4',
            'sample-user-4',
            'sample-user-5',
            'sample-user-6'
          ],
          description: 'Underground techno beats in an intimate setting',
          preferredGender: 'Any',
          inviteCode: 'G7H8',
        ),
        Party(
          id: 'p5',
          clubId: '2',
          hostUserId: 'sample-host-5',
          hostName: 'David Kim',
          title: 'Wine & Jazz',
          dateTime: DateTime.now().add(const Duration(hours: 5, minutes: 15)),
          capacity: 30,
          attendeeUserIds: <String>['sample-host-5', 'sample-user-7'],
          description: 'Premium wine tasting with live jazz performance',
          preferredGender: 'Mixed',
          inviteCode: 'I9J0',
        ),
        Party(
          id: 'p6',
          clubId: '4',
          hostUserId: 'sample-host-6',
          hostName: 'Lisa Thompson',
          title: 'Pool Party',
          dateTime: DateTime.now().add(const Duration(hours: 7)),
          capacity: 120,
          attendeeUserIds: <String>[
            'sample-host-6',
            'sample-user-8',
            'sample-user-9',
            'sample-user-10',
            'sample-user-11'
          ],
          description: 'Poolside party with tropical drinks and DJ sets',
          preferredGender: 'Any',
          inviteCode: 'K1L2',
        ),
        Party(
          id: 'p7',
          clubId: '5',
          hostUserId: 'sample-host-7',
          hostName: 'James Parker',
          title: 'Karaoke Night',
          dateTime: DateTime.now().add(const Duration(hours: 8, minutes: 30)),
          capacity: 50,
          attendeeUserIds: <String>[
            'sample-host-7',
            'sample-user-12',
            'sample-user-13'
          ],
          description: 'Sing your heart out with friends and strangers',
          preferredGender: 'Any',
          inviteCode: 'M3N4',
        ),
        Party(
          id: 'p8',
          clubId: '1',
          hostUserId: 'sample-host-8',
          hostName: 'Maria Garcia',
          title: 'House Music Vibes',
          dateTime: DateTime.now().add(const Duration(hours: 9)),
          capacity: 90,
          attendeeUserIds: <String>[
            'sample-host-8',
            'sample-user-14',
            'sample-user-15',
            'sample-user-16'
          ],
          description: 'Deep house and progressive beats all night long',
          preferredGender: 'Any',
          inviteCode: 'O5P6',
        ),
      ];

  // List parties by club
  Future<List<Party>> listByClub(String clubId) async {
    try {
      final QuerySnapshot snapshot = await _partiesCollection
          .where('clubId', isEqualTo: clubId)
          .orderBy('dateTime')
          .get();

      final List<Party> parties = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Party.fromJson(data);
      }).toList();

      // Check if any parties need invite codes and update them
      await _ensurePartiesHaveInviteCodes(parties);

      return parties;
    } catch (e) {
      print('Error listing parties by club: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      return _mockParties.where((party) => party.clubId == clubId).toList();
    }
  }

  // Get party by id
  Future<Party?> getById(String partyId) async {
    try {
      final DocumentSnapshot doc = await _partiesCollection.doc(partyId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      final party = Party.fromJson(data);

      // Check if party needs invite code and update it
      if (party.inviteCode.isEmpty) {
        await _ensurePartiesHaveInviteCodes([party]);
        // Re-fetch the updated party
        final updatedDoc = await _partiesCollection.doc(partyId).get();
        if (updatedDoc.exists) {
          final updatedData = updatedDoc.data() as Map<String, dynamic>;
          updatedData['id'] = updatedDoc.id;
          return Party.fromJson(updatedData);
        }
      }

      return party;
    } catch (e) {
      // Fallback to mock data
      try {
        return _mockParties.firstWhere((p) => p.id == partyId);
      } catch (_) {
        return null;
      }
    }
  }

  // Applications
  Future<List<Map<String, dynamic>>> listApplications(String partyId) async {
    try {
      final snapshot = await _applicationsCollection
          .where('partyId', isEqualTo: partyId)
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs
          .map((d) => {
                'id': d.id,
                ...d.data(),
              })
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getApplicationForUser(
      {required String partyId, required String userId}) async {
    try {
      final snapshot = await _applicationsCollection
          .where('partyId', isEqualTo: partyId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final d = snapshot.docs.first;
      return {'id': d.id, ...d.data()};
    } catch (e) {
      return null;
    }
  }

  Future<String?> createJoinApplication(
      {required String partyId, required String userId}) async {
    try {
      // If already attending, no need to apply
      final party = await getById(partyId);
      if (party != null && party.attendeeUserIds.contains(userId)) {
        return null;
      }
      // If an application already exists, return it
      final existing =
          await getApplicationForUser(partyId: partyId, userId: userId);
      if (existing != null) return existing['id'] as String;

      final ref = await _applicationsCollection.add({
        'partyId': partyId,
        'userId': userId,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      // Send notification to party host
      try {
        final party = await getById(partyId);
        if (party != null && party.hostUserId != null) {
          final userProfile = await _userService.getUserProfile(userId);
          final userName = userProfile?.displayName ?? 'Someone';

          await _notificationService.sendNotificationToUser(
            targetUserId: party.hostUserId,
            title: 'New Join Request',
            body: '$userName wants to join "${party.title}"',
            type: 'participant_request',
            relatedId: partyId,
          );
        }
      } catch (e) {
        print('Error sending application notification: $e');
      }

      return ref.id;
    } catch (e) {
      return null;
    }
  }

  Future<void> approveApplication({required String applicationId}) async {
    final doc = await _applicationsCollection.doc(applicationId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final String partyId = data['partyId'] as String;
    final String userId = data['userId'] as String;

    // Add to attendees and update application
    await _firestore.runTransaction((tx) async {
      final partyRef = _partiesCollection.doc(partyId);
      final partyDoc = await tx.get(partyRef);
      if (!partyDoc.exists) return;
      final partyData = partyDoc.data() as Map<String, dynamic>;
      final List<dynamic> attendees =
          (partyData['attendeeUserIds'] as List<dynamic>? ?? []).toList();
      if (!attendees.contains(userId)) attendees.add(userId);
      tx.update(partyRef, {'attendeeUserIds': attendees});
      tx.update(
          _applicationsCollection.doc(applicationId), {'status': 'approved'});
    });

    // Create or update chat group for the party
    await _createOrUpdatePartyChat(partyId, userId);
  }

  Future<void> _createOrUpdatePartyChat(
      String partyId, String newUserId) async {
    try {
      print(
          'Creating/updating party chat for party: $partyId, new user: $newUserId');

      // Get party details
      final partyDoc = await _partiesCollection.doc(partyId).get();
      if (!partyDoc.exists) {
        print('Party document not found: $partyId');
        return;
      }

      final partyData = partyDoc.data()!;
      final List<String> attendeeUserIds =
          List<String>.from(partyData['attendeeUserIds'] ?? []);
      print('Party attendees: $attendeeUserIds');

      // Check if chat group already exists
      final chatGroupsSnapshot = await _firestore
          .collection('chat_groups')
          .where('partyId', isEqualTo: partyId)
          .limit(1)
          .get();

      if (chatGroupsSnapshot.docs.isEmpty) {
        print('Creating new chat group for party: $partyId');
        // Create new chat group
        final chatGroupData = {
          'partyId': partyId,
          'name': partyData['title'] ?? 'Party Chat',
          'groupPhotoUrl': partyData['imageUrl'] ?? '',
          'memberIds': attendeeUserIds,
          'lastMessage': 'Welcome to the party chat! 🎉',
          'lastMessageTime': Timestamp.now(),
          'unreadCount': 0,
          'unreadByUser': {for (final id in attendeeUserIds) id: 0},
          'isActive': true,
          'createdAt': Timestamp.now(),
          'createdBy': partyData['hostUserId'],
          'hostUserId': partyData['hostUserId'],
          'hostName': partyData['hostName'],
        };

        final chatGroupRef =
            await _firestore.collection('chat_groups').add(chatGroupData);
        print('Created chat group with ID: ${chatGroupRef.id}');

        // Add welcome message
        await _firestore
            .collection('chat_groups')
            .doc(chatGroupRef.id)
            .collection('messages')
            .add({
          'senderId': partyData['hostUserId'],
          'senderName': partyData['hostName'] ?? 'Host',
          'text': 'Welcome to the party chat! 🎉',
          'timestamp': Timestamp.now(),
          'readBy': [partyData['hostUserId']],
        });
        print('Added welcome message to chat group');
      } else {
        print('Updating existing chat group for party: $partyId');
        // Add new user to existing chat group
        final chatGroupId = chatGroupsSnapshot.docs.first.id;
        final existingData = chatGroupsSnapshot.docs.first.data();

        // Initialize unreadByUser if it doesn't exist
        final Map<String, dynamic> unreadByUser =
            Map<String, dynamic>.from(existingData['unreadByUser'] ?? {});
        if (!unreadByUser.containsKey(newUserId)) {
          unreadByUser[newUserId] = 0;
        }
        await _firestore.collection('chat_groups').doc(chatGroupId).update({
          'memberIds': attendeeUserIds,
          'unreadByUser': unreadByUser,
        });
        print('Updated chat group members: $attendeeUserIds');

        // Add welcome message for the new user
        await _firestore
            .collection('chat_groups')
            .doc(chatGroupId)
            .collection('messages')
            .add({
          'senderId': 'system',
          'senderName': 'System',
          'text': 'A new member joined the party! 👋',
          'timestamp': Timestamp.now(),
          'readBy': [],
        });
        print('Added new member message to chat group');
      }
    } catch (e) {
      print('Error creating/updating party chat: $e');
    }
  }

  Future<void> rejectApplication({required String applicationId}) async {
    await _applicationsCollection
        .doc(applicationId)
        .update({'status': 'rejected'});
  }

  // List parties by user (as host or attendee)
  Future<List<Party>> listByUser(String userId) async {
    print('\n🔍 listByUser called for userId: $userId');
    try {
      // Get parties where user is in attendeeUserIds
      print('   Querying attendee parties...');
      final QuerySnapshot snapshot = await _partiesCollection
          .where('attendeeUserIds', arrayContains: userId)
          .get();

      print('   Found ${snapshot.docs.length} attendee parties');
      final List<Party> attendeeParties = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Party.fromJson(data);
      }).toList();

      // Also get parties where user is host
      print('   Querying host parties...');
      final QuerySnapshot hostSnapshot =
          await _partiesCollection.where('hostUserId', isEqualTo: userId).get();

      print('   Found ${hostSnapshot.docs.length} host parties');
      final List<Party> hostParties = hostSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Party.fromJson(data);
      }).toList();

      // Combine and deduplicate parties (in case user is both host and attendee)
      final Map<String, Party> partyMap = {};

      // Add attendee parties
      for (final party in attendeeParties) {
        partyMap[party.id] = party;
      }

      // Add host parties (will overwrite if duplicate)
      for (final party in hostParties) {
        partyMap[party.id] = party;
      }

      // Convert back to list and sort by date
      final List<Party> allParties = partyMap.values.toList();
      allParties.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      print('   ✅ Total unique parties: ${allParties.length}');

      // Check if any parties need invite codes and update them
      await _ensurePartiesHaveInviteCodes(allParties);

      return allParties;
    } catch (e, stackTrace) {
      print('❌ Error listing parties by user: $e');
      print('Stack trace: $stackTrace');
      print('Falling back to mock data...');
      // Fallback to mock data
      return _mockParties
          .where((party) =>
              party.hostUserId == userId ||
              party.attendeeUserIds.contains(userId))
          .toList();
    }
  }

  // Get next upcoming party for a club
  Future<Party?> nextUpcomingForClub(String clubId) async {
    try {
      final DateTime now = DateTime.now();
      final QuerySnapshot snapshot = await _partiesCollection
          .where('clubId', isEqualTo: clubId)
          .where('dateTime', isGreaterThan: now)
          .orderBy('dateTime')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        data['id'] = snapshot.docs.first.id;
        return Party.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting next upcoming party: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      final now = DateTime.now();
      final upcomingParties = _mockParties
          .where(
              (party) => party.clubId == clubId && party.dateTime.isAfter(now))
          .toList();
      if (upcomingParties.isNotEmpty) {
        upcomingParties.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        return upcomingParties.first;
      }
      return null;
    }
  }

  // Create a new party
  Future<Party> create({
    required String clubId,
    required String hostUserId,
    String? hostName,
    required String title,
    required DateTime dateTime,
    int capacity = 50,
    String? description,
    String? preferredGender,
    String? imageUrl,
    int? budgetPerHead,
    String? paymentMethod,
    List<String>? drinkingTags,
    String? reservationType,
    bool hasEntranceFee = false,
    int entranceFeeAmount = 0,
  }) async {
    try {
      // Generate unique invite code
      String inviteCode;
      bool isUnique = false;
      int attempts = 0;

      do {
        inviteCode = InviteCodeGenerator.generateInviteCode();
        // Check if invite code already exists
        final existingParty = await _partiesCollection
            .where('inviteCode', isEqualTo: inviteCode)
            .limit(1)
            .get();
        isUnique = existingParty.docs.isEmpty;
        attempts++;
      } while (!isUnique && attempts < 10);

      if (!isUnique) {
        throw Exception(
            'Failed to generate unique invite code after 10 attempts');
      }

      final Map<String, dynamic> partyData = {
        'clubId': clubId,
        'hostUserId': hostUserId,
        'hostName': hostName,
        'title': title,
        'dateTime': Timestamp.fromDate(dateTime),
        'capacity': capacity,
        'attendeeUserIds': <String>[
          hostUserId
        ], // Host is automatically an attendee
        'description': description ?? '',
        'preferredGender': preferredGender ?? 'Any',
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
        'status': 'active',
        'paymentMethod': paymentMethod ?? '',
        'drinkingTags': drinkingTags ?? <String>[],
        'reservationType': reservationType ?? '',
        'inviteCode': inviteCode,
        'hasEntranceFee': hasEntranceFee,
        'entranceFeeAmount': entranceFeeAmount,
      };

      if (budgetPerHead != null) {
        partyData['budgetPerHead'] = budgetPerHead;
      }

      final DocumentReference docRef = await _partiesCollection.add(partyData);

      return Party(
        id: docRef.id,
        clubId: clubId,
        hostUserId: hostUserId,
        hostName: hostName,
        title: title,
        dateTime: dateTime,
        capacity: capacity,
        attendeeUserIds: <String>[hostUserId],
        description: description ?? '',
        preferredGender: preferredGender ?? 'Any',
        imageUrl: imageUrl,
        paymentMethod: paymentMethod ?? '',
        drinkingTags: drinkingTags ?? <String>[],
        reservationType: reservationType ?? '',
        inviteCode: inviteCode,
        hasEntranceFee: hasEntranceFee,
        entranceFeeAmount: entranceFeeAmount,
      );
    } catch (e) {
      print('Error creating party: $e');
      throw Exception('Failed to create party: $e');
    }
  }

  // Find party by invite code
  Future<Party?> getPartyByInviteCode(String inviteCode) async {
    try {
      final QuerySnapshot snapshot = await _partiesCollection
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        data['id'] = snapshot.docs.first.id;
        return Party.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error finding party by invite code: $e');
      return null;
    }
  }

  // Join party via invite code
  Future<Party?> joinViaInviteCode(
      {required String inviteCode, required String userId}) async {
    try {
      final party = await getPartyByInviteCode(inviteCode);
      if (party == null) {
        return null; // Party not found
      }

      // Check if user is already attending
      if (party.attendeeUserIds.contains(userId)) {
        return party; // Already attending
      }

      // Check if party is accepting requests
      if (!party.isAcceptingRequests) {
        throw Exception('This party is not accepting requests at the moment');
      }

      // Check if party is full
      if (party.isFull) {
        throw Exception('Party is full');
      }

      // Add user to attendees
      final updatedAttendees = [...party.attendeeUserIds, userId];
      await _partiesCollection.doc(party.id).update({
        'attendeeUserIds': updatedAttendees,
      });

      // Return updated party
      return party.copyWith(attendeeUserIds: updatedAttendees);
    } catch (e) {
      print('Error joining party via invite code: $e');
      throw Exception('Failed to join party: $e');
    }
  }

  // Join a party
  Future<Party?> join({required String partyId, required String userId}) async {
    try {
      final DocumentReference partyRef = _partiesCollection.doc(partyId);

      // Use transaction to ensure data consistency
      final Party? updatedParty =
          await _firestore.runTransaction<Party?>((transaction) async {
        final DocumentSnapshot partyDoc = await transaction.get(partyRef);

        if (!partyDoc.exists) return null;

        final data = partyDoc.data() as Map<String, dynamic>;
        final Party party = Party.fromJson({...data, 'id': partyDoc.id});

        // Check if party is accepting requests
        if (!party.isAcceptingRequests) {
          throw Exception('This party is not accepting requests at the moment');
        }

        // Check if party is full or user already joined
        if (party.isFull || party.attendeeUserIds.contains(userId)) {
          return party;
        }

        // Add user to attendees
        final List<String> updatedAttendees = <String>[
          ...party.attendeeUserIds,
          userId
        ];

        // Update the document
        transaction.update(partyRef, {'attendeeUserIds': updatedAttendees});

        // Return updated party
        return party.copyWith(attendeeUserIds: updatedAttendees);
      });

      return updatedParty;
    } catch (e) {
      print('Error joining party: $e');
      // Fallback to mock data
      final party = _mockParties.firstWhere((p) => p.id == partyId);
      if (party.isFull || party.attendeeUserIds.contains(userId)) {
        return party;
      }
      return party.copyWith(
        attendeeUserIds: <String>[...party.attendeeUserIds, userId],
      );
    }
  }

  // Leave a party
  Future<Party?> leave(
      {required String partyId, required String userId}) async {
    try {
      final DocumentReference partyRef = _partiesCollection.doc(partyId);

      final Party? updatedParty =
          await _firestore.runTransaction<Party?>((transaction) async {
        final DocumentSnapshot partyDoc = await transaction.get(partyRef);

        if (!partyDoc.exists) return null;

        final data = partyDoc.data() as Map<String, dynamic>;
        final Party party = Party.fromJson({...data, 'id': partyDoc.id});

        // Check if user is in attendees
        if (!party.attendeeUserIds.contains(userId)) {
          return party;
        }

        // Remove user from attendees
        final List<String> updatedAttendees =
            party.attendeeUserIds.where((id) => id != userId).toList();

        // Update the document
        transaction.update(partyRef, {'attendeeUserIds': updatedAttendees});

        // Return updated party
        return party.copyWith(attendeeUserIds: updatedAttendees);
      });

      return updatedParty;
    } catch (e) {
      print('Error leaving party: $e');
      // Fallback to mock data
      final party = _mockParties.firstWhere((p) => p.id == partyId);
      if (!party.attendeeUserIds.contains(userId)) {
        return party;
      }
      return party.copyWith(
        attendeeUserIds:
            party.attendeeUserIds.where((id) => id != userId).toList(),
      );
    }
  }

  // Update party details
  Future<void> updateParty(String partyId, Map<String, dynamic> updates) async {
    try {
      await _partiesCollection.doc(partyId).update(updates);
    } catch (e) {
      print('Error updating party: $e');
      throw Exception('Failed to update party: $e');
    }
  }

  // Cancel a party (host only)
  Future<void> cancelParty(String partyId) async {
    try {
      await _partiesCollection.doc(partyId).update({
        'isCancelled': true,
        'cancelledAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error cancelling party: $e');
      throw Exception('Failed to cancel party: $e');
    }
  }

  // Uncancel a party (host only)
  Future<void> uncancelParty(String partyId) async {
    try {
      await _partiesCollection.doc(partyId).update({
        'isCancelled': false,
        'cancelledAt': null,
      });
    } catch (e) {
      print('Error uncancelling party: $e');
      throw Exception('Failed to uncancel party: $e');
    }
  }

  // Delete a party
  Future<void> deleteParty(String partyId) async {
    try {
      await _partiesCollection.doc(partyId).delete();
    } catch (e) {
      print('Error deleting party: $e');
      throw Exception('Failed to delete party: $e');
    }
  }

  // Get upcoming parties
  Future<List<Party>> getUpcomingParties({int limit = 20}) async {
    try {
      final DateTime now = DateTime.now();
      final QuerySnapshot snapshot = await _partiesCollection
          .where('dateTime', isGreaterThan: now)
          .orderBy('dateTime')
          .limit(limit)
          .get();

      final List<Party> parties = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Party.fromJson(data);
      }).toList();

      // Check if any parties need invite codes and update them
      await _ensurePartiesHaveInviteCodes(parties);

      return parties;
    } catch (e) {
      print('Error getting upcoming parties: $e');
      print('Falling back to mock data...');

      // Ensure sample users exist before returning mock data
      await _ensureSampleUsers();

      // Fallback to mock data
      final now = DateTime.now();
      final upcomingParties =
          _mockParties.where((party) => party.dateTime.isAfter(now)).toList();
      upcomingParties.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (limit > 0) {
        return upcomingParties.take(limit).toList();
      }
      return upcomingParties;
    }
  }

  // Ensure all parties have invite codes
  Future<void> _ensurePartiesHaveInviteCodes(List<Party> parties) async {
    for (final party in parties) {
      if (party.inviteCode.isEmpty) {
        try {
          // Generate unique invite code
          String inviteCode;
          bool isUnique = false;
          int attempts = 0;

          do {
            inviteCode = InviteCodeGenerator.generateInviteCode();
            // Check if invite code already exists
            final existingParty = await _partiesCollection
                .where('inviteCode', isEqualTo: inviteCode)
                .limit(1)
                .get();
            isUnique = existingParty.docs.isEmpty;
            attempts++;
          } while (!isUnique && attempts < 10);

          if (isUnique) {
            // Update the party with the invite code
            await _partiesCollection.doc(party.id).update({
              'inviteCode': inviteCode,
            });
            print('Added invite code $inviteCode to party ${party.id}');
          }
        } catch (e) {
          print('Error adding invite code to party ${party.id}: $e');
        }
      }
    }
  }

  // Stream parties for real-time updates
  Stream<List<Party>> streamPartiesByClub(String clubId) {
    return _partiesCollection
        .where('clubId', isEqualTo: clubId)
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Party.fromJson(data);
            }).toList())
        .handleError((error) {
      print('Error streaming parties by club: $error');
      print('Falling back to mock data...');
      return _mockParties.where((party) => party.clubId == clubId).toList();
    });
  }

  // Stream user's parties for real-time updates
  Stream<List<Party>> streamUserParties(String userId) {
    return _partiesCollection
        .where('attendeeUserIds', arrayContains: userId)
        .orderBy('dateTime')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Party.fromJson(data);
            }).toList())
        .handleError((error) {
      print('Error streaming user parties: $error');
      print('Falling back to mock data...');
      return _mockParties
          .where((party) =>
              party.hostUserId == userId ||
              party.attendeeUserIds.contains(userId))
          .toList();
    });
  }

  // Add sample data for development
  Future<void> addSampleData() async {
    try {
      final DateTime now = DateTime.now();
      final List<Map<String, dynamic>> sampleParties = [
        {
          'clubId': '1', // Neon Pulse
          'hostUserId': 'sample-host-1',
          'title': 'EDM Night',
          'dateTime': now.add(const Duration(hours: 3)),
          'capacity': 80,
          'attendeeUserIds': [
            'sample-host-1',
            'sample-user-1',
            'sample-user-2'
          ],
          'description': 'High-energy EDM night with top DJs',
          'createdAt': now,
          'status': 'active',
        },
        {
          'clubId': '2', // Velvet Room
          'hostUserId': 'sample-host-2',
          'title': 'Cocktail Social',
          'dateTime': now.add(const Duration(hours: 2, minutes: 30)),
          'capacity': 40,
          'attendeeUserIds': ['sample-host-2', 'sample-user-3'],
          'description': 'Sophisticated cocktail evening',
          'createdAt': now,
          'status': 'active',
        },
        {
          'clubId': '3', // Skyline Lounge
          'hostUserId': 'sample-host-3',
          'title': 'Rooftop Sunset',
          'dateTime': now.add(const Duration(hours: 4)),
          'capacity': 60,
          'attendeeUserIds': ['sample-host-3'],
          'description': 'Sunset cocktails with city views',
          'createdAt': now,
          'status': 'active',
        },
      ];

      for (final partyData in sampleParties) {
        await _partiesCollection.add(partyData);
      }

      print('Sample parties added successfully');
    } catch (e) {
      print('Error adding sample parties: $e');
    }
  }

  // Get all parties (admin function)
  Future<List<Party>> getAllParties() async {
    try {
      final QuerySnapshot snapshot =
          await _partiesCollection.orderBy('dateTime', descending: true).get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Party.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all parties: $e');
    }
  }
}

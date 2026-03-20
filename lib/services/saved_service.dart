import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/models/club.dart';
import 'package:bunny/config/firebase_config.dart';

class SavedService {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  // Save a party for later
  Future<void> saveParty(String userId, String partyId) async {
    try {
      print('Saving party: userId=$userId, partyId=$partyId');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedParties')
          .doc(partyId)
          .set({
        'partyId': partyId,
        'savedAt': Timestamp.now(),
      });
      print('Party saved successfully');
    } catch (e) {
      print('Error saving party: $e');
      throw Exception('Failed to save party');
    }
  }

  // Remove a saved party
  Future<void> removeSavedParty(String userId, String partyId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedParties')
          .doc(partyId)
          .delete();
    } catch (e) {
      print('Error removing saved party: $e');
      throw Exception('Failed to remove saved party');
    }
  }

  // Get saved parties
  Future<List<Party>> getSavedParties(String userId) async {
    try {
      print('Getting saved parties for userId: $userId');
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedParties')
          .get();

      print('Found ${snapshot.docs.length} saved party references');
      final partyIds = snapshot.docs.map((doc) => doc.id).toList();
      print('Party IDs: $partyIds');
      final parties = <Party>[];

      for (final partyId in partyIds) {
        final partyDoc =
            await _firestore.collection('parties').doc(partyId).get();
        if (!partyDoc.exists) {
          print('Party not found: $partyId');
          continue;
        }

        final data = partyDoc.data()!;
        try {
          final partyJson = <String, dynamic>{
            // Required
            'id': partyDoc.id,
            'clubId': data['clubId'] ?? '',
            'hostUserId': data['hostUserId'] ?? '',
            'title': data['title'] ?? '(Untitled)',
            // dateTime may be Timestamp/int/string; fallback to now if missing
            'dateTime': data['dateTime'] ?? data['date'] ?? Timestamp.now(),

            // Optionals with defaults
            'attendeeUserIds': (data['attendeeUserIds'] is List)
                ? List<String>.from(
                    (data['attendeeUserIds'] as List).whereType<String>())
                : <String>[],
            'capacity': (data['capacity'] is int) ? data['capacity'] : 50,
            'description': data['description'] ?? '',
            'preferredGender': data['preferredGender'] ?? 'Any',

            // Nullable
            'imageUrl': data['imageUrl'],
            'budgetPerHead': data['budgetPerHead'],
            'hostName': data['hostName'],
          };

          final party = Party.fromJson(partyJson);
          parties.add(party);
          print('Loaded party: ${party.title}');
        } catch (e) {
          print('Skipping party ${partyDoc.id} due to parse error: $e');
        }
      }

      print('Returning ${parties.length} saved parties');
      return parties;
    } catch (e) {
      print('Error getting saved parties: $e');
      return [];
    }
  }

  // Save a favorite venue
  Future<void> saveFavoriteVenue(String userId, String venueId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteVenues')
          .doc(venueId)
          .set({
        'venueId': venueId,
        'savedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error saving favorite venue: $e');
      throw Exception('Failed to save favorite venue');
    }
  }

  // Remove a favorite venue
  Future<void> removeFavoriteVenue(String userId, String venueId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteVenues')
          .doc(venueId)
          .delete();
    } catch (e) {
      print('Error removing favorite venue: $e');
      throw Exception('Failed to remove favorite venue');
    }
  }

  // Get favorite venues
  Future<List<Club>> getFavoriteVenues(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteVenues')
          .get();

      final venueIds = snapshot.docs.map((doc) => doc.id).toList();
      final venues = <Club>[];

      for (final venueId in venueIds) {
        final venueDoc =
            await _firestore.collection('clubs').doc(venueId).get();
        if (venueDoc.exists) {
          final data = venueDoc.data()!;
          final club = Club.fromJson({
            ...data,
            'id': venueDoc.id,
          });
          venues.add(club);
        }
      }

      return venues;
    } catch (e) {
      print('Error getting favorite venues: $e');
      return [];
    }
  }

  // Check if a party is saved
  Future<bool> isPartySaved(String userId, String partyId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedParties')
          .doc(partyId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking if party is saved: $e');
      return false;
    }
  }

  // Check if a venue is favorited
  Future<bool> isVenueFavorited(String userId, String venueId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favoriteVenues')
          .doc(venueId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking if venue is favorited: $e');
      return false;
    }
  }
}

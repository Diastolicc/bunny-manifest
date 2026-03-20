import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/club.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/models/user_profile.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get clubs =>
      _firestore.collection('clubs');
  CollectionReference<Map<String, dynamic>> get parties =>
      _firestore.collection('parties');
  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get reservations =>
      _firestore.collection('reservations');

  // Club operations
  Future<List<Club>> getClubs() async {
    try {
      final QuerySnapshot snapshot = await clubs.get();
      return snapshot.docs
          .map((doc) => Club.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting clubs: $e');
      return [];
    }
  }

  Future<Club?> getClub(String clubId) async {
    try {
      final DocumentSnapshot doc = await clubs.doc(clubId).get();
      if (doc.exists) {
        return Club.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting club: $e');
      return null;
    }
  }

  Future<void> createClub(Club club) async {
    try {
      await clubs.doc(club.id).set(club.toJson());
    } catch (e) {
      print('Error creating club: $e');
      rethrow;
    }
  }

  // Party operations
  Future<List<Party>> getPartiesForClub(String clubId) async {
    try {
      final QuerySnapshot snapshot = await parties
          .where('clubId', isEqualTo: clubId)
          .orderBy('dateTime')
          .get();
      return snapshot.docs
          .map((doc) => Party.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting parties: $e');
      return [];
    }
  }

  Future<Party?> getParty(String partyId) async {
    try {
      final DocumentSnapshot doc = await parties.doc(partyId).get();
      if (doc.exists) {
        return Party.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting party: $e');
      return null;
    }
  }

  Future<void> createParty(Party party) async {
    try {
      await parties.doc(party.id).set(party.toJson());
    } catch (e) {
      print('Error creating party: $e');
      rethrow;
    }
  }

  // User operations
  Future<UserProfile?> getUser(String userId) async {
    try {
      final DocumentSnapshot doc = await users.doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<void> createUser(UserProfile user) async {
    try {
      await users.doc(user.id).set(user.toJson());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await users.doc(userId).update(data);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Reservation operations
  Future<void> createReservation(String userId, String partyId) async {
    try {
      await reservations.add({
        'userId': userId,
        'partyId': partyId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'confirmed',
      });
    } catch (e) {
      print('Error creating reservation: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserReservations(String userId) async {
    try {
      final QuerySnapshot snapshot = await reservations
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting user reservations: $e');
      return [];
    }
  }

  // Search operations
  Future<List<Club>> searchClubs(String query) async {
    try {
      // Note: Firestore doesn't support full-text search out of the box
      // For production, consider using Algolia or similar service
      final QuerySnapshot snapshot = await clubs
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '$query\uf8ff')
          .get();
      return snapshot.docs
          .map((doc) => Club.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching clubs: $e');
      return [];
    }
  }
}

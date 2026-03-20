import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/user_profile.dart';
import 'package:bunny/config/firebase_config.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  // Get users collection reference
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      print('Fetching user profile for userId: $userId');
      final DocumentSnapshot doc = await _usersCollection.doc(userId).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('User data from Firestore: $data');
        data['id'] = doc.id;

        // Handle timestamp conversion manually
        final convertedData = _convertTimestamps(data);

        final profile = UserProfile.fromJson(convertedData);
        print(
            'Created UserProfile: ${profile.displayName}, profileImageUrl: ${profile.profileImageUrl}');
        return profile;
      } else {
        print('No user document found for userId: $userId');
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Get multiple user profiles by IDs
  Future<Map<String, UserProfile>> getUserProfiles(List<String> userIds) async {
    try {
      final Map<String, UserProfile> profiles = {};

      // Firestore 'in' queries are limited to 10 items, so we need to batch them
      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();
        final QuerySnapshot snapshot = await _usersCollection
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          // Handle timestamp conversion manually
          final convertedData = _convertTimestamps(data);

          print(
              'UserService: Loading user ${doc.id}: ${convertedData['displayName']}');
          print(
              'UserService: Profile image URL: ${convertedData['profileImageUrl']}');
          profiles[doc.id] = UserProfile.fromJson(convertedData);
        }
      }

      return profiles;
    } catch (e) {
      print('Error getting user profiles: $e');
      return {};
    }
  }

  // Stream user profile for real-time updates
  Stream<UserProfile?> streamUserProfile(String userId) {
    return _usersCollection.doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final convertedData = _convertTimestamps(data);
        return UserProfile.fromJson(convertedData);
      }
      return null;
    }).handleError((error) {
      print('Error streaming user profile: $error');
      return null;
    });
  }

  // Get all users (admin function)
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final convertedData = _convertTimestamps(data);
        return UserProfile.fromJson(convertedData);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all users: $e');
    }
  }

  // Verify user (admin function)
  Future<void> verifyUser(String userId) async {
    try {
      await _usersCollection.doc(userId).update({'isVerified': true});
    } catch (e) {
      throw Exception('Failed to verify user: $e');
    }
  }

  // Helper method to convert Firestore timestamps to ISO strings
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final convertedData = Map<String, dynamic>.from(data);

    // List of timestamp fields to convert
    final timestampFields = [
      'createdAt',
      'lastLoginAt',
      'verificationAppliedAt',
      'verificationApprovedAt',
      'birthday',
    ];

    for (final field in timestampFields) {
      if (convertedData[field] != null) {
        if (convertedData[field] is Timestamp) {
          convertedData[field] =
              (convertedData[field] as Timestamp).toDate().toIso8601String();
        } else if (convertedData[field] is Map &&
            convertedData[field].containsKey('_seconds')) {
          // Handle Firestore timestamp format
          final seconds = convertedData[field]['_seconds'] as int;
          final nanoseconds = convertedData[field]['_nanoseconds'] as int? ?? 0;
          final dateTime = DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds ~/ 1000000));
          convertedData[field] = dateTime.toIso8601String();
        }
      }
    }

    return convertedData;
  }
}

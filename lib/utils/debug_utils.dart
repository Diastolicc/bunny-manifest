import 'package:cloud_firestore/cloud_firestore.dart';

class DebugUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test function to check user data in database
  static Future<void> debugUserData() async {
    try {
      print('=== USER DATA DEBUG ===');

      // Get all users
      final snapshot = await _firestore.collection('users').get();
      print('Total users in database: ${snapshot.docs.length}');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        print('User ID: ${doc.id}');
        print('Display Name: ${data['displayName'] ?? 'NULL'}');
        print('Email: ${data['email'] ?? 'NULL'}');
        print('Profile Image: ${data['profileImageUrl'] ?? 'NULL'}');
        print('Verification Status: ${data['verificationStatus'] ?? 'NULL'}');
        print('---');
      }
    } catch (e) {
      print('Error in debug user data: $e');
    }
  }

  // Test function to create a test user with profile image
  static Future<void> createTestUserWithImage() async {
    try {
      print('=== CREATING TEST USER WITH IMAGE ===');

      final testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('users').doc(testUserId).set({
        'displayName': 'Test User with Image',
        'email': 'testuser@example.com',
        'profileImageUrl':
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        'verificationStatus': 'unverified',
        'createdAt': Timestamp.now(),
      });

      print('Test user created with ID: $testUserId');
    } catch (e) {
      print('Error creating test user: $e');
    }
  }

  // Test function to update current user's profile image
  static Future<void> updateCurrentUserImage(String userId) async {
    try {
      print('=== UPDATING CURRENT USER IMAGE ===');

      await _firestore.collection('users').doc(userId).update({
        'profileImageUrl':
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
      });

      print('Updated profile image for user: $userId');
    } catch (e) {
      print('Error updating user image: $e');
    }
  }
}

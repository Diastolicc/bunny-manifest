import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/user_profile.dart';

class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Apply for verification
  Future<void> applyForVerification({
    required String userId,
    required String fullName,
    required DateTime birthday,
  }) async {
    try {
      print('VerificationService: Applying for verification for user: $userId');
      print('VerificationService: Full name: $fullName, Birthday: $birthday');

      await _firestore.collection('users').doc(userId).update({
        'verificationStatus': 'pending',
        'fullName': fullName,
        'birthday': Timestamp.fromDate(birthday),
        'verificationAppliedAt': Timestamp.now(),
      });

      print(
          'VerificationService: Verification application submitted successfully');
    } catch (e) {
      print('Error applying for verification: $e');
      throw Exception('Failed to apply for verification: $e');
    }
  }

  // Get pending verification requests (for admin)
  Future<List<UserProfile>> getPendingVerifications() async {
    try {
      print('VerificationService: Fetching pending verifications...');
      final snapshot = await _firestore
          .collection('users')
          .where('verificationStatus', isEqualTo: 'pending')
          .orderBy('verificationAppliedAt', descending: false)
          .get();

      print(
          'VerificationService: Found ${snapshot.docs.length} pending verifications');

      final List<UserProfile> users = [];

      for (final doc in snapshot.docs) {
        try {
          var data = doc.data();
          data['id'] = doc.id;

          // Handle timestamp conversion manually
          data = _convertTimestamps(data);

          final user = UserProfile.fromJson(data);
          users.add(user);
          print(
              'VerificationService: Successfully parsed user: ${user.displayName}');
        } catch (e) {
          print('VerificationService: Error parsing user ${doc.id}: $e');
          // Create a fallback user profile
          final fallbackUser = UserProfile(
            id: doc.id,
            displayName: 'Unknown User',
            email: 'unknown@example.com',
            createdAt: DateTime.now(),
            verificationStatus: 'pending',
          );
          users.add(fallbackUser);
        }
      }

      print(
          'VerificationService: Successfully loaded ${users.length} pending verifications');
      return users;
    } catch (e) {
      print('Error getting pending verifications: $e');
      return [];
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

  // Approve verification (admin only)
  Future<void> approveVerification(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'verificationStatus': 'verified',
        'isVerified': true,
        'verificationApprovedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error approving verification: $e');
      throw Exception('Failed to approve verification: $e');
    }
  }

  // Reject verification (admin only)
  Future<void> rejectVerification(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'verificationStatus': 'rejected',
        'isVerified': false,
        'verificationRejectionReason': reason,
      });
    } catch (e) {
      print('Error rejecting verification: $e');
      throw Exception('Failed to reject verification: $e');
    }
  }

  // Get user verification status
  Future<String> getVerificationStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['verificationStatus'] ?? 'unverified';
      }
      return 'unverified';
    } catch (e) {
      print('Error getting verification status: $e');
      return 'unverified';
    }
  }
}

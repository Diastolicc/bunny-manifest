import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/user_profile.dart';
import 'package:bunny/config/firebase_config.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseConfig.auth;
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;

  UserProfile? _currentUser;
  StreamSubscription<User?>? _authStateSubscription;

  AuthService() {
    // Listen to authentication state changes
    _authStateSubscription =
        _auth.authStateChanges().listen((User? firebaseUser) {
      print(
          'AuthService: Auth state changed - User: ${firebaseUser?.uid}, Anonymous: ${firebaseUser?.isAnonymous}');
      if (firebaseUser != null) {
        // If we have a user, we are no longer in guest mode unless it's anonymous
        if (!firebaseUser.isAnonymous) {
          _isGuestMode = false;
        }
        _loadUserProfile(firebaseUser.uid);
      } else {
        _currentUser = null;
        // Keep guest mode as is or reset if needed, but usually on logout we might want to go to login
        // For now, let's not reset _isGuestMode here to avoid navigation issues,
        // but rely on manual signInAnonymously calls or explicit sign outs.
        notifyListeners();
      }
    });
  }

  UserProfile? get currentUser => _currentUser;
  User? get firebaseUser => _auth.currentUser;
  bool _isGuestMode = false;

  bool get isAuthenticated => _auth.currentUser != null;
  bool get isGuest => _isGuestMode || _auth.currentUser?.isAnonymous == true;

  // Refresh user profile from database
  Future<void> refreshUserProfile() async {
    if (_currentUser != null) {
      await _loadUserProfile(_currentUser!.id);
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

  // Generate a random guest username
  String _generateRandomGuestName() {
    final random = Random();
    final adjectives = [
      'Cool',
      'Awesome',
      'Epic',
      'Amazing',
      'Fantastic',
      'Brilliant',
      'Super',
      'Mega',
      'Ultra',
      'Pro',
      'Elite',
      'Prime',
      'Top',
      'Best',
      'Great',
      'Wonderful',
      'Incredible',
      'Outstanding',
      'Remarkable',
      'Extraordinary',
      'Magnificent',
      'Splendid',
      'Excellent',
      'Perfect',
      'Supreme',
      'Ultimate',
      'Supreme',
      'Legendary',
      'Mythical',
      'Divine'
    ];
    final nouns = [
      'Explorer',
      'Adventurer',
      'Traveler',
      'Wanderer',
      'Seeker',
      'Discoverer',
      'Navigator',
      'Pioneer',
      'Voyager',
      'Journeyer',
      'Explorer',
      'Scout',
      'Ranger',
      'Hunter',
      'Gatherer',
      'Collector',
      'Curator',
      'Enthusiast',
      'Fan',
      'Lover',
      'Devotee',
      'Supporter',
      'Follower',
      'Member',
      'Guest',
      'Visitor',
      'Participant',
      'Attendee',
      'Player',
      'Gamer',
      'User'
    ];

    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = random.nextInt(999) + 1;

    return '${adjective}${noun}$number';
  }

  // Sign in with email and password
  Future<UserProfile> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Explicitly turn off guest mode on successful login
        _isGuestMode = false;
        await _loadUserProfile(result.user!.uid);
        return _currentUser!;
      } else {
        throw Exception('Sign in failed');
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create user with email and password
  Future<UserProfile> createUserWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Explicitly turn off guest mode on successful sign up
        _isGuestMode = false;
        
        // Create user profile
        final UserProfile newProfile = UserProfile(
          id: result.user!.uid,
          displayName: displayName,
          email: email,
          createdAt: DateTime.now(),
        );

        // Save to Firestore
        await _firestore.collection('users').doc(result.user!.uid).set({
          ...newProfile.toJson(),
          'createdAt': Timestamp.now(),
        });

        _currentUser = newProfile;
        return newProfile;
      } else {
        throw Exception('User creation failed');
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in anonymously (guest mode without Firebase account)
  Future<void> signInAnonymously() async {
    _isGuestMode = true;
    notifyListeners();
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('AuthService: Signing out user: ${_currentUser?.id}');
      _isGuestMode = false;
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
      print(
          'AuthService: Sign out completed, current user is now: ${_currentUser?.id}');
    } on FirebaseAuthException catch (e) {
      print('AuthService: Error during sign out: $e');
      throw _handleAuthException(e);
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      if (_currentUser == null) throw Exception('No user logged in');

      // Update Firebase Auth profile if email changed
      if (email != null && email != _currentUser!.email) {
        await _auth.currentUser!.updateEmail(email);
      }

      // Update display name in Firebase Auth
      if (displayName != null) {
        await _auth.currentUser!.updateDisplayName(displayName);
      }

      // Update in Firestore
      final Map<String, dynamic> updates = {};
      if (displayName != null) updates['displayName'] = displayName;
      if (email != null) updates['email'] = email;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      if (updates.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(_currentUser!.id)
            .update(updates);

        // Update local user profile
        _currentUser = _currentUser!.copyWith(
          displayName: displayName ?? _currentUser!.displayName,
          email: email ?? _currentUser!.email,
          phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
          profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
        );
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    try {
      if (_currentUser == null) throw Exception('No user logged in');

      // Delete from Firestore
      await _firestore.collection('users').doc(_currentUser!.id).delete();

      // Delete Firebase Auth user
      await _auth.currentUser!.delete();

      _currentUser = null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Load user profile from Firestore
  Future<void> _loadUserProfile(String uid) async {
    try {
      print('AuthService: Loading user profile for UID: $uid');
      final DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('AuthService: Raw user data from Firestore: $data');

        // Handle timestamp conversion manually
        final convertedData = _convertTimestamps(data);

        _currentUser = UserProfile.fromJson(convertedData);
        print(
            'AuthService: Loaded existing user profile: ${_currentUser?.displayName}');
        print(
            'AuthService: Profile image URL: ${_currentUser?.profileImageUrl}');
        notifyListeners();
      } else {
        print('AuthService: No existing profile found, creating new one...');
        // Create profile if it doesn't exist (for users created before profile system)
        final User? firebaseUser = _auth.currentUser;
        if (firebaseUser != null) {
          // Use Firebase user creation date if available, otherwise use current time
          final DateTime registrationDate =
              firebaseUser.metadata.creationTime ?? DateTime.now();
          final UserProfile newProfile = UserProfile(
            id: uid,
            displayName: firebaseUser.displayName ??
                firebaseUser.email?.split('@')[0] ??
                'User',
            email: firebaseUser.email,
            createdAt: registrationDate,
          );

          await _firestore
              .collection('users')
              .doc(uid)
              .set(newProfile.toJson());
          _currentUser = newProfile;
          print(
              'AuthService: Created new user profile: ${newProfile.displayName}');
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
      // Fallback to basic profile
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        // Use Firebase user creation date if available, otherwise use current time
        final DateTime registrationDate =
            firebaseUser.metadata.creationTime ?? DateTime.now();
        _currentUser = UserProfile(
          id: uid,
          displayName: firebaseUser.displayName ??
              firebaseUser.email?.split('@')[0] ??
              'User',
          email: firebaseUser.email,
          createdAt: registrationDate,
        );
        print(
            'AuthService: Created fallback user profile: ${_currentUser?.displayName}');
        notifyListeners();
      }
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Update email address
  Future<void> updateEmail(String newEmail, String password) async {
    try {
      if (_currentUser == null) throw Exception('No user logged in');

      // Re-authenticate user before updating email
      final credential = EmailAuthProvider.credential(
        email: _currentUser!.email!,
        password: password,
      );
      await _auth.currentUser!.reauthenticateWithCredential(credential);

      // Update email in Firebase Auth
      await _auth.currentUser!.updateEmail(newEmail);

      // Update email in Firestore
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'email': newEmail,
      });

      // Update local user profile
      _currentUser = _currentUser!.copyWith(email: newEmail);
      notifyListeners();
    } catch (e) {
      print('Error updating email: $e');
      throw Exception('Failed to update email: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _authStateSubscription?.cancel();
  }
}

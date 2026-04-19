import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:bunny/theme/app_theme.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/saved_service.dart';
import 'package:bunny/services/notification_service.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/models/club.dart';
import 'package:bunny/models/user_profile.dart';
import 'package:bunny/widgets/verification_application_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _hostedPartiesCount = 0;
  int _joinedPartiesCount = 0;
  int _bunnyPoints = 0;
  static const double _surfaceRadius = 36.0;
  static const Color _pageBackground = Color(0xFFF4F6FB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPartyStats();
      _loadBunnyPoints();
    });
  }

  Future<void> _loadPartyStats() async {
    try {
      final authService = context.read<AuthService>();
      final partyService = context.read<PartyService>();
      final currentUserId = authService.currentUser?.id;

      if (currentUserId != null) {
        final allParties = await partyService.getAllParties();
        final hostedParties = allParties
            .where((party) => party.hostUserId == currentUserId)
            .toList();
        final hostedCount = hostedParties.length;
        final joinedParties = allParties
            .where((party) =>
                party.attendeeUserIds.contains(currentUserId) &&
                party.hostUserId != currentUserId)
            .toList();
        final joinedCount = joinedParties.length;

        if (mounted) {
          setState(() {
            _hostedPartiesCount = hostedCount;
            _joinedPartiesCount = joinedCount;
          });
        }
      } else {
        if (authService.isGuest) {
          return;
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _loadPartyStats();
          }
        });
      }
    } catch (e) {
      print('ProfileScreen: Error loading party stats: $e');
    }
  }

  Future<void> _loadBunnyPoints() async {
    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) return;

      final firestore = FirebaseFirestore.instance;
      final userDoc =
          await firestore.collection('users').doc(currentUser.id).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        int points = (data['bunnyPoints'] ?? 0) as int;
        final lastRefresh =
            (data['bunnyPointsLastRefresh'] as Timestamp?)?.toDate();

        if (lastRefresh != null) {
          final now = DateTime.now();
          final weeksSinceRefresh = now.difference(lastRefresh).inDays ~/ 7;
          if (weeksSinceRefresh > 0) {
            points += (weeksSinceRefresh * 10);
            await firestore.collection('users').doc(currentUser.id).update({
              'bunnyPoints': points,
              'bunnyPointsLastRefresh': Timestamp.now(),
            });
          }
        } else {
          if (points == 0) {
            points = 10;
          }
          await firestore.collection('users').doc(currentUser.id).update({
            'bunnyPoints': points,
            'bunnyPointsLastRefresh': Timestamp.now(),
          });
        }
        if (mounted) {
          setState(() {
            _bunnyPoints = points;
          });
        }
      } else {
        await firestore.collection('users').doc(currentUser.id).set({
          'bunnyPoints': 10,
          'bunnyPointsLastRefresh': Timestamp.now(),
        }, SetOptions(merge: true));
        if (mounted) {
          setState(() {
            _bunnyPoints = 10;
          });
        }
      }
    } catch (e) {
      print('Error loading bunny points: $e');
    }
  }

  // Social Media Style Helper Methods

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EBF4), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B1F2A),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap,
      {bool isLast = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: const Color(0xFFE8EDF5), width: 1),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 20,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1B1F2A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedParties(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Saved Parties',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _buildSavedPartiesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedPartiesList() {
    return FutureBuilder<List<Party>>(
      future: _getSavedParties(),
      builder: (context, snapshot) {
        print(
            'Profile screen - FutureBuilder state: ${snapshot.connectionState}');
        print('Profile screen - Has error: ${snapshot.hasError}');
        print('Profile screen - Has data: ${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Profile screen - Showing loading indicator');
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          print('Profile screen - Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading saved parties',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        final savedParties = snapshot.data ?? [];
        print(
            'Profile screen - UI received ${savedParties.length} saved parties');

        if (savedParties.isEmpty) {
          print('Profile screen - Showing empty state');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No saved parties yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save parties you\'re interested in to see them here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: savedParties.length,
          itemBuilder: (context, index) {
            final party = savedParties[index];
            return _buildSavedPartyCard(party);
          },
        );
      },
    );
  }

  Widget _buildSavedPartyCard(dynamic party) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Party image placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.celebration,
              color: AppTheme.colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Party details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.title ?? 'Party Title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  party.description ?? 'Party description',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(party.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            onPressed: () => _removeSavedParty(party.id),
            icon: const Icon(Icons.bookmark_remove),
            color: Colors.red.shade400,
          ),
        ],
      ),
    );
  }

  Future<List<Party>> _getSavedParties() async {
    try {
      final authService = context.read<AuthService>();
      final savedService = context.read<SavedService>();
      final firebaseUser = authService.firebaseUser;

      print(
          'Profile screen - getting saved parties for Firebase user: ${firebaseUser?.uid}');
      print(
          'Profile screen - AuthService isAuthenticated: ${authService.isAuthenticated}');
      print('Profile screen - Current user: ${authService.currentUser?.id}');

      if (firebaseUser == null) {
        print('No Firebase user found');
        return [];
      }

      print(
          'Profile screen - Calling getSavedParties with UID: ${firebaseUser.uid}');
      final savedParties = await savedService.getSavedParties(firebaseUser.uid);
      print('Profile screen - received ${savedParties.length} saved parties');

      for (int i = 0; i < savedParties.length; i++) {
        print(
            'Profile screen - Party $i: ${savedParties[i].title} (ID: ${savedParties[i].id})');
      }

      return savedParties;
    } catch (e) {
      print('Error getting saved parties: $e');
      return [];
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays > 1 && difference.inDays <= 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getMemberSinceText(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Member since recently';
    }

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final month = months[createdAt.month - 1];
    final year = createdAt.year;

    return 'Member since $month $year';
  }

  void _showVerificationApplication() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VerificationApplicationSheet(),
    );
  }

  void _updateUserImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final auth = context.read<AuthService>();
        final user = auth.currentUser;

        if (user != null) {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          try {
            // Upload image to Firebase Storage
            final String imageUrl = await _uploadProfileImage(image, user.id);

            // Update user profile with new image URL
            await _updateUserProfileImage(imageUrl, user.id);

            // Refresh the user profile
            auth.refreshUserProfile();

            // Close loading dialog
            if (mounted) Navigator.of(context).pop();

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile image updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            // Close loading dialog
            if (mounted) Navigator.of(context).pop();

            // Show error message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update profile image: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTestOngoingParty() async {
    try {
      final authService = context.read<AuthService>();
      final partyService = context.read<PartyService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to create test data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final now = DateTime.now();
      
      // Create ongoing party (happening now - started 1 hour ago)
      final testParty = Party(
        id: 'test_ongoing_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Ongoing Party',
        description: 'This is a test ongoing party for development purposes',
        hostUserId: currentUser.id,
        clubId: 'test_club_ongoing',
        dateTime: now.subtract(const Duration(hours: 1)), // Started 1 hour ago
        capacity: 50,
        budgetPerHead: 500,
        entranceFeeAmount: 0,
        hasEntranceFee: false,
        imageUrl: '',
        attendeeUserIds: ['user1', 'user2', 'user3'],
      );

      // Create the test party
      await partyService.create(
        clubId: testParty.clubId,
        hostUserId: testParty.hostUserId,
        title: testParty.title,
        dateTime: testParty.dateTime,
        description: testParty.description,
        capacity: testParty.capacity,
        budgetPerHead: testParty.budgetPerHead,
        entranceFeeAmount: testParty.entranceFeeAmount,
        hasEntranceFee: testParty.hasEntranceFee,
        imageUrl: testParty.imageUrl,
      );

      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test ongoing party created for today!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh party stats
        _loadPartyStats();
      }
    } catch (e) {
      print('Error creating test ongoing party: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating test party: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTestFutureParty() async {
    try {
      final authService = context.read<AuthService>();
      final partyService = context.read<PartyService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to create test data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final now = DateTime.now();
      
      // Create future party (tomorrow)
      final testParty = Party(
        id: 'test_future_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Future Party',
        description: 'This is a test future party for development purposes',
        hostUserId: currentUser.id,
        clubId: 'test_club_future',
        dateTime: now.add(const Duration(days: 1)), // Tomorrow
        capacity: 30,
        budgetPerHead: 300,
        entranceFeeAmount: 150,
        hasEntranceFee: true,
        imageUrl: '',
        attendeeUserIds: ['user4', 'user5'],
      );

      // Create the test party
      await partyService.create(
        clubId: testParty.clubId,
        hostUserId: testParty.hostUserId,
        title: testParty.title,
        dateTime: testParty.dateTime,
        description: testParty.description,
        capacity: testParty.capacity,
        budgetPerHead: testParty.budgetPerHead,
        entranceFeeAmount: testParty.entranceFeeAmount,
        hasEntranceFee: testParty.hasEntranceFee,
        imageUrl: testParty.imageUrl,
      );

      // Hide loading indicator
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test future party created for tomorrow!'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh party stats
        _loadPartyStats();
      }
    } catch (e) {
      print('Error creating test future party: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating test party: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTestPartyData() async {
    // Legacy method - now calls the ongoing party creation
    await _createTestOngoingParty();
  }

  Future<String> _uploadProfileImage(XFile image, String userId) async {
    try {
      final FirebaseStorage storage = FirebaseStorage.instance;
      final Reference ref = storage.ref().child(
          'profile_pictures/profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final UploadTask uploadTask = ref.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _updateUserProfileImage(String imageUrl, String userId) async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).update({
        'profileImageUrl': imageUrl,
      });
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  Widget _buildVerificationMenuItem(String? status) {
    switch (status) {
      case 'verified':
        return _buildMenuItem(
          Icons.verified,
          'Verified Account',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account is verified!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        );
      case 'pending':
        return _buildMenuItem(
          Icons.pending,
          'Verification Pending',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your verification is under review'),
                backgroundColor: Colors.orange,
              ),
            );
          },
        );
      case 'rejected':
        return _buildMenuItem(
          Icons.cancel,
          'Verification Rejected',
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Your verification was rejected. You can apply again.'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      default:
        return _buildVerificationApplyMenuItem();
    }
  }

  Widget _buildVerificationApplyMenuItem() {
    return GestureDetector(
      onTap: _showVerificationApplication,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: const Color(0xFFE8EDF5), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.help_outline,
                color: Colors.grey.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apply for Verification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1F2A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: Colors.grey.shade600,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Unverified',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileVerificationBadge(String? status) {
    switch (status) {
      case 'verified':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified,
                color: const Color(0xFF10B981),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                  color: const Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pending,
                color: Colors.orange,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Pending Review',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cancel,
                color: Colors.red,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Rejected',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline,
                color: Colors.grey.shade600,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Unverified',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    }
  }

  void _removeSavedParty(String partyId) {
    // Implement remove saved party logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Party removed from saved')),
    );
  }

  void _showFavorites(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Favorites',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _buildFavoritesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return FutureBuilder<List<Club>>(
      future: _getFavorites(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading favorites',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        final favorites = snapshot.data ?? [];

        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No favorites yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Like parties you\'re interested in to see them here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final favorite = favorites[index];
            return _buildFavoriteCard(favorite);
          },
        );
      },
    );
  }

  Widget _buildFavoriteCard(dynamic favorite) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Party image placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.celebration,
              color: AppTheme.colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Party details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite.title ?? 'Party Title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  favorite.description ?? 'Party description',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(favorite.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            onPressed: () => _removeFavorite(favorite.id),
            icon: const Icon(Icons.favorite),
            color: Colors.red.shade400,
          ),
        ],
      ),
    );
  }

  Future<List<Club>> _getFavorites() async {
    try {
      final authService = context.read<AuthService>();
      final savedService = context.read<SavedService>();
      final firebaseUser = authService.firebaseUser;

      if (firebaseUser == null) {
        return [];
      }

      final favoriteVenues =
          await savedService.getFavoriteVenues(firebaseUser.uid);
      return favoriteVenues;
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  void _removeFavorite(String favoriteId) {
    // Implement remove favorite logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Party removed from favorites')),
    );
  }

  Widget _buildRatingsAndReviewsSection(
      String profileUserId, String currentUserId) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(_surfaceRadius),
        border: Border.all(
          color: const Color(0xFFE6EBF4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ratings & Reviews',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1F2A),
                ),
              ),
              if (profileUserId != currentUserId)
                TextButton.icon(
                  onPressed: () =>
                      _showRateUserDialog(profileUserId, currentUserId),
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: const Text('Rate'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.colors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: _getRatingsAndReviews(profileUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data ?? {};
              final averageRating = data['averageRating'] ?? 0.0;
              final totalRatings = data['totalRatings'] ?? 0;
              final reviews = data['reviews'] ?? <Map<String, dynamic>>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Average Rating Display
                  if (totalRatings > 0)
                    Row(
                      children: [
                        _buildHeartRating(averageRating.round().clamp(0, 3),
                            size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1B1F2A),
                              ),
                            ),
                            Text(
                              '$totalRatings ${totalRatings == 1 ? 'rating' : 'ratings'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    const Text(
                      'No ratings yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Reviews List
                  if (reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No reviews yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    )
                  else
                    ...reviews
                        .map((review) => _buildReviewCard(review))
                        .toList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRating(int rating, {double size = 24.0}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final isFilled = index < rating;
        return Icon(
          isFilled ? Icons.favorite : Icons.favorite_border,
          color: isFilled ? Colors.red.shade400 : Colors.grey.shade300,
          size: size,
        );
      }),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EEF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: review['reviewerImageUrl'] != null
                    ? NetworkImage(review['reviewerImageUrl'])
                    : null,
                child: review['reviewerImageUrl'] == null
                    ? Icon(Icons.person, size: 16, color: Colors.grey.shade600)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['reviewerName'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1F2A),
                      ),
                    ),
                    if (review['createdAt'] != null)
                      Text(
                        _formatReviewDate(review['createdAt']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              _buildHeartRating(review['rating'] ?? 0, size: 20),
            ],
          ),
          if (review['comment'] != null &&
              review['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review['comment'],
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1B1F2A),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewDate(dynamic date) {
    if (date == null) return '';
    DateTime reviewDate;
    if (date is DateTime) {
      reviewDate = date;
    } else if (date is Timestamp) {
      reviewDate = date.toDate();
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(reviewDate);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${reviewDate.day}/${reviewDate.month}/${reviewDate.year}';
    }
  }

  Future<Map<String, dynamic>> _getRatingsAndReviews(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final reviewsSnapshot = await firestore
          .collection('user_reviews')
          .where('reviewedUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (reviewsSnapshot.docs.isEmpty) {
        return {
          'averageRating': 0.0,
          'totalRatings': 0,
          'reviews': <Map<String, dynamic>>[],
        };
      }

      final reviews = <Map<String, dynamic>>[];
      double totalRating = 0;

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final dynamic ratingValue = data['rating'];
        int rating = 0;
        if (ratingValue is int) {
          rating = ratingValue;
        } else if (ratingValue is double) {
          rating = ratingValue.round();
        }
        rating = rating.clamp(0, 3);
        totalRating += rating;

        // Get reviewer profile
        final reviewerId = data['reviewerId'];
        UserProfile? reviewerProfile;
        if (reviewerId != null) {
          try {
            final reviewerDoc =
                await firestore.collection('users').doc(reviewerId).get();
            if (reviewerDoc.exists) {
              final reviewerData = reviewerDoc.data()!;
              reviewerProfile = UserProfile.fromJson({
                'id': reviewerId,
                'displayName': reviewerData['displayName'] ?? 'Anonymous',
                'email': reviewerData['email'],
                'profileImageUrl': reviewerData['profileImageUrl'],
              });
            }
          } catch (e) {
            print('Error loading reviewer profile: $e');
          }
        }

        reviews.add({
          'id': doc.id,
          'rating': rating,
          'comment': data['comment'] ?? '',
          'reviewerId': reviewerId,
          'reviewerName': reviewerProfile?.displayName ?? 'Anonymous',
          'reviewerImageUrl': reviewerProfile?.profileImageUrl,
          'createdAt': data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : data['createdAt'],
        });
      }

      final averageRating =
          reviews.isNotEmpty ? totalRating / reviews.length : 0.0;

      return {
        'averageRating': averageRating,
        'totalRatings': reviews.length,
        'reviews': reviews,
      };
    } catch (e) {
      print('Error getting ratings and reviews: $e');
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'reviews': <Map<String, dynamic>>[],
      };
    }
  }

  void _showRateUserDialog(String profileUserId, String currentUserId) {
    int selectedRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Rate User'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tap hearts to rate (1-3):',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isSelected = index < selectedRating;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedRating = index + 1;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            isSelected ? Icons.favorite : Icons.favorite_border,
                            color: isSelected
                                ? Colors.red.shade400
                                : Colors.grey.shade300,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      labelText: 'Write a review (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'Share your experience...',
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: selectedRating == 0
                    ? null
                    : () async {
                        await _submitRating(
                          profileUserId,
                          currentUserId,
                          selectedRating,
                          commentController.text,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rating submitted successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {}); // Refresh the UI
                        }
                      },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitRating(
    String profileUserId,
    String currentUserId,
    int rating,
    String comment,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final authService = context.read<AuthService>();
      final reviewer = authService.currentUser;

      // Check if user already rated this profile
      final existingReview = await firestore
          .collection('user_reviews')
          .where('reviewedUserId', isEqualTo: profileUserId)
          .where('reviewerId', isEqualTo: currentUserId)
          .limit(1)
          .get();

      if (existingReview.docs.isNotEmpty) {
        // Update existing review
        final existingDoc = existingReview.docs.first;
        final existingData = existingDoc.data();
        final docRef = firestore.collection('user_reviews').doc(existingDoc.id);
        final Timestamp now = Timestamp.now();
        final Timestamp? existingCreatedAt =
            existingData['createdAt'] is Timestamp
                ? existingData['createdAt'] as Timestamp
                : null;

        await docRef.update({
          'rating': rating,
          'comment': comment.trim(),
          'reviewerName': reviewer?.displayName ?? 'Anonymous',
          'reviewerImageUrl': reviewer?.profileImageUrl,
          'updatedAt': now,
          if (existingCreatedAt == null) 'createdAt': now,
        });
      } else {
        // Create new review
        final Timestamp now = Timestamp.now();
        await firestore.collection('user_reviews').add({
          'reviewedUserId': profileUserId,
          'reviewerId': currentUserId,
          'rating': rating,
          'comment': comment.trim(),
          'reviewerName': reviewer?.displayName ?? 'Anonymous',
          'reviewerImageUrl': reviewer?.profileImageUrl,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    } catch (e) {
      print('Error submitting rating: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSignOutDialog(
      BuildContext context, AuthService auth) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sign Out'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  // Reset notification service
                  if (context.mounted) {
                    context.read<NotificationService>().reset();
                  }

                  await auth.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error signing out: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, child) {
        final user = auth.currentUser;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: _pageBackground,
          body: Stack(
            children: [
              Positioned(
                top: -130,
                left: -90,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.colors.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                top: 80,
                right: -100,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.colors.secondary.withValues(alpha: 0.1),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_surfaceRadius),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.64),
                              borderRadius:
                                  BorderRadius.circular(_surfaceRadius),
                              border:
                                  Border.all(color: const Color(0xFFE6EBF4)),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Profile',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1B1F2A),
                                      height: 1,
                                    ),
                                  ),
                                ),
                                _buildHeaderAction(
                                  icon: Icons.bookmark_outline,
                                  onTap: () => _showSavedParties(context),
                                ),
                                const SizedBox(width: 8),
                                _buildHeaderAction(
                                  icon: Icons.help_outline,
                                  onTap: () => context.push('/help'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 110),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  margin:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius:
                                        BorderRadius.circular(_surfaceRadius),
                                    border: Border.all(
                                      color: const Color(0xFFE6EBF4),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.06),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Image.asset(
                                            'assets/logos/wordmark_color.png',
                                            height: 30,
                                            fit: BoxFit.contain,
                                          ),
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            backgroundImage:
                                                user?.profileImageUrl != null
                                                    ? NetworkImage(
                                                        user!.profileImageUrl!)
                                                    : null,
                                            child: user?.profileImageUrl == null
                                                ? Icon(
                                                    Icons.person,
                                                    color: Colors.grey.shade600,
                                                    size: 32,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 34),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              user?.displayName ?? 'Guest User',
                                              style: const TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1B1F2A),
                                                height: 1,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppTheme.colors.primary,
                                                  AppTheme.colors.secondary,
                                                ],
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.stars_rounded,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$_bunnyPoints Points',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _buildProfileVerificationBadge(
                                          user?.verificationStatus),
                                      const SizedBox(height: 6),
                                      Text(
                                        _getMemberSinceText(user?.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildStatItem(
                                              'Hosted',
                                              _hostedPartiesCount.toString(),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildStatItem(
                                              'Joined',
                                              _joinedPartiesCount.toString(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  bottom: 16,
                                  right: 18,
                                  child: Opacity(
                                    opacity: 0.14,
                                    child: Image.asset(
                                      'assets/logos/bunny_logo.png',
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _buildRatingsAndReviewsSection(
                                user?.id ?? '', auth.currentUser?.id ?? ''),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius:
                                    BorderRadius.circular(_surfaceRadius),
                                border:
                                    Border.all(color: const Color(0xFFE6EBF4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  if (!auth.isGuest) ...[
                                    _buildVerificationMenuItem(
                                        user?.verificationStatus),
                                    _buildMenuItem(
                                        Icons.image,
                                        'Update Profile Image',
                                        _updateUserImage),
                                    _buildMenuItem(
                                        Icons.play_circle_outline,
                                        'Create Test Ongoing Party',
                                        _createTestOngoingParty),
                                    _buildMenuItem(
                                        Icons.add_circle_outline,
                                        'Create Test Future Party',
                                        _createTestFutureParty),
                                    _buildMenuItem(
                                        Icons.email_outlined, 'Email Settings',
                                        () {
                                      context.push('/email-settings');
                                    }),
                                    if (user?.tokenAdmin == 'sjahkmwieoahean')
                                      _buildMenuItem(Icons.admin_panel_settings,
                                          'Admin Settings', () {
                                        context.push('/admin-settings');
                                      }),
                                  ],
                                  _buildMenuItem(Icons.lightbulb_outline,
                                      'Request Feature', () {
                                    context.push('/request-feature');
                                  }),
                                  if (auth.isGuest)
                                    _buildMenuItem(Icons.login, 'Sign In', () {
                                      context.push('/login');
                                    }, isLast: true)
                                  else
                                    _buildMenuItem(Icons.logout, 'Sign Out',
                                        () async {
                                      await _showSignOutDialog(context, auth);
                                    }, isLast: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.72),
                                borderRadius:
                                    BorderRadius.circular(_surfaceRadius),
                                border:
                                    Border.all(color: const Color(0xFFE6EBF4)),
                              ),
                              child: Center(
                                child: Text(
                                  'BUNNY v1.0.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6EBF4)),
        ),
        child: Icon(icon, color: const Color(0xFF1B1F2A), size: 22),
      ),
    );
  }
}

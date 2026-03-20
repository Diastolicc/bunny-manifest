import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/services/user_service.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/models/user_profile.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;

  const UserProfileViewScreen({super.key, required this.userId});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  int _reloadToken = 0;

  void _refresh() {
    if (mounted) {
      setState(() {
        _reloadToken++;
      });
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
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: FutureBuilder<UserProfile?>(
        key: ValueKey('user_profile_${widget.userId}_$_reloadToken'),
        future: context.read<UserService>().getUserProfile(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'User not found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final user = snapshot.data!;
          final currentUserId = context.read<AuthService>().currentUser?.id;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                            'BUNNY',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              letterSpacing: 2.0,
                            ),
                          ),
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: user.profileImageUrl != null
                                ? NetworkImage(user.profileImageUrl!)
                                : null,
                            child: user.profileImageUrl == null
                                ? Icon(
                                    Icons.person,
                                    color: Colors.grey.shade600,
                                    size: 30,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (user.email != null)
                            Text(
                              user.email!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _getMemberSinceText(user.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ratings and Reviews Section
                _buildRatingsAndReviewsSection(
                    widget.userId, currentUserId ?? ''),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingsAndReviewsSection(
      String profileUserId, String currentUserId) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ratings & Reviews',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (profileUserId != currentUserId && currentUserId.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _showRateUserDialog(
                        context, profileUserId, currentUserId),
                    icon: const Icon(Icons.favorite_border, size: 18),
                    label: const Text('Rate'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              key: ValueKey('ratings_${profileUserId}_$_reloadToken'),
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
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
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
                color: Colors.black87,
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

  void _showRateUserDialog(
      BuildContext context, String profileUserId, String currentUserId) {
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
                          context,
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
                          _refresh();
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
    BuildContext context,
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
}

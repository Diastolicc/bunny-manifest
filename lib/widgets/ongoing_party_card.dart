import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../services/club_service.dart';
import '../services/user_service.dart';
import '../services/local_cache_service.dart';
import '../services/auth_service.dart';
import '../services/saved_service.dart';

class OngoingPartyCard extends StatefulWidget {
  const OngoingPartyCard({
    super.key,
    required this.party,
    this.userLatitude,
    this.userLongitude,
    this.showNowBadge = false,
    this.storyStyle = false,
  });
  final Party party;
  final double? userLatitude;
  final double? userLongitude;
  final bool showNowBadge;
  final bool storyStyle;

  @override
  State<OngoingPartyCard> createState() => _OngoingPartyCardState();
}

class _OngoingPartyCardState extends State<OngoingPartyCard> with SingleTickerProviderStateMixin {
  String? _clubLocation;
  String? _hostProfileImageUrl;
  String? _hostFirstName;
  double? _distanceKm;
  bool _isSaved = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadClubInfo();
    _loadHostInfo();
    _calculateDistance();
    _checkIfSaved();
    
    // Initialize pulse animation for NOW badge
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadClubInfo() async {
    try {
      final clubService = ClubService();
      final club = await clubService.getById(widget.party.clubId);
      if (mounted) {
        setState(() {
          _clubLocation = club?.location ?? 'Unknown Location';
          _distanceKm = club?.distanceKm;
        });
      }
    } catch (e) {
      print('Error loading club info: $e');
      if (mounted) {
        setState(() {
          _clubLocation = 'Unknown Location';
        });
      }
    }
  }

  Future<void> _loadHostInfo() async {
    try {
      final userService = UserService();
      final host = await userService.getUserProfile(widget.party.hostUserId);
      if (mounted) {
        setState(() {
          _hostProfileImageUrl = host?.profileImageUrl;
          _hostFirstName = (host != null && host.displayName.isNotEmpty)
              ? host.displayName.split(' ').first
              : 'Host';
        });
      }
    } catch (e) {
      print('Error loading host info: $e');
      if (mounted) {
        setState(() {
          _hostFirstName = 'Host';
        });
      }
    }
  }

  Future<void> _calculateDistance() async {
    if (widget.userLatitude == null || widget.userLongitude == null) {
      return;
    }

    try {
      final clubService = ClubService();
      final club = await clubService.getById(widget.party.clubId);

      // If club has distanceKm already calculated, use it
      if (club?.distanceKm != null && (club?.distanceKm ?? 0) > 0) {
        if (mounted) {
          setState(() {
            _distanceKm = club?.distanceKm;
          });
        }
        return;
      }

      if (mounted && club != null) {
        setState(() {
          _distanceKm = club.distanceKm > 0 ? club.distanceKm : null;
        });
      }
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  Future<void> _checkIfSaved() async {
    try {
      final authService = context.read<AuthService>();
      final savedService = context.read<SavedService>();
      final firebaseUser = authService.firebaseUser;

      if (firebaseUser != null) {
        final isSaved =
            await savedService.isPartySaved(firebaseUser.uid, widget.party.id);
        if (mounted) {
          setState(() {
            _isSaved = isSaved;
          });
        }
      }
    } catch (e) {
      print('Error checking if party is saved: $e');
    }
  }

  Future<Map<String, dynamic>> _loadAttendeeProfiles() async {
    try {
      final userService = UserService();
      final attendeeIds = widget.party.attendeeUserIds;
      
      // Get up to 4 profile URLs
      final List<String?> profileUrls = [];
      final idsToFetch = attendeeIds.take(4).toList();
      
      for (final userId in idsToFetch) {
        try {
          final profile = await userService.getUserProfile(userId);
          profileUrls.add(profile?.profileImageUrl);
        } catch (e) {
          print('Error loading profile for user $userId: $e');
          profileUrls.add(null);
        }
      }
      
      final remaining = attendeeIds.length > 4 ? attendeeIds.length - 4 : 0;
      
      return {
        'profiles': profileUrls,
        'remaining': remaining,
      };
    } catch (e) {
      print('Error loading attendee profiles: $e');
      return {
        'profiles': <String?>[],
        'remaining': 0,
      };
    }
  }

  Widget _buildDateCard(DateTime dateTime) {
    final day = dateTime.day.toString();
    final month = _formatDate(dateTime).toUpperCase();
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final time = '$displayHour:$minute $period';

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF8d58b5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              month,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Day
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
                height: 1,
              ),
            ),
          ),
          // Time
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[date.month - 1];
  }

  String _formatDay(DateTime date) {
    return date.day.toString();
  }

  String _getPartyImage(String partyTitle) {
    final List<String> partyImages = [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1566733971017-f8a6c8c2c6b3?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1520975916090-3105956d8ac38?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1517095037594-166575f1e866?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&h=300&fit=crop',
    ];
    final int hash = partyTitle.hashCode;
    return partyImages[hash.abs() % partyImages.length];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.storyStyle) {
      return _buildStoryStyleCard(context);
    }

    return GestureDetector(
      onTap: () async {
        // Cache the party data locally before navigation
        await LocalCacheService.cacheParty(widget.party);
        context.push('/party-details?id=${widget.party.id}');
      },
      child: Container(
        height: 360,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Party image as the base card
              Positioned.fill(
                child: Image.network(
                  (widget.party.imageUrl != null &&
                          widget.party.imageUrl!.isNotEmpty)
                      ? widget.party.imageUrl!
                      : _getPartyImage(widget.party.title),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.image_not_supported,
                            size: 32, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
              // Small details card at the bottom
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      // Party title with checkmark
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.party.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8d58b5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.party.budgetPerHead != null
                                  ? '₱${widget.party.budgetPerHead!.toStringAsFixed(0)}'
                                  : 'Free',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Host name
                      Text(
                        'Hosted by ${_hostFirstName ?? widget.party.hostName ?? 'Host'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Profile avatars and location in a row
                      Row(
                        children: [
                          // Profile avatars of host and joiners
                          SizedBox(
                            height: 28,
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: _loadAttendeeProfiles(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final profiles = snapshot.data!['profiles'] as List<String?>;
                                final remainingCount = snapshot.data!['remaining'] as int;
                                
                                return Row(
                                  children: [
                                    // Display up to 4 profile avatars
                                    ...List.generate(
                                      profiles.length > 4 ? 4 : profiles.length,
                                      (index) {
                                        return Transform.translate(
                                          offset: Offset(-8.0 * index, 0),
                                          child: Container(
                                            height: 28,
                                            width: 28,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.grey.shade300,
                                              backgroundImage: profiles[index] != null
                                                  ? NetworkImage(profiles[index]!)
                                                  : null,
                                              child: profiles[index] == null
                                                  ? Icon(
                                                      Icons.person,
                                                      size: 16,
                                                      color: Colors.grey.shade600,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Show remaining count if more than 4
                                    if (remainingCount > 0)
                                      Transform.translate(
                                        offset: Offset(-8.0 * (profiles.length > 4 ? 4 : profiles.length), 0),
                                        child: Container(
                                          height: 28,
                                          width: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF8d58b5),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '+$remainingCount',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const Spacer(),
                          // Location on the right, aligned with avatars
                          Flexible(
                            child: Text(
                              _clubLocation ?? 'Unknown Location',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Date card on top left
              Positioned(
                top: 12,
                left: 12,
                child: _buildDateCard(widget.party.dateTime),
              ),
              // Animated NOW badge on top right (only for ongoing parties)
              if (widget.showNowBadge)
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.red.shade400,
                                Colors.red.shade600,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'NOW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Bookmark icon (for non-ongoing parties)
              if (!widget.showNowBadge)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () async {
                      final authService = context.read<AuthService>();
                      final savedService = context.read<SavedService>();
                      final firebaseUser = authService.firebaseUser;

                      if (firebaseUser == null) {
                        return;
                      }

                      try {
                        if (_isSaved) {
                          await savedService.removeSavedParty(
                              firebaseUser.uid, widget.party.id);
                          setState(() {
                            _isSaved = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Removed from saved'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          await savedService.saveParty(
                              firebaseUser.uid, widget.party.id);
                          setState(() {
                            _isSaved = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved for later'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error saving party: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: _isSaved ? Colors.amber : Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryStyleCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await LocalCacheService.cacheParty(widget.party);
        context.push('/party-details?id=${widget.party.id}');
      },
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red.shade400,
                        Colors.red.shade700,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                        image: DecorationImage(
                          image: NetworkImage(
                            (widget.party.imageUrl != null &&
                                    widget.party.imageUrl!.isNotEmpty)
                                ? widget.party.imageUrl!
                                : _getPartyImage(widget.party.title),
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.party.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

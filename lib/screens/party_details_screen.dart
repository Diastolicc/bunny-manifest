import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/party.dart';
import '../models/user_profile.dart';
import '../services/club_service.dart';
import '../services/user_service.dart';
import '../services/party_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/saved_service.dart';
import '../theme/app_theme.dart';
import '../services/local_cache_service.dart';
import 'chat_room_screen.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';

class PartyDetailsScreen extends StatefulWidget {
  final Party party;

  const PartyDetailsScreen({super.key, required this.party});

  @override
  State<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends State<PartyDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _bunnyController;
  late Animation<double> _slideAnimation;
  late Animation<double> _bunnyAnimation;
  String? _clubName;
  List<UserProfile> _attendees = [];
  bool _isPending = false;
  bool _isJoined = false;
  String? _applicationId;
  bool _isFavorited = false;
  bool _isJoiningRequest = false;
  bool _isCancellingRequest = false;
  OverlayEntry? _toastOverlayEntry;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _bunnyController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
    );
    _bunnyAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bunnyController, curve: Curves.elasticOut),
    );
    _loadPartyData();
    // Start the slide animation
    _slideController.forward();
  }

  @override
  void dispose() {
    _toastOverlayEntry?.remove();
    _slideController.dispose();
    _bunnyController.dispose();
    super.dispose();
  }

  void _showModernToast({
    required String message,
    required IconData icon,
    required Color accentColor,
  }) {
    if (!mounted) return;

    _toastOverlayEntry?.remove();

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ModernToast(
        message: message,
        icon: icon,
        accentColor: accentColor,
      ),
    );

    overlay.insert(entry);
    _toastOverlayEntry = entry;

    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (_toastOverlayEntry == entry) {
        _toastOverlayEntry?.remove();
        _toastOverlayEntry = null;
      }
    });
  }

  Future<void> _loadPartyData() async {
    try {
      // Check if party is saved (bookmarked)
      final authService = context.read<AuthService>();
      final firebaseUser = authService.firebaseUser;
      if (firebaseUser != null) {
        final savedService = context.read<SavedService>();
        final isSaved =
            await savedService.isPartySaved(firebaseUser.uid, widget.party.id);
        if (mounted) {
          setState(() {
            _isFavorited = isSaved;
          });
        }
      }

      // First, try to get party data from local cache
      final cachedParty =
          await LocalCacheService.getCachedParty(widget.party.id);
      if (cachedParty != null) {
        print('📱 Using cached party data for ${widget.party.id}');
        // Update the party data with cached version if it's newer
        if (cachedParty.dateTime.isAfter(widget.party.dateTime)) {
          // Use cached data if it's more recent
          setState(() {
            // Update the party data with cached version
            // Note: This is a simplified approach - in a real app you might want to merge data
          });
        }
      }

      final clubService = ClubService();
      final userService = UserService();
      final auth = context.read<AuthService>();
      final partyService = context.read<PartyService>();

      // Load club info
      final club = await clubService.getById(widget.party.clubId);
      if (mounted) {
        setState(() {
          _clubName = club?.name ?? 'Unknown Venue';
        });
      }

      // Load host and all attendees
      final host = await userService.getUserProfile(widget.party.hostUserId);
      final List<UserProfile> allAttendees = [];

      print('Party attendeeUserIds: ${widget.party.attendeeUserIds}');
      print('Host ID: ${widget.party.hostUserId}');

      if (host != null) {
        allAttendees.add(host);
        print('Added host: ${host.displayName}');
      }

      // Load all attendee profiles
      for (final attendeeId in widget.party.attendeeUserIds) {
        if (attendeeId != widget.party.hostUserId) {
          // Don't duplicate host
          try {
            final attendee = await userService.getUserProfile(attendeeId);
            if (attendee != null) {
              allAttendees.add(attendee);
              print('Added attendee: ${attendee.displayName}');
            }
          } catch (e) {
            print('Error loading attendee $attendeeId: $e');
          }
        }
      }

      print('Total attendees loaded: ${allAttendees.length}');

      if (mounted) {
        setState(() {
          _attendees = allAttendees;
        });
      }

      // Check if current user is already joined or has a pending application
      final userId = auth.firebaseUser?.uid;
      if (userId != null && userId.isNotEmpty) {
        // Check if user is already joined
        final isJoined = widget.party.attendeeUserIds.contains(userId);
        if (mounted) {
          setState(() {
            _isJoined = isJoined;
          });
        }

        // Only check for pending application if not already joined
        if (!isJoined) {
          final application = await partyService.getApplicationForUser(
            partyId: widget.party.id,
            userId: userId,
          );
          if (mounted && application != null) {
            final status = application['status'] as String?;
            if (status == 'pending') {
              setState(() {
                _isPending = true;
                _applicationId = application['id'] as String?;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading party data: $e');
      if (mounted) {
        setState(() {
          _clubName = 'Unknown Venue';
          _attendees = [];
        });
      }
    }
  }

  String _getPartyImage(String partyTitle) {
    // Try to get a real party image first
    if (widget.party.imageUrl != null && widget.party.imageUrl!.isNotEmpty) {
      return widget.party.imageUrl!;
    }

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

    // Use hash-based selection for consistent image assignment
    final hash = partyTitle.hashCode;
    final index = hash.abs() % partyImages.length;
    return partyImages[index];
  }

  String _getMonthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }

  Future<void> _handleJoinParty() async {
    if (_isJoiningRequest) return;

    final auth = context.read<AuthService>();
    if (auth.isGuest) {
      // Handle guest user prompt - Go to login screen
      context.push('/login');
      return;
    }

    // Check if party is accepting requests
    if (!widget.party.isAcceptingRequests) {
      _showModernToast(
        message: 'This party is not accepting requests right now',
        icon: Icons.lock_clock_rounded,
        accentColor: const Color(0xFFF59E0B),
      );
      return;
    }

    // Check if already joined
    if (_isJoined) {
      _showModernToast(
        message: 'You are already part of this party',
        icon: Icons.check_circle_rounded,
        accentColor: const Color(0xFF22C55E),
      );
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isJoiningRequest = true;
        });
      }

      final userId = auth.firebaseUser?.uid;
      if (userId == null || userId.isEmpty) {
        _showModernToast(
          message: 'Not signed in',
          icon: Icons.person_off_rounded,
          accentColor: const Color(0xFFEF4444),
        );
        return;
      }

      final appId = await context.read<PartyService>().createJoinApplication(
            partyId: widget.party.id,
            userId: userId,
          );

      if (mounted) {
        if (appId != null) {
          setState(() {
            _isPending = true;
            _applicationId = appId;
          });

          // Log the join request in Activity
          final currentUserId = auth.firebaseUser?.uid;
          if (currentUserId != null) {
            await context.read<NotificationService>().sendNotificationToUser(
                  targetUserId: currentUserId,
                  title: 'Join request sent',
                  body: 'You asked to join "${widget.party.title}".',
                  type: 'party_invite',
                  relatedId: widget.party.id,
                );
          }

          _showModernToast(
            message: 'Join request sent',
            icon: Icons.mark_chat_unread_rounded,
            accentColor: const Color(0xFF22C55E),
          );
        } else {
          _showModernToast(
            message: 'You already requested or joined',
            icon: Icons.info_rounded,
            accentColor: const Color(0xFFF59E0B),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showModernToast(
          message: 'Error joining party',
          icon: Icons.error_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoiningRequest = false;
        });
      }
    }
  }

  Future<void> _handleCancelApplication() async {
    if (_applicationId == null || _isCancellingRequest) return;
    try {
      if (mounted) {
        setState(() {
          _isCancellingRequest = true;
        });
      }

      await context
          .read<PartyService>()
          .rejectApplication(applicationId: _applicationId!);
      if (mounted) {
        setState(() {
          _isPending = false;
          _applicationId = null;
        });
        _showModernToast(
          message: 'Application cancelled',
          icon: Icons.cancel_rounded,
          accentColor: const Color(0xFF38BDF8),
        );
      }
    } catch (e) {
      if (mounted) {
        _showModernToast(
          message: 'Failed to cancel application',
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancellingRequest = false;
        });
      }
    }
  }

  Future<void> _navigateToPartyChat() async {
    try {
      // Get the chat group for this party
      final chatService = context.read<ChatService>();
      final chatGroup = await chatService.getChatGroupForParty(widget.party.id);

      if (chatGroup != null) {
        // Navigate to the chat room
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatRoomScreen(groupId: chatGroup.id),
            ),
          );
        }
      } else {
        // Chat group doesn't exist yet, show message
        if (mounted) {
          _showModernToast(
            message:
                'Chat not available yet. It will be created when the party starts.',
            icon: Icons.forum_outlined,
            accentColor: const Color(0xFFF59E0B),
          );
        }
      }
    } catch (e) {
      print('Error navigating to party chat: $e');
      if (mounted) {
        _showModernToast(
          message: 'Error opening chat',
          icon: Icons.error_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  Widget _buildFloatingHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final authService = context.read<AuthService>();
                  final firebaseUser = authService.firebaseUser;
                  if (firebaseUser == null) {
                    // Guest users: do not show sign-in popup. Ignore save action.
                    return;
                  }

                  try {
                    final savedService = context.read<SavedService>();
                    if (_isFavorited) {
                      await savedService.removeSavedParty(
                          firebaseUser.uid, widget.party.id);
                      setState(() {
                        _isFavorited = false;
                      });
                      _showModernToast(
                        message: 'Removed from saved',
                        icon: Icons.bookmark_remove_rounded,
                        accentColor: const Color(0xFFF59E0B),
                      );
                    } else {
                      await savedService.saveParty(
                          firebaseUser.uid, widget.party.id);
                      setState(() {
                        _isFavorited = true;
                      });
                      _showModernToast(
                        message: 'Saved for later',
                        icon: Icons.bookmark_added_rounded,
                        accentColor: const Color(0xFF22C55E),
                      );
                    }
                  } catch (e) {
                    _showModernToast(
                      message: 'Failed to update saved party',
                      icon: Icons.error_outline_rounded,
                      accentColor: const Color(0xFFEF4444),
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                    color: _isFavorited ? Colors.amber : Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        // Full width image at the very top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height:
              MediaQuery.of(context).size.height * 0.4, // 40% of screen height
          child: Image.network(
            _getPartyImage(widget.party.title),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade800,
                child: const Center(
                  child: Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              );
            },
          ),
        ),

        // Details card positioned below the image
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4 -
              20, // Start slightly overlapping the image
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(
              child: _buildNewDetailsCard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewDetailsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 1. Name of Event
          _buildReadOnlyMinimalField(
            label: 'Name of Event',
            value: widget.party.title,
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // 2. Address (Venue)
          _buildReadOnlyMinimalField(
            label: 'Venue',
            value: _clubName ?? 'Unknown Venue',
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // 3. Notes for visitor
          _buildReadOnlyMinimalField(
            label: 'Notes for visitor',
            value: widget.party.description,
            maxLines: 10,
          ),
          const SizedBox(height: 24),

          // 4. Date & Time Card
          _buildReadOnlyDateTimeCard(),
          const SizedBox(height: 24),

          // 5. Capacity and Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildReadOnlyMinimalField(
                  label: 'Total Person',
                  value: '${widget.party.capacity} people',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildReadOnlyBudgetField(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 7. Drinking Preferences
          _buildReadOnlyDrinkingPreferences(),
          const SizedBox(height: 24),

          // 8. Participants Section
          _buildSectionTitle('Participants'),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(
                left: 0), // Removed padding to align with other fields
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Going',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_attendees.length} people',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_attendees.isNotEmpty)
                    Row(
                      children: [
                        ..._attendees.take(6).map((attendee) {
                          final isHost = attendee.id == widget.party.hostUserId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: (attendee.profileImageUrl !=
                                              null &&
                                          attendee.profileImageUrl!.isNotEmpty)
                                      ? NetworkImage(attendee.profileImageUrl!)
                                      : null,
                                  child: (attendee.profileImageUrl == null ||
                                          attendee.profileImageUrl!.isEmpty)
                                      ? Text(
                                          attendee.displayName.isNotEmpty
                                              ? attendee.displayName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                if (isHost)
                                  Positioned(
                                    bottom: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.colors.primary,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Colors.white, width: 1),
                                      ),
                                      child: const Text(
                                        'HOST',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (_attendees.length > 6)
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey.shade400,
                            child: Text(
                              '+${_attendees.length - 6}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    const Text(
                      'No attendees yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 9. Invite Code Section
          _buildSectionTitle('Invite Code'),
          const SizedBox(height: 8),
          Divider(
            color: Colors.grey.shade300,
            thickness: 1,
          ),
          const SizedBox(height: 12),
          _buildInviteCodeSection(),

          const SizedBox(height: 80), // Space for floating button
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildReadOnlyMinimalField({
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8936D), // Peach color
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value.isNotEmpty ? value : 'Not specified',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }

  Widget _buildReadOnlyDateTimeCard() {
    // Helper to format month name
    String getMonthName(int month) {
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
      return months[month - 1];
    }

    // Helper to format day name
    String getDayName(int weekday) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return days[weekday - 1];
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF321857),
              Color(0xFF5D369F)
            ], // Deep purple gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            // Date Block
            Container(
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center vertically
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Center horizontally
                children: [
                  Text(
                    getMonthName(widget.party.dateTime.month),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${widget.party.dateTime.day}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Time & Day Info
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center vertically
                crossAxisAlignment:
                    CrossAxisAlignment.center, // Center horizontally
                children: [
                  Text(
                    getDayName(widget.party.dateTime.weekday),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeOfDay.fromDateTime(widget.party.dateTime)
                        .format(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyBudgetField() {
    final budgetAmount = widget.party.budgetPerHead != null
        ? widget.party.budgetPerHead!.toStringAsFixed(0)
        : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8936D), // Peach color
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₱',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                budgetAmount,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              '/person',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        if (widget.party.hasEntranceFee) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8936D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFE8936D),
                width: 1,
              ),
            ),
            child: Text(
              '+₱${widget.party.entranceFeeAmount} Fee',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE8936D),
              ),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildReadOnlyDrinkingPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Drinking Preferences',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8936D),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.party.drinkingTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.party.drinkingTags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8936D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE8936D),
                  ),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE8936D),
                  ),
                ),
              );
            }).toList(),
          )
        else
          const Text(
            'Not specified',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }

  Widget _buildInviteCodeSection() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.share,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Share this code to invite friends',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.party.inviteCode.isNotEmpty
                          ? widget.party.inviteCode
                          : 'No invite code available',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.party.inviteCode.isNotEmpty
                            ? Colors.blue.shade800
                            : Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (widget.party.inviteCode.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        // Copy to clipboard
                        await _copyInviteCode();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.party.inviteCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Friends can use this code to join your party',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copyInviteCode() async {
    try {
      // Import clipboard functionality
      // Note: You may need to add flutter/services to imports
      await Clipboard.setData(ClipboardData(text: widget.party.inviteCode));

      if (mounted) {
        _showModernToast(
          message: 'Invite code copied to clipboard',
          icon: Icons.copy_rounded,
          accentColor: const Color(0xFF22C55E),
        );
      }
    } catch (e) {
      if (mounted) {
        _showModernToast(
          message: 'Failed to copy invite code',
          icon: Icons.error_outline_rounded,
          accentColor: const Color(0xFFEF4444),
        );
      }
    }
  }

  Widget _buildJoinButton() {
    final auth = context.read<AuthService>();
    final isHost = auth.currentUser?.id == widget.party.hostUserId;
    const double actionBarRadius = 30;

    if (isHost) {
      return Positioned(
        bottom: 20,
        left: 24,
        right: 24,
        child: GestureDetector(
          onTap: () {
            // Navigate to My Parties screen
            // The router config has MyPartiesScreen at /parties
            context.go('/parties');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(actionBarRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Manage Party',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 20,
      left: 24,
      right: 24,
      child: AnimatedBuilder(
        animation: _bunnyAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
                0, _bunnyAnimation.value * 15 * (1 - _bunnyAnimation.value)),
            child: Container(
              decoration: BoxDecoration(
                color: !_isJoined &&
                        !_isPending &&
                        !widget.party.isAcceptingRequests
                    ? Colors.grey.shade600
                    : Theme.of(context).primaryColor,
                borderRadius:
                    BorderRadius.circular(actionBarRadius), // Pill style
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isJoined
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'You\'re part of this party!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: GestureDetector(
                              onTap: () async {
                                // Navigate to party chat
                                await _navigateToPartyChat();
                              },
                              child: const Text(
                                'View Chat',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isPending
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.hourglass_bottom,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Pending approval',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: GestureDetector(
                                  onTap: _isCancellingRequest
                                      ? null
                                      : _handleCancelApplication,
                                  child: _isCancellingRequest
                                      ? const _JoinButtonSpinner(
                                          size: 14,
                                          color: Colors.black87,
                                        )
                                      : const Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: GestureDetector(
                            onTap: (widget.party.isAcceptingRequests &&
                                    !_isJoiningRequest)
                                ? _handleJoinParty
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isJoiningRequest) ...[
                                  const _JoinButtonSpinner(),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Sending request...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    widget.party.isAcceptingRequests
                                        ? (context.read<AuthService>().isGuest
                                            ? Icons.login
                                            : Icons.person_add)
                                        : Icons.block,
                                    color: widget.party.isAcceptingRequests
                                        ? Colors.white
                                        : Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.party.isAcceptingRequests
                                        ? (context.read<AuthService>().isGuest
                                            ? 'Sign In to Continue'
                                            : 'Join Party')
                                        : 'Not Accepting Requests',
                                    style: TextStyle(
                                      color: widget.party.isAcceptingRequests
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // Set status bar to dark content for visibility
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                  0,
                  (1 - _slideAnimation.value) *
                      MediaQuery.of(context).size.height),
              child: Stack(
                children: [
                  // Main content - image and details
                  _buildImageSection(),

                  // Floating header
                  _buildFloatingHeader(),

                  // Fixed join button
                  _buildJoinButton(),
                ],
              ),
            );
          },
        ),
      );
    } catch (e) {
      print('Error in PartyDetailsScreen build: $e');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error,
                color: Colors.white,
                size: 50,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error loading party details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class _JoinButtonSpinner extends StatefulWidget {
  final double size;
  final Color color;

  const _JoinButtonSpinner({
    this.size = 18,
    this.color = Colors.white,
  });

  @override
  State<_JoinButtonSpinner> createState() => _JoinButtonSpinnerState();
}

class _JoinButtonSpinnerState extends State<_JoinButtonSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _JoinButtonSpinnerPainter(
              progress: _controller.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _JoinButtonSpinnerPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _JoinButtonSpinnerPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.5;

    final ringPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final activeArcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * math.pi,
      math.pi * 0.9,
      false,
      activeArcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _JoinButtonSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ModernToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accentColor;

  const _ModernToast({
    required this.message,
    required this.icon,
    required this.accentColor,
  });

  @override
  State<_ModernToast> createState() => _ModernToastState();
}

class _ModernToastState extends State<_ModernToast> {
  bool _visible = false;

  Color _getToastBackground() {
    final accentValue = widget.accentColor.value;

    if (accentValue == const Color(0xFF22C55E).value) {
      return const Color(0xFFE9F7EF);
    }

    if (accentValue == const Color(0xFFEF4444).value) {
      return const Color(0xFFFDEBEC);
    }

    if (accentValue == const Color(0xFFF59E0B).value) {
      return const Color(0xFFFBF2DA);
    }

    return const Color(0xFFE7F1FB);
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final background = _getToastBackground();

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutQuart,
            offset: _visible ? Offset.zero : const Offset(0.16, 0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 260),
              opacity: _visible ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                constraints: const BoxConstraints(maxWidth: 460),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.11),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: widget.accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: Colors.white,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  style: const TextStyle(
                                    color: Color(0xFF101828),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    decoration: TextDecoration.none,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

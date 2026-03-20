import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../models/user_profile.dart';
// import '../models/club.dart';
import '../services/party_service.dart';
import '../services/user_service.dart';
import '../services/club_service.dart';
import '../services/auth_service.dart';
import '../services/saved_service.dart';
import '../theme/app_theme.dart';

class ViewAllPartiesScreen extends StatefulWidget {
  const ViewAllPartiesScreen({super.key, this.isOverlay = false});
  final bool isOverlay;

  @override
  State<ViewAllPartiesScreen> createState() => _ViewAllPartiesScreenState();
}

class _ViewAllPartiesScreenState extends State<ViewAllPartiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, upcoming, ongoing, past
  List<Party> _allParties = [];
  List<Party> _filteredParties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    try {
      final partyService = context.read<PartyService>();
      final parties =
          await partyService.getUpcomingParties(limit: 50); // Get more parties
      setState(() {
        _allParties = parties;
        _filteredParties = parties;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading parties: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterParties() {
    final now = DateTime.now();
    List<Party> filtered = _allParties;

    // Apply category filter
    switch (_selectedFilter) {
      case 'upcoming':
        filtered =
            filtered.where((party) => party.dateTime.isAfter(now)).toList();
        break;
      case 'ongoing':
        final startTime = now.subtract(const Duration(hours: 4));
        final endTime = now.add(const Duration(hours: 4));
        filtered = filtered
            .where((party) =>
                party.dateTime.isAfter(startTime) &&
                party.dateTime.isBefore(endTime))
            .toList();
        break;
      case 'past':
        filtered =
            filtered.where((party) => party.dateTime.isBefore(now)).toList();
        break;
      default:
        // 'all' - no filter
        break;
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered
          .where((party) =>
              party.title.toLowerCase().contains(searchTerm) ||
              party.description.toLowerCase().contains(searchTerm))
          .toList();
    }

    setState(() {
      _filteredParties = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        // Header section
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 24,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          decoration: BoxDecoration(
            color: AppTheme.colors.primary,
            borderRadius: widget.isOverlay
                ? const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  )
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (widget.isOverlay) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'All Parties',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Filter options')),
                  );
                },
                icon: const Icon(Icons.filter_list, color: Colors.white),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Column(
            children: [
              // Search and filter section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _filterParties(),
                      decoration: InputDecoration(
                        hintText: 'Search parties...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Upcoming', 'upcoming'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Ongoing', 'ongoing'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Past', 'past'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Parties grid
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredParties.isEmpty
                        ? _buildEmptyState()
                        : _buildPartiesGrid(),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isOverlay) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: content,
          );
        },
      );
    } else {
      return Scaffold(
        extendBodyBehindAppBar: true,
        body: content,
      );
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        _filterParties();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.colors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.colors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            color: Colors.grey.shade400,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No parties found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredParties.length,
      itemBuilder: (context, index) {
        final party = _filteredParties[index];
        return _PartyCard(party: party);
      },
    );
  }
}

class _PartyCard extends StatefulWidget {
  const _PartyCard({required this.party});
  final Party party;

  @override
  State<_PartyCard> createState() => _PartyCardState();
}

class _PartyCardState extends State<_PartyCard> {
  String? _clubName;
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadClubName();
  }

  Future<void> _loadClubName() async {
    try {
      final clubService = context.read<ClubService>();

      // First try to get the club by ID (handles both static and dynamic clubs)
      final club = await clubService.getById(widget.party.clubId);

      if (club != null) {
        if (mounted) {
          setState(() {
            _clubName = club.name;
          });
        }
      } else {
        // If club not found, try to get venue details from Google Places
        try {
          // Extract the original placeId from the unique ID
          final placeId = widget.party.clubId.split('_')[0];
          final placeDetails = await clubService.getVenueDetails(placeId);
          if (placeDetails != null && mounted) {
            setState(() {
              _clubName = placeDetails.name ?? 'Unknown Venue';
            });
          } else if (mounted) {
            setState(() {
              _clubName = 'Unknown Venue';
            });
          }
        } catch (e) {
          print('Error getting venue details: $e');
          if (mounted) {
            setState(() {
              _clubName = 'Unknown Venue';
            });
          }
        }
      }
    } catch (e) {
      print('Error loading club name: $e');
      if (mounted) {
        setState(() {
          _clubName = 'Unknown Venue';
        });
      }
    }
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

  Widget _buildCompactJoinerProfilePictures(List<String> attendeeIds) {
    if (attendeeIds.isEmpty) return const SizedBox.shrink();

    // Show up to 2 profile pictures, then count if more
    final displayCount = attendeeIds.length > 2 ? 2 : attendeeIds.length;
    final remainingCount = attendeeIds.length > 2 ? attendeeIds.length - 2 : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayCount; i++)
          FutureBuilder<UserProfile?>(
            future: context.read<UserService>().getUserProfile(attendeeIds[i]),
            builder: (context, snapshot) {
              return Container(
                margin: EdgeInsets.only(right: i < displayCount - 1 ? 8 : 0),
                child: CircleAvatar(
                  radius: 16, // Much bigger radius
                  backgroundImage:
                      snapshot.hasData && snapshot.data?.profileImageUrl != null
                          ? NetworkImage(snapshot.data!.profileImageUrl!)
                          : null,
                  backgroundColor: Colors.grey.shade300,
                  child:
                      snapshot.hasData && snapshot.data?.profileImageUrl == null
                          ? Icon(Icons.person,
                              size: 16,
                              color: Colors.grey.shade600) // Much bigger icon
                          : null,
                ),
              );
            },
          ),
        // Remaining count
        if (remainingCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey.shade600,
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/party-details?id=${widget.party.id}');
      },
      child: Container(
        width: 280,
        height: 360,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (60% of card height)
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  // Party image
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
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
                  ),
                  // Date circle overlay (top left)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getMonthName(widget.party.dateTime.month),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            widget.party.dateTime.day.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Favorite icon (top right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () async {
                        // Add favorite functionality here if needed
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_border,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content section (40% of card height)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Party title and budget per head
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.party.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          widget.party.budgetPerHead != null
                              ? '₱${widget.party.budgetPerHead} / head'
                              : 'Free Entry',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Address
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _clubName ?? 'Loading...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Description (only if there's space)
                    if (widget.party.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          widget.party.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Join counter and Join Now button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Profile stacks and counter
                        Row(
                          children: [
                            _buildProfileStacks(widget.party.attendeeUserIds),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.colors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppTheme.colors.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 12,
                                    color: AppTheme.colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.party.attendeeUserIds.length}/${widget.party.capacity}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'joining',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Join Now button - REMOVED
                        // Container(
                        //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        //   decoration: BoxDecoration(
                        //     color: AppTheme.colors.primary,
                        //     borderRadius: BorderRadius.circular(16),
                        //   ),
                        //   child: const Text(
                        //     'Join Now',
                        //     style: TextStyle(
                        //       fontSize: 11,
                        //       fontWeight: FontWeight.w600,
                        //       color: Colors.white,
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

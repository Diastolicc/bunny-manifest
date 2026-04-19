import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../services/club_service.dart';
import '../theme/app_theme.dart';
import '../widgets/venue_card.dart';
import 'home_screen.dart'; // Import for _VenueCard if it was public, but since it's private in HomeScreen, we might need to duplicate or make it public.
// Assuming VenueCard is what we want, but the user said "copy the look of view all parties screen" which uses OngoingPartyCard.
// However, for Venues, we should probably use a card suited for venues.
// The home screen uses a private _VenueCard.
// Let's create a similar card here or use the existing VenueCard if suitable.
// Looking at file list, there is lib/widgets/venue_card.dart. Let's use that if possible or recreate the look.
// For now, I will recreate the look of _VenueCard from HomeScreen but adapted for this list.

class ViewAllVenuesScreen extends StatefulWidget {
  const ViewAllVenuesScreen({super.key, this.isOverlay = false});
  final bool isOverlay;

  @override
  State<ViewAllVenuesScreen> createState() => _ViewAllVenuesScreenState();
}

class _ViewAllVenuesScreenState extends State<ViewAllVenuesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Club> _allVenues = [];
  List<Club> _filteredVenues = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    try {
      final clubService = context.read<ClubService>();
      final venues = await clubService.listClubs(limit: 50);
      setState(() {
        _allVenues = venues;
        _isLoading = false;
      });
      _filterVenues();
    } catch (e) {
      print('Error loading venues: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterVenues() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVenues = _allVenues.where((club) {
        final matchesSearch = club.name.toLowerCase().contains(query) ||
            club.location.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'All' ||
            club.categories.contains(_selectedCategory);
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 24,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            children: [
              // Back button
              IconButton(
                onPressed: () {
                  if (widget.isOverlay) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.black87, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              // Title
              const Text(
                'All Venues',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Filter button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black87, width: 2),
                ),
                child: IconButton(
                  onPressed: () {
                    // Show simple category filter sheet
                    _showFilterSheet();
                  },
                  icon: const Icon(Icons.filter_list,
                      color: Colors.black87, size: 20),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Column(
            children: [
              // Search section
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterVenues(),
                  decoration: InputDecoration(
                    hintText: 'Search venues...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ),

              // Categories pill list (optional, derived from data)
              // For simplicity, we can skip or add static categories if needed here.
              // Let's rely on the filter button for now to keep it clean like ViewAllPartiesScreen.

              // Venues list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredVenues.isEmpty
                        ? _buildEmptyState()
                        : _buildVenuesList(),
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'All',
                  'Nightclub',
                  'Bar',
                  'Lounge',
                  'Rooftop',
                  'Live Music'
                ].map((category) {
                  final isSelected = _selectedCategory == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _filterVenues();
                      Navigator.pop(context);
                    },
                    selectedColor: AppTheme.colors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory,
            color: Colors.grey.shade400,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No venues found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenuesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredVenues.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final club = _filteredVenues[index];
        return VenueListItem(club: club);
      },
    );
  }
}

class VenueListItem extends StatelessWidget {
  final Club club;

  const VenueListItem({super.key, required this.club});

  String _getVenueImage(String venueName) {
    final List<String> venueImages = [
      'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1566733971017-f8a6c8c2c6b3?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1520975916090-3105956d8ac38?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1517095037594-166575f1e866?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400&h=300&fit=crop',
    ];
    final int hash = venueName.hashCode;
    return venueImages[hash.abs() % venueImages.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/club/${club.id}'),
      child: Container(
        width: 300,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        club.imageUrl.isNotEmpty
                            ? club.imageUrl
                            : _getVenueImage(club.name),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey.shade300,
                                  Colors.grey.shade400,
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 28,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              club.rating > 0
                                  ? club.rating.toStringAsFixed(1)
                                  : 'New',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          club.distanceKm > 0
                              ? '${club.distanceKm.toStringAsFixed(1)} km'
                              : 'Nearby',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          club.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        size: 18,
                        color: Color(0xFF8d58b5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    club.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (club.categories.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            club.categories.first,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Icon(
                        Icons.local_bar,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          club.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

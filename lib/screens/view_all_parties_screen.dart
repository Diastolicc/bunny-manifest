import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/party.dart';
import '../models/user_profile.dart';
import '../services/party_service.dart';
import '../services/user_service.dart';
import '../services/club_service.dart';
import '../services/auth_service.dart';
import '../services/saved_service.dart';
import '../services/local_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ongoing_party_card.dart';

class ViewAllPartiesScreen extends StatefulWidget {
  const ViewAllPartiesScreen({super.key, this.isOverlay = false});
  final bool isOverlay;

  @override
  State<ViewAllPartiesScreen> createState() => _ViewAllPartiesScreenState();
}

class _ViewAllPartiesScreenState extends State<ViewAllPartiesScreen> {
  final TextEditingController _searchController = TextEditingController();
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
        _isLoading = false;
      });
      _filterParties();
    } catch (e) {
      print('Error loading parties: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterParties() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParties = _allParties.where((party) {
        final matchesSearch = party.title.toLowerCase().contains(query);
        return matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        // Header - Using home screen design
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
                'All Parties',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Filter button with circle border
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Filter options')),
                    );
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredParties.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final party = _filteredParties[index];
        return OngoingPartyCard(
          party: party,
          // Since we might not have user location here easily, we can pass null or try to get it from a provider if available
          // For now we leave them null, the card handles null gracefully (distance will be from club data if available)
        );
      },
    );
  }
}

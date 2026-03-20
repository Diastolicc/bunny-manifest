import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:bunny/services/club_service.dart';
import 'package:bunny/models/club.dart';

class AdminManageClubsScreen extends StatefulWidget {
  const AdminManageClubsScreen({super.key});

  @override
  State<AdminManageClubsScreen> createState() => _AdminManageClubsScreenState();
}

class _AdminManageClubsScreenState extends State<AdminManageClubsScreen> {
  List<Club> _clubs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clubService = context.read<ClubService>();
      final clubs = await clubService.getAllClubs();
      if (mounted) {
        setState(() {
          _clubs = clubs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading clubs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading clubs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Club> get _filteredClubs {
    if (_searchQuery.isEmpty) {
      return _clubs;
    }
    return _clubs.where((club) {
      return club.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          club.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          club.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Clubs',
          style: TextStyle(
            color: AppTheme.colors.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppTheme.colors.primary),
            onPressed: () {
              // TODO: Add new club functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add Club - Coming Soon'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                hintStyle: TextStyle(color: AppTheme.colors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppTheme.colors.textSecondary),
                filled: true,
                fillColor: AppTheme.colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: AppTheme.colors.text),
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Total Clubs: ${_filteredClubs.length}',
                  style: TextStyle(
                    color: AppTheme.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: AppTheme.colors.primary),
                  onPressed: _loadClubs,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Clubs List
          Expanded(
            child: _isLoading
                ? Center(
                    child: SpinKitWaveSpinner(
                      color: AppTheme.colors.primary,
                      size: 50.0,
                    ),
                  )
                : _filteredClubs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_city,
                              size: 64,
                              color: AppTheme.colors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No clubs found',
                              style: TextStyle(
                                color: AppTheme.colors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadClubs,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredClubs.length,
                          itemBuilder: (context, index) {
                            final club = _filteredClubs[index];
                            return _buildClubCard(club);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(Club club) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showClubDetails(club);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Club Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: club.imageUrl.isNotEmpty
                      ? Image.network(
                          club.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: AppTheme.colors.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.location_city,
                                color: AppTheme.colors.primary,
                                size: 32,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: AppTheme.colors.primary.withOpacity(0.1),
                          child: Icon(
                            Icons.location_city,
                            color: AppTheme.colors.primary,
                            size: 32,
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Club Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: TextStyle(
                          color: AppTheme.colors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppTheme.colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              club.location,
                              style: TextStyle(
                                color: AppTheme.colors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            club.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: AppTheme.colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (club.categories.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.colors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                club.categories.first,
                                style: TextStyle(
                                  color: AppTheme.colors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    color: AppTheme.colors.textSecondary,
                  ),
                  onPressed: () {
                    _showClubActions(club);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClubActions(Club club) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),

              // Club name header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  club.name,
                  style: TextStyle(
                    color: AppTheme.colors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Edit action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showEditClubDialog(club);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: AppTheme.colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Club',
                                style: TextStyle(
                                  color: AppTheme.colors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Modify club information',
                                style: TextStyle(
                                  color: AppTheme.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppTheme.colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Divider(
                height: 1,
                color: AppTheme.colors.textSecondary.withOpacity(0.1),
                indent: 76,
              ),

              // Delete action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteClub(club);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delete Club',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Remove club permanently',
                                style: TextStyle(
                                  color: AppTheme.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showClubDetails(Club club) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppTheme.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Club Image
              if (club.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    club.imageUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 20),

              // Details
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        style: TextStyle(
                          color: AppTheme.colors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: AppTheme.colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            club.location,
                            style: TextStyle(
                              color: AppTheme.colors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 20,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            club.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: AppTheme.colors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 20),
                          if (club.distanceKm > 0) ...[
                            Icon(
                              Icons.location_pin,
                              size: 20,
                              color: AppTheme.colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${club.distanceKm.toStringAsFixed(1)} km',
                              style: TextStyle(
                                color: AppTheme.colors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (club.categories.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: club.categories.map((category) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.colors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: AppTheme.colors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (club.description.isNotEmpty) ...[
                        Text(
                          'Description',
                          style: TextStyle(
                            color: AppTheme.colors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          club.description,
                          style: TextStyle(
                            color: AppTheme.colors.textSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Club ID',
                        style: TextStyle(
                          color: AppTheme.colors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        club.id,
                        style: TextStyle(
                          color: AppTheme.colors.textSecondary,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteClub(Club club) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Club'),
          content: Text('Are you sure you want to delete "${club.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteClub(club);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteClub(Club club) async {
    try {
      final clubService = context.read<ClubService>();
      await clubService.deleteClub(club.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${club.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadClubs(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting club: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditClubDialog(Club club) {
    final nameController = TextEditingController(text: club.name);
    final locationController = TextEditingController(text: club.location);
    final descriptionController = TextEditingController(text: club.description);
    final imageUrlController = TextEditingController(text: club.imageUrl);
    final ratingController = TextEditingController(text: club.rating.toString());
    final categoriesController = TextEditingController(text: club.categories.join(', '));
    final mapsLinkController = TextEditingController(text: club.mapsLink);
    final cityController = TextEditingController(text: club.city);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Club'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Club Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mapsLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Maps Link (URL)',
                    border: OutlineInputBorder(),
                    helperText: 'Google Maps or Apple Maps URL',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ratingController,
                  decoration: const InputDecoration(
                    labelText: 'Rating (0.0 - 5.0)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoriesController,
                  decoration: const InputDecoration(
                    labelText: 'Categories (comma separated)',
                    border: OutlineInputBorder(),
                    helperText: 'e.g., EDM, Dance, Rooftop',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameController.dispose();
                locationController.dispose();
                descriptionController.dispose();
                imageUrlController.dispose();
                ratingController.dispose();
                categoriesController.dispose();
                mapsLinkController.dispose();
                cityController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Read values before disposing
                final name = nameController.text;
                final location = locationController.text;
                final description = descriptionController.text;
                final imageUrl = imageUrlController.text;
                final rating = ratingController.text;
                final categories = categoriesController.text;
                final mapsLink = mapsLinkController.text;
                final city = cityController.text;
                
                // Dispose controllers
                nameController.dispose();
                locationController.dispose();
                descriptionController.dispose();
                imageUrlController.dispose();
                ratingController.dispose();
                categoriesController.dispose();
                mapsLinkController.dispose();
                cityController.dispose();
                
                Navigator.pop(context);
                
                // Call update with the saved values
                _updateClub(
                  club,
                  name,
                  location,
                  description,
                  imageUrl,
                  rating,
                  categories,
                  mapsLink,
                  city,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateClub(
    Club club,
    String name,
    String location,
    String description,
    String imageUrl,
    String ratingStr,
    String categoriesStr,
    String mapsLink,
    String city,
  ) async {
    try {
      // Validate inputs
      if (name.trim().isEmpty) {
        throw Exception('Club name cannot be empty');
      }

      double rating = double.tryParse(ratingStr) ?? club.rating;
      if (rating < 0 || rating > 5) {
        throw Exception('Rating must be between 0 and 5');
      }

      List<String> categories = categoriesStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final clubService = context.read<ClubService>();
      await clubService.updateClub(club.id, {
        'name': name.trim(),
        'location': location.trim(),
        'description': description.trim(),
        'imageUrl': imageUrl.trim(),
        'rating': rating,
        'categories': categories,
        'mapsLink': mapsLink.trim(),
        'city': city.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${name.trim()} updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadClubs(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating club: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

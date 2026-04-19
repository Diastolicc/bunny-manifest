// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../models/club.dart';
import '../models/party.dart';
import '../models/user_profile.dart';
import '../services/club_service.dart';
import '../services/party_service.dart';
import '../services/saved_service.dart';
import '../services/user_service.dart';
import '../services/local_cache_service.dart';
import '../services/notification_service.dart';
import '../services/banner_service.dart';
import '../models/banner_config.dart';
import '../theme/app_theme.dart';
import 'club_detail_screen.dart';
import 'create_party_screen.dart';
import 'view_all_venues_screen.dart';
import '../widgets/ongoing_party_card.dart';

class HomeScreen extends StatefulWidget {
  final String? scrollToClubId;

  const HomeScreen({super.key, this.scrollToClubId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Future<void> _showCreatePartyAuthPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Login Required'),
          content: const Text(
            'You need to be logged in to create a party. Please log in or create an account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/login');
              },
              child: const Text('Log In / Create Account'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHugeCrowdTab() {
    return FutureBuilder<List<Party>>(
      future: _upcomingPartiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No huge crowd parties'),
          );
        }

        final parties = [...snapshot.data!];
        // Sort by capacity descending to show biggest parties first
        parties.sort((a, b) => b.capacity.compareTo(a.capacity));

        return SizedBox(
          height: 380,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 8),
            itemCount: parties.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final party = parties[index];
              return SizedBox(
                width: 300,
                child: OngoingPartyCard(
                  party: party,
                  userLatitude: _userLatitude,
                  userLongitude: _userLongitude,
                ),
              );
            },
          ),
        );
      },
    );
  }

  late Future<List<Party>> _upcomingPartiesFuture;
  Future<List<Party>>? _ongoingPartiesFuture;
  Future<List<Club>>? _hotVenuesFuture;
  Future<BannerConfig?>? _bannerFuture;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _currentCity = 'Loading...';
  double? _userLatitude;
  double? _userLongitude;

  // Filter states
  String _selectedDateFilter = 'all';
  String _selectedPartyType = 'all';
  String _selectedPeopleFilter = 'all';
  String _searchQuery = '';
  String? _selectedMood;

  String _selectedLocationFilter = 'Poblacion'; // New state for location filter

  // Date slider states
  List<DateTime> _dates = [];
  DateTime? _selectedDateForQuickAccess;

  // Scroll-based header state
  bool _isHeaderMinimized = false;

  // Bunny points popup state
  bool _showBunnyPointsPopup = true;

  // Loading state for upcoming parties (used to avoid layout flashes)
  bool _isUpcomingLoading = false;

  // Animation state for location filter
  late AnimationController _locationFilterAnimController;
  late Animation<double> _locationFilterScaleAnimation;
  late Animation<Offset> _locationFilterSlideAnimation;

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentCity = 'Location disabled';
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentCity = 'Permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentCity = 'Permission denied';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Store user coordinates
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });

      // Get city name from coordinates
      print(
          'HomeScreen: Getting location for coordinates: ${position.latitude}, ${position.longitude}');
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.administrativeArea ?? 'Unknown';
        print('Location detected: $city');
        print('Full address: ${place.toString()}');
        print('Locality: ${place.locality}');
        print('Administrative Area: ${place.administrativeArea}');
        print('Country: ${place.country}');
        setState(() {
          _currentCity = city;
        });
      } else {
        print('No placemarks found');
        setState(() {
          _currentCity = 'Unknown location';
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _currentCity = 'Location error';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    print(
        'HomeScreen: Initialized with scrollToClubId: ${widget.scrollToClubId}');
    _upcomingPartiesFuture = Future.value(<Party>[]);
    _hotVenuesFuture = _getHotVenues();
    _bannerFuture = _loadBanner();
    _loadUpcomingParties();
    _loadOngoingParties();
    _getCurrentLocation();
    _generateDates();

    // Initialize location filter animation
    _locationFilterAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _locationFilterScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _locationFilterAnimController, curve: Curves.elasticOut),
    );

    _locationFilterSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _locationFilterAnimController, curve: Curves.easeOut),
    );

    // Start animation after a small delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _locationFilterAnimController.forward();
      }
    });

    // Listen to search changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        // Clear selected mood if search is empty
        if (_searchController.text.isEmpty) {
          _selectedMood = null;
        }
      });
    });

    // Add scroll listener for header minimization
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _locationFilterAnimController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    const threshold = 100.0; // Scroll threshold to trigger header change

    if (currentOffset > threshold && !_isHeaderMinimized) {
      setState(() {
        _isHeaderMinimized = true;
      });
    } else if (currentOffset <= threshold && _isHeaderMinimized) {
      setState(() {
        _isHeaderMinimized = false;
      });
    }
  }

  void _generateDates() {
    final now = DateTime.now();
    // Generate dates for the next 14 days
    _dates = List.generate(14, (index) => now.add(Duration(days: index)));
    _selectedDateForQuickAccess = null; // Start with ALL selected
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildMinimizedHeader() {
    return Row(
      children: [
        // Bunny logo (left)
        Container(
          height: 30, // 5% smaller than 32px
          width: 143, // 5% smaller than 150px
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/logos/bunny_logo.png',
            height: 30,
            width: 143,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to text if image not found
              return Text(
                'bunny',
                style: _sectionHeaderStyle,
              );
            },
          ),
        ),

        // Spacer to push location to right
        const Spacer(),

        // Location pill (smaller)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: Colors.grey.shade700,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                _currentCity,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildExpandedHeader() {
    return Row(
      children: [
        // Bunny logo (left)
        Container(
          height: 30, // 5% smaller than 32px
          width: 143, // 5% smaller than 150px
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/logos/bunny_logo.png',
            height: 30,
            width: 143,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to text if image not found
              return Text(
                'bunny',
                style: _sectionHeaderStyle,
              );
            },
          ),
        ),

        // Spacer to push location to right
        const Spacer(),

        // Location pill (smaller)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: Colors.grey.shade700,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                _currentCity,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          // Input Field
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search parties...', // Corresponds to "Write here..."
                hintStyle: TextStyle(color: Colors.grey.shade500),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadUpcomingParties();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Action Button - Hidden for later use
          // GestureDetector(
          //   onTap: () {
          //     // Filter button - will be implemented later
          //   },
          // )
        ],
      ),
    );
  }

  Widget _buildMoodPills() {
    final moods = [
      'Dancing',
      'Chill',
      'Adventure',
      'Social',
      'Party',
      'Romantic',
      'Sports',
      'Food',
      'Music',
      'Art',
      'Gaming',
      'Travel',
    ];

    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          return Padding(
            padding: EdgeInsets.only(right: index < moods.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                // Set search query and trigger search
                _searchController.text = mood;
                setState(() {
                  _searchQuery = mood;
                  _selectedMood = mood;
                });
                _loadUpcomingParties();
                // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Searching for: $mood'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedMood == mood
                      ? AppTheme.colors.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  mood,
                  style: TextStyle(
                    color: _selectedMood == mood
                        ? Colors.white
                        : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    final isAllSelected = _selectedDateForQuickAccess == null;

    return SizedBox(
      height: 80,
      child: Row(
        children: [
          // Sticky "ALL" Card
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDateForQuickAccess = null; // null represents "ALL"
              });
              _loadUpcomingParties();
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(left: 0, right: 12),
              decoration: BoxDecoration(
                color: isAllSelected
                    ? AppTheme.colors.primary
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAllSelected
                      ? AppTheme.colors.primary
                      : Colors.grey.shade100,
                  width: 1.5,
                ),
                boxShadow: isAllSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.colors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  'ALL',
                  style: TextStyle(
                    color: isAllSelected
                        ? Colors.white
                        : AppTheme.colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Scrollable Date List
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              itemCount: _dates.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isToday = _isSameDate(date, today);
                final isSelected = _selectedDateForQuickAccess != null &&
                    _isSameDate(date, _selectedDateForQuickAccess!);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDateForQuickAccess = date;
                    });
                    _loadUpcomingParties();
                  },
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.colors.primary
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.colors.primary
                            : Colors.grey.shade100,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.colors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isToday)
                          Text(
                            'NOW',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          )
                        else
                          Text(
                            _getDayName(date),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  Widget _buildLocationIcon() {
    final locations = [
      'Poblacion',
      'BGC',
      'Tomas Morato',
      'Makati',
      'Quezon City',
      'Pasig'
    ];

    // Auto-select first location on init if not already selected
    if (_selectedLocationFilter == 'All') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedLocationFilter = locations.first;
          });
          _loadUpcomingParties();
        }
      });
    }

    return AnimatedBuilder(
      animation: _locationFilterAnimController,
      builder: (context, child) {
        return SlideTransition(
          position: _locationFilterSlideAnimation,
          child: ScaleTransition(
            scale: _locationFilterScaleAnimation,
            alignment: Alignment.centerRight,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.colors.background,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            Icons.location_on,
            color: AppTheme.colors.primary,
            size: 20,
          ),
          onPressed: () {
            // Cycle through available locations on tap
            final locations = [
              'Poblacion',
              'BGC',
              'Tomas Morato',
              'Makati',
              'Quezon City',
              'Pasig'
            ];
            final currentIndex = locations.indexOf(_selectedLocationFilter);
            final nextIndex = (currentIndex + 1) % locations.length;
            setState(() {
              _selectedLocationFilter = locations[nextIndex];
            });
            _loadUpcomingParties();
            HapticFeedback.mediumImpact();
          },
        ),
      ),
    );
  }

  // Check if there are any active filters
  bool _hasActiveFilters() {
    return _selectedDateFilter != 'all' ||
        _selectedPartyType != 'all' ||
        _selectedPeopleFilter != 'all';
  }

  // Show search modal
  void _showSearchModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.only(top: 60, left: 16, right: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search input
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search parties...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                            _loadUpcomingParties();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                  _loadUpcomingParties();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show filter modal
  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterModal(),
    );
  }

  // Build the filter modal content
  Widget _buildFilterModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: AppTheme.colors.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filter Parties',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedDateFilter = 'all';
                      _selectedPartyType = 'all';
                      _selectedPeopleFilter = 'all';
                    });
                    _loadUpcomingParties();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date Filter Section
            _buildFilterSection(
              title: 'Date',
              icon: Icons.calendar_today,
              child: _buildModernDatePicker(),
            ),
            const SizedBox(height: 12),

            // Type Filter Section
            _buildFilterSection(
              title: 'Type',
              icon: Icons.category,
              child: _buildModernTypeSelector(),
            ),
            const SizedBox(height: 12),

            // People Filter Section
            _buildFilterSection(
              title: 'People',
              icon: Icons.people,
              child: _buildModernPeopleSelector(),
            ),
            const SizedBox(height: 20),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _loadUpcomingParties();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build filter section wrapper
  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: AppTheme.colors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildModernDatePicker() {
    return GestureDetector(
      onTap: () => _showDatePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _getDateDisplayText(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPartyType,
          isExpanded: true,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey.shade600,
            size: 20,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.all_inclusive,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  const Text('All Types'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'club',
              child: Row(
                children: [
                  Icon(Icons.nightlife, size: 18, color: Colors.purple),
                  const SizedBox(width: 12),
                  const Text('Club'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'bar',
              child: Row(
                children: [
                  Icon(Icons.local_bar, size: 18, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text('Bar'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'restaurant',
              child: Row(
                children: [
                  Icon(Icons.restaurant, size: 18, color: Colors.green),
                  const SizedBox(width: 12),
                  const Text('Restaurant'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'outdoor',
              child: Row(
                children: [
                  Icon(Icons.park, size: 18, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text('Outdoor'),
                ],
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _selectedPartyType = value;
              });
              _loadUpcomingParties();
            }
          },
        ),
      ),
    );
  }

  Widget _buildModernPeopleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeopleFilter,
          isExpanded: true,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.grey.shade600,
            size: 20,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Row(
                children: [
                  Icon(Icons.all_inclusive,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  const Text('All Sizes'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: '1-5',
              child: Row(
                children: [
                  Icon(Icons.group, size: 18, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text('1-5 people'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: '6-10',
              child: Row(
                children: [
                  Icon(Icons.groups, size: 18, color: Colors.green),
                  const SizedBox(width: 12),
                  const Text('6-10 people'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: '11-20',
              child: Row(
                children: [
                  Icon(Icons.groups_2, size: 18, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text('11-20 people'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: '20+',
              child: Row(
                children: [
                  Icon(Icons.groups_3, size: 18, color: Colors.red),
                  const SizedBox(width: 12),
                  const Text('20+ people'),
                ],
              ),
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _selectedPeopleFilter = value;
              });
              _loadUpcomingParties();
            }
          },
        ),
      ),
    );
  }

  String _getDateDisplayText() {
    switch (_selectedDateFilter) {
      case 'today':
        return 'Today';
      case 'tomorrow':
        return 'Tomorrow';
      case 'this week':
        return 'This Week';
      case 'next week':
        return 'Next Week';
      default:
        return 'All Dates';
    }
  }

  void _showDatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...['all', 'today', 'tomorrow', 'this week', 'next week']
                      .map((option) {
                    return ListTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: _selectedDateFilter == option
                            ? AppTheme.colors.primary
                            : Colors.grey.shade400,
                      ),
                      title: Text(
                        option == 'all'
                            ? 'All Dates'
                            : option == 'today'
                                ? 'Today'
                                : option == 'tomorrow'
                                    ? 'Tomorrow'
                                    : option == 'this week'
                                        ? 'This Week'
                                        : 'Next Week',
                        style: TextStyle(
                          color: _selectedDateFilter == option
                              ? AppTheme.colors.primary
                              : Colors.grey.shade700,
                          fontWeight: _selectedDateFilter == option
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: _selectedDateFilter == option
                          ? Icon(Icons.check, color: AppTheme.colors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedDateFilter = option;
                        });
                        _loadUpcomingParties();
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipWithLabel(String label, String selectedValue,
      List<String> options, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selectedValue == 'all'
                  ? Colors.grey.shade300
                  : AppTheme.colors.primary,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              style: TextStyle(
                color: selectedValue == 'all'
                    ? Colors.grey.shade700
                    : AppTheme.colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: selectedValue == 'all'
                    ? Colors.grey.shade700
                    : AppTheme.colors.primary,
                size: 12,
              ),
              dropdownColor: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              items: options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String selectedValue,
      List<String> options, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedValue == 'all'
              ? Colors.grey.shade300
              : AppTheme.colors.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isExpanded: true,
          style: TextStyle(
            color: selectedValue == 'all'
                ? Colors.grey.shade700
                : AppTheme.colors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: selectedValue == 'all'
                ? Colors.grey.shade700
                : AppTheme.colors.primary,
            size: 14,
          ),
          dropdownColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterDropdownWithLabel(String label, String selectedValue,
      List<String> options, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selectedValue == 'all'
                ? Colors.grey.shade200
                : AppTheme.colors.primary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selectedValue == 'all'
                  ? Colors.grey.shade300
                  : AppTheme.colors.primary,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              style: TextStyle(
                color: selectedValue == 'all'
                    ? Colors.grey.shade700
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: selectedValue == 'all'
                    ? Colors.grey.shade700
                    : Colors.white,
                size: 16,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      value == 'all'
                          ? 'All ${label.toLowerCase()}'
                          : value.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Party> _applyFilters(List<Party> parties) {
    List<Party> filtered = parties;

    print(
        '_applyFilters: _selectedDateForQuickAccess = $_selectedDateForQuickAccess');
    if (_selectedDateForQuickAccess != null) {
      print('Filtering by date...');
      int before = filtered.length;
      filtered = filtered.where((party) {
        final matches =
            _isSameDate(party.dateTime, _selectedDateForQuickAccess!);
        if (matches) {
          print('  MATCH: ${party.title} on ${party.dateTime}');
        }
        return matches;
      }).toList();
      print('Filtered: $before -> ${filtered.length}');
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((party) {
        return party.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            party.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply date filter from modal
    if (_selectedDateFilter != 'all') {
      final now = DateTime.now();
      filtered = filtered.where((party) {
        switch (_selectedDateFilter) {
          case 'today':
            return party.dateTime.day == now.day &&
                party.dateTime.month == now.month &&
                party.dateTime.year == now.year;
          case 'tomorrow':
            final tomorrow = now.add(const Duration(days: 1));
            return party.dateTime.day == tomorrow.day &&
                party.dateTime.month == tomorrow.month &&
                party.dateTime.year == tomorrow.year;
          case 'this week':
            final weekEnd = now.add(const Duration(days: 7));
            return party.dateTime.isAfter(now) &&
                party.dateTime.isBefore(weekEnd);
          case 'next week':
            final nextWeekStart = now.add(const Duration(days: 7));
            final nextWeekEnd = now.add(const Duration(days: 14));
            return party.dateTime.isAfter(nextWeekStart) &&
                party.dateTime.isBefore(nextWeekEnd);
          default:
            return true;
        }
      }).toList();
    }

    // Apply people filter
    if (_selectedPeopleFilter != 'all') {
      filtered = filtered.where((party) {
        final attendeeCount = party.attendeeUserIds.length;
        switch (_selectedPeopleFilter) {
          case '1-5':
            return attendeeCount >= 1 && attendeeCount <= 5;
          case '6-10':
            return attendeeCount >= 6 && attendeeCount <= 10;
          case '11-20':
            return attendeeCount >= 11 && attendeeCount <= 20;
          case '20+':
            return attendeeCount > 20;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  Future<void> _loadUpcomingParties() async {
    try {
      if (mounted) {
        setState(() {
          _isUpcomingLoading = true;
        });
      }
      print(
          '_loadUpcomingParties START - selectedDate: $_selectedDateForQuickAccess');
      print('Loading from database...');
      final partyService = context.read<PartyService>();
      final allParties = await partyService.getUpcomingParties(limit: 50);
      print('Got ${allParties.length} parties from DB');

      // Print all party dates to see what we're working with
      for (var p in allParties.take(5)) {
        print('Party: ${p.title} - Date: ${p.dateTime}');
      }

      // Cache the loaded parties
      await LocalCacheService.cacheParties(allParties);

      print('About to call _applyFilters with ${allParties.length} parties');
      final filteredParties = _applyFilters(allParties);
      print('After filtering: ${filteredParties.length} parties');

      setState(() {
        _upcomingPartiesFuture = Future.value(filteredParties);
      });
    } catch (e) {
      print('ERROR: $e');
      setState(() {
        _upcomingPartiesFuture = Future.value(<Party>[]);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpcomingLoading = false;
        });
      }
    }
  }

  Future<void> _loadOngoingParties() async {
    try {
      print('Loading ongoing parties...');

      // Always load from database first (bypass cache for debugging)
      print('Loading ongoing parties from database...');
      final partyService = context.read<PartyService>();
      final allParties = await partyService.getAllParties();
      print('All parties from database: ${allParties.length}');

      // Cache the loaded parties
      await LocalCacheService.cacheParties(allParties);

      // Filter parties happening today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      print('Today: $today, Tomorrow: $tomorrow');

      final ongoingParties = allParties.where((party) {
        final partyDate = DateTime(
            party.dateTime.year, party.dateTime.month, party.dateTime.day);
        return partyDate.isAtSameMomentAs(today) ||
            (partyDate.isAfter(today) && partyDate.isBefore(tomorrow));
      }).toList();

      print('✅ Loaded ${ongoingParties.length} ongoing parties');
      setState(() {
        _ongoingPartiesFuture = Future.value(ongoingParties);
      });
    } catch (e) {
      print('❌ Error loading ongoing parties: $e');
      setState(() {
        _ongoingPartiesFuture = Future.value(<Party>[]);
      });
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadUpcomingParties(),
      _loadOngoingParties(),
    ]);
    // Refresh hot venues
    setState(() {
      _hotVenuesFuture = _getHotVenues();
    });
  }

  // Method to refresh data when returning from other screens
  void refreshOnReturn() {
    _refreshData();
  }

  Widget _buildBannerImage() {
    return FutureBuilder<BannerConfig?>(
      future: _bannerFuture,
      builder: (context, snapshot) {
        print(
            'BannerImage: ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, Data: ${snapshot.data?.imageUrl}');

        // Default banner URL if no banner is set in database
        final defaultBannerUrl =
            'https://firebasestorage.googleapis.com/v0/b/bunny-59131.firebasestorage.app/o/photo-1516450360452-9312f5e86fc7%20copy.jpg?alt=media&token=77aafb88-ece6-4d0e-bfd9-1b7ea6874667';
        final imageUrl = snapshot.data?.imageUrl ?? defaultBannerUrl;

        print('BannerImage: Using imageUrl: $imageUrl');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Background Image
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A1A2E),
                            const Color(0xFF16213E),
                            const Color(0xFF0F3460),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.nightlife,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHotVenuesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with View All Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar icon removed
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bunny logo replaced with section text
                  const Text(
                    'Bars and Venues',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/view-all-venues'),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF8d58b5),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Removed 'Hey, User' section header
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Venues List
        FutureBuilder<List<Club>>(
          future: _hotVenuesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: Text(
                    'No venues available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            final venues = snapshot.data!;
            // Max 8 venues displayed
            final displayVenues = venues.take(8).toList();
            final itemCount = displayVenues.length;

            return SizedBox(
              height: 280, // Reduced height to match venue list item
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: itemCount,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final venue = displayVenues[index];
                  return SizedBox(
                    width: 300,
                    child: VenueListItem(
                      club: venue,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Future<List<Club>> _getHotVenues() async {
    try {
      final clubService = context.read<ClubService>();

      // Get all clubs
      final clubs = await clubService.listClubs();

      // Get top 7 clubs by their existing order/data instead of counting parties
      // This is instant since clubs already have the data
      final topVenues = clubs.take(7).toList();

      return topVenues;
    } catch (e) {
      print('Error getting hot venues: $e');
      return [];
    }
  }

  Future<BannerConfig?> _loadBanner() async {
    try {
      final bannerService = BannerService();
      final banner = await bannerService.getActiveBanner();
      print('HomeScreen: Loaded banner: ${banner?.imageUrl ?? "null"}');
      return banner;
    } catch (e) {
      print('Error loading banner: $e');
      return null;
    }
  }

  String _getVenueFallbackImage(String venueName) {
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

  Widget _buildVenueFallbackContainer(String venueName) {
    return Image.asset(
      'assets/club_default.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8d58b5),
                Color(0xFF5D369F),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.nightlife,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  // Removed _buildVenueCard as it is replaced by the _VenueCard widget

  Future<int> _getVenuePartyCount(String clubId) async {
    try {
      final partyService = context.read<PartyService>();
      final parties = await partyService.listByClub(clubId);
      return parties.length;
    } catch (e) {
      print('Error getting party count for club $clubId: $e');
      return 0;
    }
  }

  // Consistent section header styling
  TextStyle get _sectionHeaderStyle => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF374151),
      );

  TextStyle get _sectionSubtextStyle => TextStyle(
        color: Colors.grey.shade600,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.colors.primary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            top: 90,
            right: -50,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.colors.secondary.withOpacity(0.10),
              ),
            ),
          ),
          // Sticky Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.92),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.colors.primary.withOpacity(0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Consumer2<AuthService, NotificationService>(
                  builder: (context, auth, notificationService, child) {
                    final currentUserId = auth.firebaseUser?.uid;
                    if (currentUserId != null) {
                      notificationService.initializeForUser(currentUserId);
                    }
                    final notifications = notificationService.notifications;
                    final unreadCount =
                        notifications.where((n) => !n.isRead).length;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset(
                          'assets/logos/wordmark_color.png',
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.colors.background,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.search,
                                  color: AppTheme.colors.textSecondary,
                                  size: 22,
                                ),
                                onPressed: () {
                                  context.push('/view-all-parties');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.colors.background,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.notifications_none,
                                      color: AppTheme.colors.textSecondary,
                                      size: 22,
                                    ),
                                    onPressed: () => context.push('/activity'),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 11,
                                    top: 11,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Main content below sticky bar
          Padding(
            padding: EdgeInsets.only(
              top: kToolbarHeight + MediaQuery.of(context).padding.top + 24,
            ),
            child: CustomRefreshIndicator(
              onRefresh: () async {
                print('Pull-to-refresh triggered');
                await Future.wait([
                  _loadUpcomingParties(),
                  _loadOngoingParties(),
                ]);
                print('✅ Data refresh completed');
                setState(() {});
              },
              builder: (context, child, controller) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(0, controller.value * 100),
                          child: child,
                        ),
                        if (controller.isLoading || controller.value > 0)
                          Positioned(
                            top: 20 + (controller.value * 50),
                            left: 0,
                            right: 0,
                            child: Center(
                              child: SpinKitWaveSpinner(
                                color: AppTheme.colors.primary,
                                size: 40.0,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Greeting and date selector
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 7),
                      child: Consumer<AuthService>(
                        builder: (context, auth, child) {
                          final userName =
                              auth.currentUser?.displayName ?? 'User';
                          final firstName = userName.split(' ').first;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.90),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.92),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.colors.primary.withOpacity(0.09),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Hey, $firstName',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                          height: 1.02,
                                          letterSpacing: -0.4,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildLocationIcon(),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildDateSelector(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFeedContent(),
                    const SizedBox(height: 16),
                    _buildBannerImage(),
                    const SizedBox(height: 16),
                    _buildHotVenuesSection(),
                    const SizedBox(height: 12),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
          // Bunny Points Popup
          if (_showBunnyPointsPopup)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 24,
              right: 24,
              child: _buildBunnyPointsPopup(),
            ),
        ],
      ),
    );
  }

  Widget _buildBunnyPointsPopup() {
    // Removed sign-in popup content per design — return empty widget.
    return const SizedBox.shrink();
  }

  Widget _buildFeedContent() {
    return Column(
      children: [
        // Ongoing stories section with circles directly in feed content
        FutureBuilder<List<Party>>(
          future: _ongoingPartiesFuture ?? Future.value(<Party>[]),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildOngoingTab(),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // You might be interested Feed Item
        Column(
          children: [
            _buildFeedItem(
              title: 'For You',
              subtitle: '',
              color: const Color(0xFF6C5CE7),
              child: _buildUpcomingTab(),
              onTap: () => context.push('/view-all-parties'),
            ),
            const SizedBox(height: 8), // Much reduced spacing between sections
          ],
        ),
        // Huge Crowd (copied from upcoming)
        Column(
          children: [
            _buildFeedItem(
              title: 'Trending Now',
              subtitle: '',
              color: const Color(0xFFFF7675),
              child: _buildHugeCrowdTab(),
              onTap: () => context.push('/view-all-parties'),
              showViewAll: false,
            ),
            const SizedBox(height: 8), // Much reduced spacing between sections
          ],
        ),
        // Introvert Gathering (copied from upcoming)
        _buildFeedItem(
          title: 'Recommended',
          subtitle: '',
          color: const Color(0xFF74B9FF),
          child: _buildIntrovertTab(),
          onTap: () => context.push('/view-all-parties'),
        ),
      ],
    );
  }

  Widget _buildFeedItem({
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
    required VoidCallback onTap,
    bool showViewAll = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.92),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty || subtitle.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty) ...[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                            height: 1.05,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (subtitle.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showViewAll)
                  TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.colors.background,
                      foregroundColor: AppTheme.colors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPlainSection({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.92),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildUpcomingTab() {
    return FutureBuilder<List<Party>>(
      future: _upcomingPartiesFuture,
      builder: (context, snapshot) {
        if (_isUpcomingLoading) {
          return SizedBox(
            height: 380,
            child: Center(
              child: SpinKitWaveSpinner(
                color: AppTheme.colors.primary,
                size: 40.0,
              ),
            ),
          );
        }
        print(
            '_buildUpcomingTab - ConnectionState: ${snapshot.connectionState}');
        print('_buildUpcomingTab - HasData: ${snapshot.hasData}');
        print('_buildUpcomingTab - HasError: ${snapshot.hasError}');
        if (snapshot.hasData) {
          print('_buildUpcomingTab - Data length: ${snapshot.data!.length}');
        }
        if (snapshot.hasError) {
          print('_buildUpcomingTab - Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 380,
            child: Center(
              child: SpinKitWaveSpinner(
                color: AppTheme.colors.primary,
                size: 40.0,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, color: Colors.grey, size: 32),
                SizedBox(height: 8),
                Text(
                  'No upcoming parties',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final upcomingParties = snapshot.data!;

        // Show all upcoming parties (don't filter out ones user is already attending)
        final filteredParties = _applyFilters(upcomingParties);

        if (filteredParties.isEmpty) {
          // Check if a specific date was selected
          if (_selectedDateForQuickAccess != null) {
            final dateStr =
                DateFormat('MMM d').format(_selectedDateForQuickAccess!);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, color: Colors.grey, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing happening on $dateStr,',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'try another day',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No parties'));
        }

        final parties = [...snapshot.data!];
        // Sort by capacity desc, then date asc
        parties.sort((a, b) {
          final byCapacity = b.capacity.compareTo(a.capacity);
          if (byCapacity != 0) return byCapacity;
          return a.dateTime.compareTo(b.dateTime);
        });

        return SizedBox(
          height: 380, // Match the Ongoing section card height
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 8),
            itemCount: parties.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final party = parties[index];
              return SizedBox(
                width: 300,
                child: OngoingPartyCard(
                  party: party,
                  userLatitude: _userLatitude,
                  userLongitude: _userLongitude,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Introvert Gathering copies upcoming but prioritizes small capacity parties
  Widget _buildIntrovertTab() {
    return FutureBuilder<List<Party>>(
      future: _upcomingPartiesFuture,
      builder: (context, snapshot) {
        print(
            '_buildIntrovertTab - ConnectionState: ${snapshot.connectionState}');
        print('_buildIntrovertTab - HasData: ${snapshot.hasData}');
        print('_buildIntrovertTab - HasError: ${snapshot.hasError}');
        if (snapshot.hasData) {
          print('_buildIntrovertTab - Data length: ${snapshot.data!.length}');
        }
        if (snapshot.hasError) {
          print('_buildIntrovertTab - Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          if (_selectedDateForQuickAccess != null) {
            final dateStr =
                DateFormat('MMM d').format(_selectedDateForQuickAccess!);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, color: Colors.grey, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing happening on $dateStr,',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'try another day',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No parties'));
        }

        final parties = [...snapshot.data!];
        // Sort by capacity asc, then date asc
        parties.sort((a, b) {
          final byCapacity = a.capacity.compareTo(b.capacity);
          if (byCapacity != 0) return byCapacity;
          return a.dateTime.compareTo(b.dateTime);
        });

        return SizedBox(
          height: 380, // Match the Ongoing section card height
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 8),
            itemCount: parties.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final party = parties[index];
              return SizedBox(
                width: 300,
                child: OngoingPartyCard(
                  party: party,
                  userLatitude: _userLatitude,
                  userLongitude: _userLongitude,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Removed: Your Parties section (no longer used)
  /* Widget _buildYourPartiesSection() {
    return FutureBuilder<List<Party>>(
      future: _getUserParties(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Error loading your parties',
                style: TextStyle(color: Colors.grey),
              ),
          );
        }

        final userParties = snapshot.data ?? [];
        
        if (userParties.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_note,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No parties yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join or create a party to see it here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort by most recent (newest dateTime first)
        userParties.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        final List<Party> displayedParties =
            userParties.length > 3 ? userParties.sublist(0, 3) : userParties;

        // Single card containing the entire section
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Your Parties',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${displayedParties.length} of ${userParties.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (userParties.length > 3)
                      TextButton(
                        onPressed: () => _showAllUserParties(userParties),
                        child: const Text('View all history'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // List inside the single card
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedParties.length,
                  separatorBuilder: (context, index) => Divider(height: 16, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final party = displayedParties[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        context.push('/party-details/${party.id}');
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              (party.imageUrl != null && party.imageUrl!.isNotEmpty) 
                                  ? party.imageUrl! 
                                  : _getPartyImage(party.title),
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Texts
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  party.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatPartyDate(party.dateTime),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Meta (attendees / budget)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${party.attendeeUserIds.length}/${party.capacity}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (party.budgetPerHead != null)
                                Text(
                                  '₱${party.budgetPerHead}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.colors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  } */

  /* Widget _buildUserPartyCard(Party party) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PartyDetailsScreen(party: party),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        width: 280,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Image.network(
                      (party.imageUrl != null && party.imageUrl!.isNotEmpty) 
                          ? party.imageUrl! 
                          : _getPartyImage(party.title),
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: party.dateTime.isAfter(DateTime.now()) 
                            ? Colors.green 
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        party.dateTime.isAfter(DateTime.now()) ? 'Upcoming' : 'Past',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                ),
              ),
                    ),
                  ),
                ],
              ),
            ),
            // Content section
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPartyDate(party.dateTime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${party.attendeeUserIds.length}/${party.capacity}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        if (party.budgetPerHead != null)
                          Text(
                            '₱${party.budgetPerHead}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.colors.primary,
                            ),
                          ),
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
  } */

  void _showJoinViaCodeDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join Party'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the invite code to join a party'),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Invite Code',
                  hintText: 'Enter party invite code',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = codeController.text.trim();
                if (code.isNotEmpty) {
                  Navigator.of(context).pop();
                  _handleJoinParty(code);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an invite code'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  void _handleJoinParty(String inviteCode) async {
    if (inviteCode.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an invite code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Joining party with code: $inviteCode'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      final auth = context.read<AuthService>();
      if (auth.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to join a party'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final partyService = context.read<PartyService>();
      final party = await partyService.joinViaInviteCode(
        inviteCode: inviteCode.trim().toUpperCase(),
        userId: auth.currentUser!.id,
      );

      if (party != null) {
        // Success - cache party and navigate to party details
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          print(
              'Home: Caching and navigating to party details for partyId: ${party.id}');

          // Cache the party data locally
          await LocalCacheService.cacheParty(party);

          context.push('/party-details?id=${party.id}');
        }
      } else {
        // Party not found
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No party found with invite code: $inviteCode'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining party: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showActionCards(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.only(
                    left: 24, right: 20, top: 8, bottom: 8),
                child: Text(
                  'What would you like to do?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Action cards
              _buildDropdownCard(
                icon: Icons.add,
                title: 'Host A Party',
                description: 'Create your own event and invite friends',
                color: AppTheme.colors.primary,
                onTap: () {
                  final authService = context.read<AuthService>();
                  final isLoggedOut =
                      authService.currentUser == null || authService.isGuest;
                  if (isLoggedOut) {
                    Navigator.of(context).pop();
                    _showCreatePartyAuthPrompt();
                    return;
                  }

                  Navigator.of(context).pop();
                  context.push('/create-party');
                },
              ),
              _buildDropdownCard(
                icon: Icons.group_add,
                title: 'Join via Invite Code',
                description: 'Enter a party code to join an event',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pop();
                  _showJoinViaCodeDialog(context);
                },
              ),
              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdownCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 24, right: 20, top: 4, bottom: 4),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOngoingTab() {
    return FutureBuilder<List<Party>>(
      future: _ongoingPartiesFuture ?? Future.value(<Party>[]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 380,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox(
            height: 380,
            child: Center(
              child: Text('Error loading ongoing parties'),
            ),
          );
        }

        final parties = snapshot.data ?? [];

        if (parties.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayParties = parties.take(10).toList();

        return SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: displayParties.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final party = displayParties[index];
              return SizedBox(
                width: 96,
                child: OngoingPartyCard(
                  party: party,
                  userLatitude: _userLatitude,
                  userLongitude: _userLongitude,
                  showNowBadge: true,
                  storyStyle: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// _VenueCard widget is defined above or in a separate file.

class _SimplePartyCard extends StatefulWidget {
  const _SimplePartyCard({
    required this.party,
    required this.onShowSignInPrompt,
  });
  final Party party;
  final Function(String) onShowSignInPrompt;

  @override
  State<_SimplePartyCard> createState() => _SimplePartyCardState();
}

class _SimplePartyCardState extends State<_SimplePartyCard> {
  bool _isFavorited = false;
  String? _clubName;

  @override
  void initState() {
    super.initState();
    _loadClubName();
    _checkIfSaved();
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
            _isFavorited = isSaved;
          });
        }
      }
    } catch (e) {
      print('Error checking if party is saved: $e');
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

  Widget _buildProfileStacks(List<String> attendeeIds) {
    if (attendeeIds.isEmpty) return const SizedBox.shrink();

    final displayCount = attendeeIds.length > 3 ? 3 : attendeeIds.length;
    final remainingCount = attendeeIds.length - displayCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile picture stacks
        ...List.generate(displayCount, (index) {
          return Transform.translate(
            offset: Offset(index > 0 ? -6.0 : 0, 0),
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 7,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-${1494790108755 + index}?w=32&h=32&fit=crop&crop=face',
                ),
                onBackgroundImageError: (exception, stackTrace) {
                  // Handle image error
                },
                child: const Icon(Icons.person, size: 10, color: Colors.grey),
              ),
            ),
          );
        }),
        // Remaining count
        if (remainingCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.grey.shade600,
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
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
    print('Building _SimplePartyCard for party: ${widget.party.title}');
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image card with date and bookmark
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Full image background
                  Positioned.fill(
                    child: Image.network(
                      widget.party.imageUrl != null &&
                              widget.party.imageUrl!.isNotEmpty
                          ? widget.party.imageUrl!
                          : _getPartyImage(widget.party.title),
                      fit: BoxFit.cover,
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
                            child: Icon(Icons.image_not_supported,
                                size: 20, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  // Date badge (top-left) - flat design
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.party.dateTime.day.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Joiner profile pictures overlay (bottom-right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildCompactJoinerProfilePictures(
                        widget.party.attendeeUserIds),
                  ),

                  // Bookmark icon (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        print('Save party button tapped');
                        final authService = context.read<AuthService>();
                        final savedService = context.read<SavedService>();
                        final currentUser = authService.currentUser;

                        print('Current user: ${currentUser?.id}');
                        print(
                            'Current user displayName: ${currentUser?.displayName}');
                        print('Party ID: ${widget.party.id}');
                        print('Party title: ${widget.party.title}');
                        print(
                            'AuthService isAuthenticated: ${authService.isAuthenticated}');
                        print(
                            'Firebase user: ${authService.firebaseUser?.uid}');

                        final firebaseUser = authService.firebaseUser;
                        if (firebaseUser == null) {
                          // Guest users: do not show sign-in popup. Ignore save action.
                          return;
                        }

                        try {
                          if (_isFavorited) {
                            print('Removing saved party');
                            await savedService.removeSavedParty(
                                firebaseUser.uid, widget.party.id);
                            setState(() {
                              _isFavorited = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Removed from saved'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            print('Saving party');
                            await savedService.saveParty(
                                firebaseUser.uid, widget.party.id);
                            setState(() {
                              _isFavorited = true;
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isFavorited
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          color: _isFavorited ? Colors.amber : Colors.black87,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Content section below image - COMPACT LAYOUT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Party title and budget pill in one row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.party.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // App color budget pill with no fill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppTheme.colors.primary, width: 1),
                      ),
                      child: Text(
                        widget.party.budgetPerHead != null
                            ? '₱${widget.party.budgetPerHead!.toStringAsFixed(0)} / person'
                            : 'Free',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Venue pill below the title
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Text(
                    _clubName ?? 'Loading...',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Join Now button - REMOVED
                // Builder(
                //   builder: (context) {
                //     final auth = context.read<AuthService?>();
                //     final isHost = auth?.currentUser?.id == widget.party.hostUserId;
                //
                //     if (isHost) {
                //       return const SizedBox.shrink();
                //     }
                //
                //     return FutureBuilder<Map<String, dynamic>?>(
                //       future: context.read<PartyService>().getApplicationForUser(
                //         partyId: widget.party.id,
                //         userId: auth?.currentUser?.id ?? '',
                //       ),
                //       builder: (context, snapshot) {
                //         final application = snapshot.data;
                //         final isApplied = application != null;
                //
                //         return Container(
                //           height: 24,
                //           width: double.infinity,
                //           decoration: BoxDecoration(
                //             gradient: LinearGradient(
                //               colors: isApplied
                //                   ? [Colors.grey.shade500, Colors.grey.shade600]
                //                   : [AppTheme.colors.primary, AppTheme.colors.secondary],
                //               begin: Alignment.topLeft,
                //               end: Alignment.bottomRight,
                //             ),
                //             borderRadius: BorderRadius.circular(12),
                //             boxShadow: [
                //               BoxShadow(
                //                 color: Colors.black.withOpacity(0.1),
                //                 blurRadius: 4,
                //                 offset: const Offset(0, 2),
                //               ),
                //             ],
                //           ),
                //           child: Material(
                //             color: Colors.transparent,
                //             child: InkWell(
                //               borderRadius: BorderRadius.circular(12),
                //               onTap: isApplied ? null : () {
                //                 print('Join button tapped for party: ${widget.party.title}');
                //                 if (auth?.currentUser == null) {
                //                   widget.onShowSignInPrompt('join this party');
                //                   return;
                //                 }
                //                 context.push('/party-details/${widget.party.id}');
                //               },
                //               child: Center(
                //                 child: Text(
                //                   isApplied ? 'Applied' : 'Join',
                //                   style: const TextStyle(
                //                     color: Colors.white,
                //                     fontSize: 10,
                //                     fontWeight: FontWeight.w600,
                //                     letterSpacing: 0.1,
                //                   ),
                //                 ),
                //               ),
                //             ),
                //           ),
                //         );
                //       },
                //     );
                //   },
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinerProfilePictures(List<String> attendeeIds) {
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
        if (remainingCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: CircleAvatar(
              radius: 16, // Much bigger radius
              backgroundColor: Colors.grey.shade400,
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12, // Much bigger font
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
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
}

class _EnhancedClubCard extends StatefulWidget {
  const _EnhancedClubCard({
    required this.club,
    required this.onShowSignInPrompt,
  });
  final Club club;
  final Function(String) onShowSignInPrompt;

  @override
  State<_EnhancedClubCard> createState() => _EnhancedClubCardState();
}

class _EnhancedClubCardState extends State<_EnhancedClubCard> {
  bool _isFavorited = false;

  void _showClubDetailOverlay(BuildContext context, Club club) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClubDetailScreen(clubId: club.id, isOverlay: true),
    );
  }

  void _toggleFavorite() async {
    final authService = context.read<AuthService>();
    final savedService = context.read<SavedService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      // Guest users: silently skip save action (no popup).
      return;
    }

    try {
      if (_isFavorited) {
        await savedService.removeFavoriteVenue(currentUser.id, widget.club.id);
        setState(() {
          _isFavorited = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await savedService.saveFavoriteVenue(currentUser.id, widget.club.id);
        setState(() {
          _isFavorited = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<int> _getPartyCount(BuildContext context, String clubId) async {
    try {
      final partyService = context.read<PartyService>();
      final parties = await partyService.listByClub(clubId);
      return parties.length;
    } catch (e) {
      print('Error getting party count: $e');
      return 0;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showClubDetailOverlay(context, widget.club);
      },
      child: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Club image with enhanced overlay
            Container(
              height: 100,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: Image.network(
                        widget.club.imageUrl.isNotEmpty
                            ? widget.club.imageUrl
                            : _getPartyImage(widget.club.name),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 28, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Enhanced overlay with Google Places data
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Favorite icon
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                          color: _isFavorited ? Colors.blue : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Rating and distance overlay
                  if (widget.club.rating > 0 || widget.club.distanceKm > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Row(
                        children: [
                          if (widget.club.rating > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star,
                                      size: 12, color: Colors.amber.shade300),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.club.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.club.distanceKm > 0)
                              const SizedBox(width: 4),
                          ],
                          if (widget.club.distanceKm > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on,
                                      size: 12, color: Colors.blue.shade300),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${widget.club.distanceKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Enhanced club details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Club name
                  Text(
                    widget.club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Location with icon
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
                          widget.club.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Categories/Type
                  if (widget.club.categories.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.colors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.club.categories.first,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Party count only
                  FutureBuilder<int>(
                    future: _getPartyCount(context, widget.club.id),
                    builder: (context, snapshot) {
                      final partyCount = snapshot.data ?? 0;
                      return Text(
                        '$partyCount Party${partyCount == 1 ? '' : 's'} Happening',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
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

class _ClubCard extends StatefulWidget {
  const _ClubCard({
    required this.club,
    required this.onShowSignInPrompt,
  });
  final Club club;
  final Function(String) onShowSignInPrompt;

  @override
  State<_ClubCard> createState() => _ClubCardState();
}

class _ClubCardState extends State<_ClubCard> {
  bool _isFavorited = false;

  void _showClubDetailOverlay(BuildContext context, Club club) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClubDetailScreen(clubId: club.id, isOverlay: true),
    );
  }

  void _showCreatePartyOverlay(BuildContext context, Club club) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePartyScreen(
        clubId: club.id,
        isOverlay: true,
      ),
    );
  }

  void _toggleFavorite() async {
    final authService = context.read<AuthService>();
    final savedService = context.read<SavedService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      // Guest users: silently skip save action (no popup).
      return;
    }

    try {
      if (_isFavorited) {
        await savedService.removeFavoriteVenue(currentUser.id, widget.club.id);
        setState(() {
          _isFavorited = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await savedService.saveFavoriteVenue(currentUser.id, widget.club.id);
        setState(() {
          _isFavorited = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<int> _getPartyCount(BuildContext context, String clubId) async {
    try {
      final partyService = context.read<PartyService>();
      final parties = await partyService.listByClub(clubId);
      return parties.length;
    } catch (e) {
      print('Error getting party count: $e');
      return 0;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showClubDetailOverlay(context, widget.club);
      },
      child: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club image
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        _getPartyImage(widget.club.name),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 28, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Favorite icon
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _toggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isFavorited ? Icons.bookmark : Icons.bookmark_border,
                          color: _isFavorited ? Colors.blue : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Rating and distance overlay
                  if (widget.club.rating > 0 || widget.club.distanceKm > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Row(
                        children: [
                          if (widget.club.rating > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star,
                                      size: 12, color: Colors.amber.shade300),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.club.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.club.distanceKm > 0)
                              const SizedBox(width: 4),
                          ],
                          if (widget.club.distanceKm > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on,
                                      size: 12, color: Colors.blue.shade300),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${widget.club.distanceKm.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Club details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.club.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.club.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: _getPartyCount(context, widget.club.id),
                    builder: (context, snapshot) {
                      final partyCount = snapshot.data ?? 0;
                      return Text(
                        '$partyCount Party${partyCount == 1 ? '' : 's'} Happening',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Host Party button (View functionality moved to card tap)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showCreatePartyOverlay(context, widget.club);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Host Party',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:bunny/services/party_service.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/club_service.dart';
import 'package:bunny/services/image_upload_service.dart';
import 'package:bunny/services/chat_service.dart';
import 'package:bunny/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bunny/models/club.dart';
import 'package:bunny/models/party.dart';
import 'package:bunny/models/user_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:math';

class CreatePartyScreen extends StatefulWidget {
  const CreatePartyScreen({
    super.key,
    this.clubId,
    this.isOverlay = false,
    this.isEdit = false,
    this.partyId,
  });
  final String? clubId;
  final bool isOverlay;
  final bool isEdit;
  final String? partyId;

  @override
  State<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends State<CreatePartyScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(days: 1));
  int _capacity = 10;
  String _preferredGender = 'Any';
  bool _saving = false;
  File? _selectedImage;
  String? _imageUrl;
  bool _showStatusOverlay = false;
  bool _isSuccess = false;
  double _overlayOpacity = 0.0;

  // Location and club suggestions
  String _currentCity = 'Loading...';
  double? _userLatitude;
  double? _userLongitude;
  List<Club> _nearbyClubs = [];
  bool _isLoadingClubs = false;
  String? _selectedClubId;

  // Venue search
  final TextEditingController _venueSearchController = TextEditingController();
  List<Club> _searchResults = [];
  bool _isSearching = false;

  // Smart recommendations
  List<Club> _personalizedRecommendations = [];
  List<Club> _trendingRecommendations = [];
  bool _isLoadingRecommendations = false;

  // Previous party data
  dynamic _previousParty;
  bool _isLoadingPreviousParty = false;

  // Edit party data
  Party? _editingParty;
  bool _isLoadingEditParty = false;

  final ImagePicker _picker = ImagePicker();

  // New fields for redesigned form
  String _selectedPaymentMethod = '';
  List<String> _selectedDrinkingTags = [];
  String _selectedReservationType = '';
  bool _agreedToTerms = false;

  // Entrance fee fields
  bool _hasEntranceFee = false;
  final TextEditingController _entranceFeeController = TextEditingController();
  bool _isEntranceFeeSeparate = false;

  // Payment method options
  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'cash', 'name': 'Cash', 'icon': Icons.money, 'color': Colors.green},
    {
      'id': 'card',
      'name': 'Card',
      'icon': Icons.credit_card,
      'color': Colors.blue
    },
    {
      'id': 'ewallet',
      'name': 'E-Wallet',
      'icon': Icons.phone_android,
      'color': Colors.purple
    },
  ];

  // Drinking tag options
  final List<String> _drinkingOptions = [
    'Hard Drinks',
    'Beer',
    'Cocktails',
    'Wine',
    'Non-Alcoholic',
    'Mixed Drinks'
  ];

  // Reservation type options
  final List<Map<String, dynamic>> _reservationTypes = [
    {
      'id': 'standing',
      'name': 'Standing',
      'icon': Icons.table_bar,
      'description': 'Standing area'
    },
    {
      'id': 'table',
      'name': 'With Table',
      'icon': Icons.table_restaurant,
      'description': 'Seated with table'
    },
    {
      'id': 'walkin',
      'name': 'Walk-in',
      'icon': Icons.directions_walk,
      'description': 'No reservation needed'
    },
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadPreviousParty();
    if (widget.clubId != null) {
      _selectedClubId = widget.clubId;
    }
    if (widget.isEdit && widget.partyId != null) {
      _loadEditParty();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _venueSearchController.dispose();
    _entranceFeeController.dispose();
    super.dispose();
  }

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
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.administrativeArea ?? 'Unknown';
        setState(() {
          _currentCity = city;
        });
      } else {
        setState(() {
          _currentCity = 'Unknown location';
        });
      }

      // Load nearby clubs and smart recommendations
      await _loadNearbyClubs();
      await _loadSmartRecommendations();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _currentCity = 'Location error';
      });
    }
  }

  Future<void> _loadNearbyClubs() async {
    if (_userLatitude == null || _userLongitude == null) return;

    setState(() {
      _isLoadingClubs = true;
    });

    try {
      final clubService = ClubService();
      // Use enhanced nearby clubs with Google Places integration
      print('CreateParty: Loading clubs for city: $_currentCity');
      print('CreateParty: User location: $_userLatitude, $_userLongitude');
      final clubs = await clubService.getEnhancedNearbyClubs(
        userLatitude: _userLatitude!,
        userLongitude: _userLongitude!,
        maxDistanceKm: 5.0, // 5km radius to limit to city area
        limit: 10,
        cityName: _currentCity, // Use detected city name
      );
      print('CreateParty: Found ${clubs.length} clubs');

      setState(() {
        _nearbyClubs = clubs;
        _isLoadingClubs = false;
      });
    } catch (e) {
      print('Error loading nearby clubs: $e');
      setState(() {
        _isLoadingClubs = false;
      });
    }
  }

  Future<void> _searchVenues(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      print('CreateParty: Searching for: "$query"');
      print('CreateParty: User location: $_userLatitude, $_userLongitude');

      final clubService = ClubService();
      final places = await clubService.searchVenuesWithAutocomplete(
        query: query,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
      );

      print('CreateParty: Raw search results: ${places.length} places');
      for (int i = 0; i < places.length; i++) {
        final place = places[i];
        print(
            'CreateParty: Place $i: ${place.name} (ID: ${place.placeId}, Lat: ${place.latitude}, Lng: ${place.longitude})');
      }

      final List<Club> searchResults = places
          .map((place) => clubService.placeToClub(
                place,
                userLatitude: _userLatitude,
                userLongitude: _userLongitude,
              ))
          .toList();

      print('CreateParty: Converted to clubs: ${searchResults.length}');
      for (int i = 0; i < searchResults.length; i++) {
        final club = searchResults[i];
        print(
            'CreateParty: Club $i: ${club.name} (ID: ${club.id}, Location: ${club.location}, Distance: ${club.distanceKm}km)');
      }

      // Deduplicate search results by ID to prevent multiple selections
      final uniqueResults = <String, Club>{};
      for (final club in searchResults) {
        uniqueResults[club.id] = club;
      }

      print(
          'CreateParty: Search results: ${searchResults.length} total, ${uniqueResults.length} unique');
      print('CreateParty: Selected club ID: $_selectedClubId');
      print('CreateParty: Unique club IDs: ${uniqueResults.keys.toList()}');

      setState(() {
        _searchResults = uniqueResults.values.toList();
        _isSearching = false;
      });
    } catch (e) {
      print('Error searching venues: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _loadPreviousParty() async {
    setState(() {
      _isLoadingPreviousParty = true;
    });

    try {
      final auth = context.read<AuthService>();
      if (auth.currentUser == null) {
        setState(() {
          _isLoadingPreviousParty = false;
        });
        return;
      }

      final partyService = context.read<PartyService>();
      final allUserParties =
          await partyService.listByUser(auth.currentUser!.id);

      // Filter to only hosted parties and sort by creation date (most recent first)
      final hostedParties = allUserParties
          .where((party) => party.hostUserId == auth.currentUser!.id)
          .toList();

      hostedParties.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      if (hostedParties.isNotEmpty) {
        setState(() {
          _previousParty = hostedParties.first;
          _isLoadingPreviousParty = false;
        });
      } else {
        setState(() {
          _isLoadingPreviousParty = false;
        });
      }
    } catch (e) {
      print('Error loading previous party: $e');
      setState(() {
        _isLoadingPreviousParty = false;
      });
    }
  }

  Future<void> _loadEditParty() async {
    if (widget.partyId == null) {
      print('Error: partyId is null in edit mode');
      return;
    }

    setState(() {
      _isLoadingEditParty = true;
    });

    try {
      final partyService = context.read<PartyService>();
      final party = await partyService.getById(widget.partyId!);

      if (party != null) {
        setState(() {
          _editingParty = party;
        });
        _fillWithEditParty();
      } else {
        print('Error: Party not found with ID: ${widget.partyId}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Party not found')),
        );
      }
    } catch (e) {
      print('Error loading edit party: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading party: $e')),
      );
    } finally {
      setState(() {
        _isLoadingEditParty = false;
      });
    }
  }

  void _fillWithEditParty() {
    if (_editingParty == null) return;

    final party = _editingParty!;

    // Map payment method names to IDs
    String paymentMethodId = '';
    if (party.paymentMethod.isNotEmpty) {
      final paymentMethod = _paymentMethods.firstWhere(
        (method) =>
            method['name'].toLowerCase() == party.paymentMethod.toLowerCase(),
        orElse: () => {'id': '', 'name': ''},
      );
      paymentMethodId = paymentMethod['id'] ?? '';
    }

    // Map reservation type names to IDs
    String reservationTypeId = '';
    if (party.reservationType.isNotEmpty) {
      final reservationType = _reservationTypes.firstWhere(
        (type) =>
            type['name'].toLowerCase() == party.reservationType.toLowerCase(),
        orElse: () => {'id': '', 'name': ''},
      );
      reservationTypeId = reservationType['id'] ?? '';
    }

    setState(() {
      _titleController.text = party.title;
      _descriptionController.text = party.description;
      _budgetController.text = party.budgetPerHead?.toString() ?? '';
      _capacity = party.capacity;
      _dateTime = party.dateTime;
      _selectedPaymentMethod = paymentMethodId;
      _selectedDrinkingTags = List<String>.from(party.drinkingTags);
      _selectedReservationType = reservationTypeId;
      _preferredGender = party.preferredGender;
      _selectedClubId = party.clubId;
      _imageUrl = party.imageUrl;
    });
  }

  void _fillWithPreviousParty() {
    if (_previousParty == null) return;

    // Debug: Print previous party data
    print('Previous party data:');
    print('Payment Method: ${_previousParty.paymentMethod}');
    print('Reservation Type: ${_previousParty.reservationType}');
    print('Drinking Tags: ${_previousParty.drinkingTags}');

    // Map payment method names to IDs
    String paymentMethodId = '';
    if (_previousParty.paymentMethod != null) {
      final paymentMethod = _paymentMethods.firstWhere(
        (method) =>
            method['name'].toLowerCase() ==
            _previousParty.paymentMethod.toLowerCase(),
        orElse: () => {'id': '', 'name': ''},
      );
      paymentMethodId = paymentMethod['id'] ?? '';
      print('Mapped payment method ID: $paymentMethodId');
    }

    // Map reservation type names to IDs
    String reservationTypeId = '';
    if (_previousParty.reservationType != null) {
      final reservationType = _reservationTypes.firstWhere(
        (type) =>
            type['name'].toLowerCase() ==
            _previousParty.reservationType.toLowerCase(),
        orElse: () => {'id': '', 'name': ''},
      );
      reservationTypeId = reservationType['id'] ?? '';
      print('Mapped reservation type ID: $reservationTypeId');
    }

    setState(() {
      _titleController.text = _previousParty.title ?? '';
      _descriptionController.text = _previousParty.description ?? '';
      _budgetController.text = _previousParty.budgetPerHead?.toString() ?? '';
      _capacity = _previousParty.capacity ?? 10;
      _selectedPaymentMethod = paymentMethodId;
      _selectedDrinkingTags =
          List<String>.from(_previousParty.drinkingTags ?? []);
      _selectedReservationType = reservationTypeId;
      _preferredGender = _previousParty.preferredGender ?? 'Any';
      _selectedClubId = _previousParty.clubId;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Previous party details loaded!'),
        backgroundColor: AppTheme.colors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadSmartRecommendations() async {
    if (_userLatitude == null || _userLongitude == null) return;

    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final clubService = ClubService();

      // Create sample user preferences and behavior for demo
      // In a real app, these would be loaded from user data
      final userPreferences = UserPreferences(
        userId: 'demo_user',
        favoriteVenueTypes: ['Nightclub', 'Bar', 'Lounge'],
        preferredDistanceKm: 10.0,
        preferredMusicGenres: ['Electronic', 'Hip-Hop', 'Pop'],
      );

      final userBehavior = UserBehavior(
        userId: 'demo_user',
        totalPartiesCreated: 5,
        totalPartiesJoined: 12,
        totalVenuesVisited: 8,
        averagePartyRating: 4.2,
        mostActiveDays: ['Friday', 'Saturday', 'Sunday'],
        mostActiveTimes: ['Evening', 'Night'],
      );

      // Load personalized recommendations
      final personalized = await clubService.getPersonalizedRecommendations(
        userId: 'demo_user',
        userPreferences: userPreferences,
        userBehavior: userBehavior,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
        limit: 5,
      );

      // Load trending recommendations
      final trending = await clubService.getTrendingRecommendations(
        userId: 'demo_user',
        userPreferences: userPreferences,
        userBehavior: userBehavior,
        userLatitude: _userLatitude,
        userLongitude: _userLongitude,
        limit: 3,
      );

      setState(() {
        _personalizedRecommendations = personalized;
        _trendingRecommendations = trending;
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      print('Error loading smart recommendations: $e');
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    try {
      final imageUploadService = context.read<ImageUploadService>();
      final auth = context.read<AuthService>();

      if (auth.currentUser == null) return;

      // Convert File to XFile for the upload service
      final xFile = XFile(_selectedImage!.path);

      _imageUrl = await imageUploadService.uploadPartyImage(
        'temp_${DateTime.now().millisecondsSinceEpoch}',
        xFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthService>();
    if (auth.currentUser == null) return;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a party title')),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please agree to the terms and conditions')),
      );
      return;
    }

    setState(() {
      _saving = true;
      _showStatusOverlay = true;
      _isSuccess = false;
      _overlayOpacity = 1.0;
    });

    try {
      // Upload image first if one is selected
      if (_selectedImage != null && _imageUrl == null) {
        await _uploadImage();
      }

      if (widget.isEdit && _editingParty != null) {
        // Update existing party
        await context.read<PartyService>().updateParty(
          _editingParty!.id,
          {
            'title': _titleController.text.trim(),
            'dateTime': _dateTime,
            'capacity': _capacity,
            'description': _descriptionController.text.trim(),
            'preferredGender': _preferredGender,
            'imageUrl': _imageUrl,
            'budgetPerHead': int.tryParse(_budgetController.text.trim()),
            'paymentMethod': _selectedPaymentMethod,
            'drinkingTags': _selectedDrinkingTags,
            'reservationType': _selectedReservationType,
          },
        );

        // Send notification to group chat
        await _sendPartyUpdateNotification();

        if (mounted) {
          setState(() {
            _isSuccess = true;
          });
          await Future.delayed(const Duration(milliseconds: 900));
          if (!mounted) return;
          setState(() {
            _overlayOpacity = 0.0;
          });
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          context.pop();
        }
      } else {
        // Save venue to database if it's not already there
        String finalClubId = _selectedClubId ?? widget.clubId ?? 'default-club';

        if (_selectedClubId != null) {
          // Check if the selected club exists in the database
          final clubService = ClubService();
          final existingClub = await clubService.getClub(_selectedClubId!);

          if (existingClub == null) {
            // Find the selected club from search results and save it
            final selectedClub = _searchResults.firstWhere(
              (club) => club.id == _selectedClubId,
              orElse: () => _nearbyClubs.firstWhere(
                (club) => club.id == _selectedClubId,
                orElse: () => _personalizedRecommendations.firstWhere(
                  (club) => club.id == _selectedClubId,
                  orElse: () => _trendingRecommendations.firstWhere(
                    (club) => club.id == _selectedClubId,
                    orElse: () => Club(
                      id: _selectedClubId!,
                      name: 'Unknown Venue',
                      location: 'Unknown Location',
                      description: '',
                      imageUrl: '',
                      categories: [],
                      rating: 0.0,
                      distanceKm: 0.0,
                    ),
                  ),
                ),
              ),
            );

            // Save the club to the database
            final newClubId = await clubService.createClub(selectedClub);
            print(
                'CreateParty: Saved new venue to database: ${selectedClub.name} (New ID: $newClubId)');
            // Update the final club ID to use the new database ID
            finalClubId = newClubId;
          }
        }

        // Create new party
        final party = await context.read<PartyService>().create(
              clubId: finalClubId,
              hostUserId: auth.firebaseUser?.uid ?? auth.currentUser?.id ?? '',
              hostName: auth.currentUser?.displayName ??
                  auth.firebaseUser?.uid ??
                  'Guest',
              title: _titleController.text.trim(),
              dateTime: _dateTime,
              capacity: _capacity,
              description: _descriptionController.text.trim(),
              preferredGender: _preferredGender,
              imageUrl: _imageUrl,
              budgetPerHead: int.tryParse(_budgetController.text.trim()),
              paymentMethod: _selectedPaymentMethod,
              drinkingTags: _selectedDrinkingTags,
              reservationType: _selectedReservationType,
              hasEntranceFee: _hasEntranceFee,
              entranceFeeAmount: _hasEntranceFee
                  ? int.tryParse(_entranceFeeController.text.trim()) ?? 0
                  : 0,
            );

        if (mounted) {
          setState(() {
            _isSuccess = true;
          });
          await Future.delayed(const Duration(milliseconds: 900));
          if (!mounted) return;
          setState(() {
            _overlayOpacity = 0.0;
          });
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          // Navigate to invite screen instead of just popping
          // Wait a bit more to ensure overlay is fully dismissed
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;

          print('Navigating to invite screen with party ID: ${party.id}');
          // Verify party ID is valid
          if (party.id.isEmpty) {
            print('Error: Party ID is empty, cannot navigate to invite screen');
            if (mounted) {
              // Navigate to home instead of popping
              if (Navigator.of(context).canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }
            return;
          }

          // Use GoRouter to navigate - close the overlay and navigate to invite
          if (mounted) {
            final routePath = '/party-invite/${party.id}';
            print('Attempting to navigate to: $routePath');
            try {
              // Close the CreatePartyScreen overlay first
              Navigator.of(context).pop();
              // Then navigate to invite screen using push
              await Future.delayed(const Duration(milliseconds: 100));
              context.push(routePath);
              print('Navigation successful');
            } catch (e, stackTrace) {
              print('Navigation error: $e');
              print('Stack trace: $stackTrace');
              // If push fails, show error and just pop to go back
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Party created! Error navigating to invite: $e'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
                // Only pop if we can
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  // If can't pop, navigate to home
                  context.go('/');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating party: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _sendPartyUpdateNotification() async {
    if (_editingParty == null) {
      print('Error: _editingParty is null, cannot send notification');
      return;
    }

    try {
      final chatService = context.read<ChatService>();
      final auth = context.read<AuthService>();

      if (auth.currentUser == null) {
        print('Error: No current user, cannot send notification');
        return;
      }

      // Get the chat group for this party
      final chatGroup =
          await chatService.getChatGroupForParty(_editingParty!.id);

      if (chatGroup != null) {
        // Send a system message about the party update
        final message =
            "🎉 Party details have been updated by ${auth.currentUser!.displayName}! Check the latest information.";

        await chatService.sendSystemMessage(
          groupId: chatGroup.id,
          text: message,
        );

        print('Party update notification sent to group chat');
      } else {
        print('No chat group found for party: ${_editingParty!.id}');
      }
    } catch (e) {
      print('Error sending party update notification: $e');
      // Don't show error to user as this is a background operation
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Scaffold(
      backgroundColor: AppTheme.colors.primary.withOpacity(0.15), // Theme color background
      body: Column(
        children: [
          // Custom Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.isOverlay) {
                        Navigator.of(context).pop();
                      } else {
                        // Check if we can pop, otherwise go home
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          // Force navigation to home without reload (using go instead of pushReplacement)
                          context.go('/');
                        }
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
                            color: AppTheme.colors.primary.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: AppTheme.colors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.colors.primary.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'Start a Party',
                      style: TextStyle(
                        color: AppTheme.colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40), // Balance the back button
                ],
              ),
            ),
          ),
          
          // Top Image Section
          Expanded(
            flex: 2,
            child: Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: _selectedImage != null
                    ? Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.colors.primary.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImage = null;
                                    _imageUrl = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.black87,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.colors.primary.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 48,
                              color: AppTheme.colors.primary.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Upload your files here ',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Browse',
                                style: TextStyle(
                                  color: AppTheme.colors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Bottom Form Section
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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

                    // Unified Form Fields
                    _buildUnifiedCard(),

                    const SizedBox(height: 32),

                    // Create Button (Pill style)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.colors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: _ModernSpinner(),
                              )
                            : const Text(
                                'Create Party',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isOverlay) {
      return WillPopScope(
        onWillPop: () async => !_showStatusOverlay,
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: content,
                ),
                if (_showStatusOverlay)
                  AnimatedOpacity(
                    opacity: _overlayOpacity,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        scale: _overlayOpacity,
                        child: Container(
                          width: 300,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_isSuccess) ...[
                                // Animated loading spinner with pulsing effect (monochrome)
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 1500),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: 0.8 +
                                          (0.2 * (1 + (value * 2 - 1).abs())),
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey.shade300,
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.grey.shade700,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Creating your party...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Setting up the perfect vibe',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ] else ...[
                                // Success animation with monochrome design
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 800),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: 0.5 + (0.5 * value),
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey.shade200,
                                          border: Border.all(
                                            color: Colors.grey.shade400,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.grey.shade700,
                                          size: 50,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Party Created! 🎉',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your party is now live and ready for guests',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    } else {
      return WillPopScope(
        onWillPop: () async => !_showStatusOverlay,
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.grey.shade50,
              body: content,
            ),
            if (_showStatusOverlay)
              AnimatedOpacity(
                opacity: _overlayOpacity,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.black.withOpacity(0.4),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    scale: _overlayOpacity,
                    child: Container(
                      width: 300,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isSuccess) ...[
                            // Animated loading spinner with pulsing effect
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1500),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale:
                                      0.8 + (0.2 * (1 + (value * 2 - 1).abs())),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.colors.primary
                                              .withOpacity(0.3),
                                          AppTheme.colors.primary,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Creating your party...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Setting up the perfect vibe',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ] else ...[
                            // Success animation with celebration effect
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 800),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.5 + (0.5 * value),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.green.withOpacity(0.3),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.celebration_rounded,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Party Created! 🎉',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your party is now live and ready for guests',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No venues found. Try a different search term.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final club = _searchResults[index];
          final isSelected = _selectedClubId == club.id;

          return _buildClubCard(club, isSelected);
        },
      ),
    );
  }

  Widget _buildNearbyClubs() {
    if (_isLoadingClubs) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            height: 40,
            width: 40,
            child: _ModernSpinner(),
          ),
        ),
      );
    }

    if (_nearbyClubs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No nearby venues found. You can still create a party without selecting a venue.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _nearbyClubs.length,
        itemBuilder: (context, index) {
          final club = _nearbyClubs[index];
          final isSelected = _selectedClubId == club.id;

          return _buildClubCard(club, isSelected);
        },
      ),
    );
  }

  Widget _buildClubCard(Club club, bool isSelected,
      {bool isRecommended = false, bool isTrending = false}) {
    return GestureDetector(
      onTap: () {
        print('Tapping club: ${club.name} (ID: ${club.id})');
        print('Currently selected: $_selectedClubId');
        print('Is currently selected: $isSelected');
        setState(() {
          _selectedClubId = isSelected ? null : club.id;
        });
        print('New selection: $_selectedClubId');
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.colors.primary.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.colors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.nightlife,
                        color: isSelected
                            ? AppTheme.colors.primary
                            : Colors.grey.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          club.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isSelected
                                ? AppTheme.colors.primary
                                : Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    club.location,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        club.rating.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${club.distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Recommendation badges
            if (isRecommended)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isTrending)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔥',
                    style: TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRecommendations() {
    if (_isLoadingRecommendations) {
      return const Padding(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            height: 40,
            width: 40,
            child: _ModernSpinner(),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personalized recommendations
        if (_personalizedRecommendations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.star, color: AppTheme.colors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Recommended for you',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _personalizedRecommendations.length,
              itemBuilder: (context, index) {
                final club = _personalizedRecommendations[index];
                final isSelected = _selectedClubId == club.id;
                return _buildClubCard(club, isSelected, isRecommended: true);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Trending recommendations
        if (_trendingRecommendations.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Trending now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trendingRecommendations.length,
              itemBuilder: (context, index) {
                final club = _trendingRecommendations[index];
                final isSelected = _selectedClubId == club.id;
                return _buildClubCard(club, isSelected, isTrending: true);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Nearby venues fallback
        _buildNearbyClubs(),
      ],
    );
  }

  Widget _buildUnifiedCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Name of Event
        _buildMinimalField(
          controller: _titleController,
          label: 'Party Name',
          hint: 'Bunny\'s Friday Night', // Example from reference
        ),

        const SizedBox(height: 24),

        // 2. Address (Venue)
        _buildVenueSectionMinimal(),

        const SizedBox(height: 24),

        // 3. Notes for visitor (Description)
        _buildMinimalField(
          controller: _descriptionController,
          label: 'Notes for joiners',
          hint: 'Wear comfortable and bring your ID', // Example from reference
          maxLines: 2,
        ),

        const SizedBox(height: 24),

        // 4. Date & Time Card
        _buildDateTimeCard(),

        const SizedBox(height: 24),

        // 5. Capacity (Total Person)
        _buildCapacitySection(),

        const SizedBox(height: 24),

        // 6. Price / Budget
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set Price',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE8936D), // Peach color
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₱', // Changed to Peso sign
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: '00',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade300,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                      Text(
                        '/person',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 7. Drinking Preferences
        _buildDrinkingTagsSection(),

        const SizedBox(height: 24),

        // Entrance Fee Toggle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entrance Fee',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE8936D),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEntranceFeeSeparate = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isEntranceFeeSeparate
                            ? const Color(0xFFE8936D)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Included',
                        style: TextStyle(
                          color: !_isEntranceFeeSeparate
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEntranceFeeSeparate = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isEntranceFeeSeparate
                            ? const Color(0xFFE8936D)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Separate',
                        style: TextStyle(
                          color: _isEntranceFeeSeparate
                              ? Colors.white
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isEntranceFeeSeparate) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _entranceFeeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter entrance fee amount',
                  prefixIcon: const Icon(Icons.payments_outlined,
                      color: Color(0xFFE8936D), size: 20),
                  suffixText: 'PHP',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8936D), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),
        _buildChatNoteAndAgreement(),
      ],
    );
  }

  Widget _buildMinimalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE8936D), // Peach color for labels
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
            border: InputBorder.none, // Remove border
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }

  Widget _buildVenueSectionMinimal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Venue',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8936D),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            _showVenuePicker(context);
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _venueSearchController.text.isNotEmpty
                      ? _venueSearchController.text
                      : 'Select a venue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE8936D)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }

  void _showVenuePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _venueSearchController,
                    onChanged: (value) {
                      _searchVenues(value);
                      // Force rebuild to show search results
                      (context as Element).markNeedsBuild();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search for a venue...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _searchResults.isNotEmpty
                      ? ListView.builder(
                          controller: scrollController,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final club = _searchResults[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: club.imageUrl.isNotEmpty
                                    ? Image.network(
                                        club.imageUrl,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.broken_image,
                                              size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.business,
                                            size: 20),
                                      ),
                              ),
                              title: Text(club.name),
                              subtitle: Text(club.location),
                              onTap: () {
                                setState(() {
                                  _selectedClubId = club.id;
                                  _venueSearchController.text = club.name;
                                });
                                Navigator.pop(context);
                              },
                            );
                          },
                        )
                      : FutureBuilder<List<Club>>(
                          future: ClubService().listClubs(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                  child: Text('No venues found'));
                            }
                            final clubs = snapshot.data!;
                            return ListView.builder(
                              controller: scrollController,
                              itemCount: clubs.length,
                              itemBuilder: (context, index) {
                                final club = clubs[index];
                                return ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: club.imageUrl.isNotEmpty
                                        ? Image.network(
                                            club.imageUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  size: 20),
                                            ),
                                          )
                                        : Container(
                                            width: 40,
                                            height: 40,
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.business,
                                                size: 20),
                                          ),
                                  ),
                                  title: Text(club.name),
                                  subtitle: Text(club.location),
                                  onTap: () {
                                    setState(() {
                                      _selectedClubId = club.id;
                                      _venueSearchController.text = club.name;
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateTimeCard() {
    // Helper to format month name
    String getMonthName(int month) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return months[month - 1];
    }

    // Helper to format day name
    String getDayName(int weekday) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
            colors: [Color(0xFF321857), Color(0xFF5D369F)], // Deep purple gradient
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
                children: [
                  Text(
                    getMonthName(_dateTime.month),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${_dateTime.day}',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getDayName(_dateTime.weekday),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${TimeOfDay.fromDateTime(_dateTime).format(context)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Edit Icon
            GestureDetector(
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _dateTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_dateTime),
                  );
                  if (pickedTime != null) {
                    setState(() => _dateTime = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    ));
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, color: AppTheme.colors.primary, size: 18)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.colors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date & Time',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _dateTime = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        _dateTime.hour,
                        _dateTime.minute));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: AppTheme.colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_dateTime.toLocal().toString().split(' ')[0]}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_dateTime),
                  );
                  if (picked != null) {
                    setState(() => _dateTime = DateTime(
                          _dateTime.year,
                          _dateTime.month,
                          _dateTime.day,
                          picked.hour,
                          picked.minute,
                        ));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          color: AppTheme.colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_dateTime.toLocal().toString().split(' ')[1].substring(0, 5)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapacitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Person',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFE8936D),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          onChanged: (value) {
            final newCapacity = int.tryParse(value);
            if (newCapacity != null && newCapacity >= 1 && newCapacity <= 100) {
              setState(() => _capacity = newCapacity);
            }
          },
          decoration: InputDecoration(
            hintText: 'Enter capacity',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
            suffixText: 'people',
            suffixStyle: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
        const SizedBox(height: 12),
        // Capacity suggestion pills
        Wrap(
          spacing: 8,
          children: [5, 10, 15].map((capacity) {
            final isSelected = _capacity == capacity;
            return GestureDetector(
              onTap: () {
                setState(() => _capacity = capacity);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.colors.primary
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.colors.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '$capacity people',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Party Image',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedImage != null)
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(_selectedImage!),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                        _imageUrl = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add image',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVenueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Venue',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _venueSearchController,
          onChanged: _searchVenues,
          decoration: InputDecoration(
            hintText: 'Search for a venue...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _venueSearchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _venueSearchController.clear();
                      _searchVenues('');
                    },
                    icon: const Icon(Icons.clear, size: 20),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.colors.primary),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 12),
        if (_venueSearchController.text.isNotEmpty)
          _buildSearchResults()
        else
          _buildSmartRecommendations(),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.colors.primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppTheme.colors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Create Party',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildBudgetField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Budget per head',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'e.g. 500',
            prefixIcon:
                Icon(Icons.payments, color: AppTheme.colors.primary, size: 20),
            suffixIcon: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                '₱',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.colors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 12),
        // Budget suggestion pills
        Wrap(
          spacing: 8,
          children: [300, 500, 700, 1000].map((budget) {
            final isSelected = _budgetController.text == budget.toString();
            return GestureDetector(
              onTap: () {
                setState(() {
                  _budgetController.text = budget.toString();
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.colors.primary
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.colors.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '₱$budget',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Entrance Fee Section
        _buildEntranceFeeSection(),
      ],
    );
  }

  Widget _buildEntranceFeeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Entrance Fee',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Free/Custom Toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _hasEntranceFee = false;
                    _entranceFeeController.clear();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: !_hasEntranceFee
                        ? AppTheme.colors.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_hasEntranceFee
                          ? AppTheme.colors.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.free_breakfast,
                        color: !_hasEntranceFee
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Free',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !_hasEntranceFee
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _hasEntranceFee = true;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _hasEntranceFee
                        ? AppTheme.colors.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasEntranceFee
                          ? AppTheme.colors.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.attach_money,
                        color: _hasEntranceFee
                            ? Colors.white
                            : Colors.grey.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Custom',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _hasEntranceFee
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Custom Amount Field (only show when Custom is selected)
        if (_hasEntranceFee) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _entranceFeeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter entrance fee amount',
              prefixIcon:
                  Icon(Icons.money, color: AppTheme.colors.primary, size: 20),
              suffixIcon: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: const Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppTheme.colors.primary, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 8),
          // Entrance fee suggestion pills
          Wrap(
            spacing: 8,
            children: [50, 100, 150, 200].map((fee) {
              final isSelected = _entranceFeeController.text == fee.toString();
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _entranceFeeController.text = fee.toString();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.colors.primary
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.colors.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '₱$fee',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _paymentMethods.map((method) {
            final isSelected = _selectedPaymentMethod == method['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = method['id'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? method['color'].withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? method['color'] : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        method['icon'],
                        color: isSelected
                            ? method['color']
                            : Colors.grey.shade600,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method['name'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? method['color']
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDrinkingTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Drinking Preferences',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '(can select more than 1)',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _drinkingOptions.map((tag) {
            final isSelected = _selectedDrinkingTags.contains(tag);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDrinkingTags.remove(tag);
                  } else {
                    _selectedDrinkingTags.add(tag);
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.colors.primary
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.colors.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Custom drinking preference input
        TextField(
          onChanged: (value) {
            if (value.trim().isNotEmpty &&
                !_selectedDrinkingTags.contains(value.trim())) {
              setState(() {
                _selectedDrinkingTags.add(value.trim());
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'Add custom drinking preference...',
            prefixIcon:
                Icon(Icons.add, color: AppTheme.colors.primary, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.colors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildReservationTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reservation Type',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _reservationTypes.map((type) {
            final isSelected = _selectedReservationType == type['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedReservationType = type['id'];
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  height: 100, // Fixed height for all cards
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.colors.primary.withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.colors.primary
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type['icon'],
                        color: isSelected
                            ? AppTheme.colors.primary
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type['name'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.colors.primary
                              : Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          type['description'],
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviousPartyLoadingSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading your previous party...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEditPartyLoadingSection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading party details...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPreviousPartySection() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.colors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.colors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history,
                    color: AppTheme.colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your Last Party',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _previousParty?.title ?? 'Previous Party',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use the same details from your last party',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fillWithPreviousParty,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Use Last Party Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildChatNoteAndAgreement() {
    return Row(
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) {
            setState(() {
              _agreedToTerms = value ?? false;
            });
          },
          activeColor: AppTheme.colors.primary,
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () async {
                      const url = 'https://www.thebunnyapp.com';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'terms and conditions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
class _ModernSpinner extends StatefulWidget {
  const _ModernSpinner();

  @override
  State<_ModernSpinner> createState() => _ModernSpinnerState();
}

class _ModernSpinnerState extends State<_ModernSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
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
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: CustomPaint(
            painter: _SpinnerPainter(_controller.value),
            size: const Size(24, 24),
          ),
        );
      },
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double progress;

  _SpinnerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Draw the spinning arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 2 * 3.14159,
      1.5,
      false,
      paint,
    );

    // Draw rotating dots
    final dotRadius = 1.5;
    for (int i = 0; i < 3; i++) {
      final angle = (progress * 2 * 3.14159) + (i * 2.09); // 120 degrees apart
      final dotX = center.dx + radius * 0.7 * cos(angle);
      final dotY = center.dy + radius * 0.7 * sin(angle);
      
      final dotPaint = Paint()
        ..color = Colors.white.withOpacity(1 - (i * 0.3))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(dotX, dotY),
        dotRadius,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
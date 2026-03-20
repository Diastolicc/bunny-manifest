import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bunny/models/club.dart';
import 'package:bunny/models/place.dart';
import 'package:bunny/models/user_preferences.dart';
import 'package:bunny/config/firebase_config.dart';
import 'package:bunny/services/places_service.dart';
import 'package:bunny/services/recommendation_service.dart';
import 'package:bunny/services/behavior_tracking_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final PlacesService _placesService = PlacesService();
  final RecommendationService _recommendationService = RecommendationService();
  final BehaviorTrackingService _behaviorTrackingService =
      BehaviorTrackingService();

  // Get clubs collection reference
  CollectionReference<Map<String, dynamic>> get _clubsCollection =>
      _firestore.collection('clubs');

  // Mock data as fallback
  final List<Club> _mockClubs = <Club>[
    const Club(
      id: '1',
      name: 'Neon Pulse',
      location: 'Downtown',
      description: 'EDM and dance hits with state-of-the-art sound system',
      imageUrl:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1200',
      categories: <String>['Hottest', 'Dance', 'EDM'],
      rating: 4.7,
      distanceKm: 1.2,
    ),
    const Club(
      id: '2',
      name: 'Velvet Room',
      location: 'Midtown',
      description: 'Sophisticated cocktails and live DJ performances',
      imageUrl:
          'https://images.unsplash.com/photo-1520975916090-3105956d8ac38?q=80&w=1200',
      categories: <String>['Nearest', 'Lounge', 'Cocktails'],
      rating: 4.5,
      distanceKm: 0.6,
    ),
    const Club(
      id: '3',
      name: 'Skyline Lounge',
      location: 'Uptown',
      description: 'Rooftop vibes with panoramic city views',
      imageUrl:
          'https://images.unsplash.com/photo-1517095037594-166575f1e866?q=80&w=1200',
      categories: <String>['Hottest', 'Rooftop', 'Luxury'],
      rating: 4.8,
      distanceKm: 3.4,
    ),
    const Club(
      id: '4',
      name: 'Bass Drop',
      location: 'Westside',
      description: 'Underground electronic music and techno',
      imageUrl:
          'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800&h=400&fit=crop',
      categories: <String>['Electronic', 'Techno', 'Underground'],
      rating: 4.6,
      distanceKm: 2.1,
    ),
    const Club(
      id: '5',
      name: 'Jazz Corner',
      location: 'Eastside',
      description: 'Live jazz music and craft cocktails',
      imageUrl:
          'https://images.unsplash.com/photo-1566733971017-f8a6c8c2c6b3?w=800&h=400&fit=crop',
      categories: <String>['Jazz', 'Live Music', 'Cocktails'],
      rating: 4.4,
      distanceKm: 1.8,
    ),
  ];

  // Search clubs with filters
  Future<List<Club>> search({
    String query = '',
    bool hottest = false,
    bool nearest = false,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> queryRef = _clubsCollection;

      // Apply text search if query is provided
      if (query.isNotEmpty) {
        // For Firestore, we'll do client-side search for now
        // In production, you might want to use Algolia or similar for better search
        queryRef = queryRef;
      }

      // Apply sorting
      if (hottest) {
        queryRef = queryRef.orderBy('rating', descending: true);
      } else if (nearest) {
        queryRef = queryRef.orderBy('distanceKm', descending: false);
      } else {
        // Default sorting by name
        queryRef = queryRef.orderBy('name');
      }

      // Apply limit
      queryRef = queryRef.limit(limit);

      final QuerySnapshot snapshot = await queryRef.get();
      List<Club> clubs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        return Club.fromJson(data);
      }).toList();

      // Apply client-side text search if query is provided
      if (query.isNotEmpty) {
        clubs = clubs
            .where((club) =>
                club.name.toLowerCase().contains(query.toLowerCase()) ||
                club.location.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }

      return clubs;
    } catch (e) {
      print('Error searching clubs: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      return getMockClubs(
          query: query, hottest: hottest, nearest: nearest, limit: limit);
    }
  }

  // List all clubs
  Future<List<Club>> listClubs({int limit = 20}) async {
    try {
      // Try to load from cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_clubs');
      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        final cachedClubs = decodedData.map((json) => Club.fromJson(json)).toList();
        print('Using cached clubs data');
        
        // Return cached data immediately, then fetch fresh data in background
        _fetchAndCacheClubs(limit);
        return cachedClubs;
      }

      // If no cache, fetch from Firestore
      return await _fetchAndCacheClubs(limit);
    } catch (e) {
      print('Error listing clubs: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      return getMockClubs(limit: limit);
    }
  }

  // Helper method to fetch and cache clubs
  Future<List<Club>> _fetchAndCacheClubs(int limit) async {
    try {
      final QuerySnapshot snapshot =
          await _clubsCollection.orderBy('name').limit(limit).get();

      if (snapshot.docs.isEmpty) {
        return getMockClubs(limit: limit);
      }

      final clubs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Club.fromJson(data);
      }).toList();

      // Cache the fetched data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_clubs', jsonEncode(clubs.map((c) => c.toJson()).toList()));
      print('Cached ${clubs.length} clubs');

      return clubs;
    } catch (e) {
      print('Error fetching clubs: $e');
      return [];
    }
  }

  // Get club by ID
  Future<Club?> getById(String id) async {
    try {
      final DocumentSnapshot doc = await _clubsCollection.doc(id).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Club.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error getting club by ID: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      return _mockClubs.firstWhere((club) => club.id == id);
    }
  }

  // Get club by ID (alias for getById)
  Future<Club?> getClub(String id) async {
    return await getById(id);
  }

  // Create a new club
  Future<String> createClub(Club club) async {
    try {
      final Map<String, dynamic> clubData = club.toJson();
      clubData.remove('id'); // Remove ID as Firestore will generate it

      final DocumentReference docRef = await _clubsCollection.add(clubData);
      return docRef.id;
    } catch (e) {
      print('Error creating club: $e');
      throw Exception('Failed to create club: $e');
    }
  }

  // Update an existing club
  Future<void> updateClub(String id, Map<String, dynamic> updates) async {
    try {
      await _clubsCollection.doc(id).update(updates);
    } catch (e) {
      print('Error updating club: $e');
      throw Exception('Failed to update club: $e');
    }
  }

  // Delete a club
  Future<void> deleteClub(String id) async {
    try {
      await _clubsCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting club: $e');
      throw Exception('Failed to delete club: $e');
    }
  }

  // Get clubs by category
  Future<List<Club>> getClubsByCategory(String category) async {
    try {
      final QuerySnapshot snapshot = await _clubsCollection
          .where('categories', arrayContains: category)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Club.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error getting clubs by category: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      return getMockClubs()
          .where((club) => club.categories.contains(category))
          .toList();
    }
  }

  // Get clubs within distance range
  Future<List<Club>> getClubsWithinDistance(double maxDistanceKm) async {
    try {
      final QuerySnapshot snapshot = await _clubsCollection
          .where('distanceKm', isLessThanOrEqualTo: maxDistanceKm)
          .orderBy('distanceKm')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Club.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error getting clubs within distance: $e');
      print('Falling back to mock data...');
      // Fallback to mock data
      return getMockClubs()
          .where((club) => club.distanceKm <= maxDistanceKm)
          .toList();
    }
  }

  // Stream clubs for real-time updates
  Stream<List<Club>> streamClubs({int limit = 20}) {
    return _clubsCollection
        .orderBy('name')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Club.fromJson(data);
            }).toList())
        .handleError((error) {
      print('Error streaming clubs: $error');
      print('Falling back to mock data...');
      return getMockClubs(limit: limit);
    });
  }

  // Stream a specific club for real-time updates
  Stream<Club?> streamClub(String id) {
    return _clubsCollection.doc(id).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Club.fromJson(data);
      }
      return null;
    }).handleError((error) {
      print('Error streaming club: $error');
      print('Falling back to mock data...');
      return _mockClubs.firstWhere((club) => club.id == id);
    });
  }

  // Helper method to get mock clubs with filters
  List<Club> getMockClubs({
    String query = '',
    bool hottest = false,
    bool nearest = false,
    int limit = 20,
  }) {
    List<Club> clubs = List.from(_mockClubs);

    // Apply text search
    if (query.isNotEmpty) {
      clubs = clubs
          .where((club) =>
              club.name.toLowerCase().contains(query.toLowerCase()) ||
              club.location.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    // Apply sorting
    if (hottest) {
      clubs.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (nearest) {
      clubs.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {
      clubs.sort((a, b) => a.name.compareTo(b.name));
    }

    // Apply limit
    if (limit > 0) {
      clubs = clubs.take(limit).toList();
    }

    return clubs;
  }

  // Get all clubs (admin function)
  Future<List<Club>> getAllClubs() async {
    try {
      final QuerySnapshot snapshot = await _clubsCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Club.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all clubs: $e');
    }
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get nearby clubs based on user location
  Future<List<Club>> getNearbyClubs({
    required double userLatitude,
    required double userLongitude,
    double maxDistanceKm = 10.0,
    int limit = 20,
  }) async {
    try {
      // Get all clubs first
      final List<Club> allClubs = await listClubs(limit: 100);

      // Calculate distances and filter nearby clubs
      final List<Club> nearbyClubs = allClubs.where((club) {
        // For now, we'll use the existing distanceKm field or calculate if we have coordinates
        // In a real app, you'd store latitude/longitude for each club
        return club.distanceKm <= maxDistanceKm;
      }).toList();

      // Sort by distance
      nearbyClubs.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      return nearbyClubs.take(limit).toList();
    } catch (e) {
      print('Error getting nearby clubs: $e');
      // Fallback to mock data with distance filtering
      return getMockClubs(nearest: true, limit: limit)
          .where((club) => club.distanceKm <= maxDistanceKm)
          .toList();
    }
  }

  // Get clubs with enhanced location data
  Future<List<Club>> getClubsWithLocation({
    double? userLatitude,
    double? userLongitude,
    String query = '',
    bool sortByDistance = false,
    int limit = 20,
  }) async {
    try {
      List<Club> clubs = await listClubs(limit: limit);

      // Apply text search if query is provided
      if (query.isNotEmpty) {
        clubs = clubs
            .where((club) =>
                club.name.toLowerCase().contains(query.toLowerCase()) ||
                club.location.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }

      // Sort by distance if user location is provided and sorting is requested
      if (sortByDistance && userLatitude != null && userLongitude != null) {
        clubs.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      }

      return clubs;
    } catch (e) {
      print('Error getting clubs with location: $e');
      return getMockClubs(query: query, nearest: sortByDistance, limit: limit);
    }
  }

  // Search clubs with location-based suggestions
  Future<List<Club>> searchClubsNearby({
    required double userLatitude,
    required double userLongitude,
    String query = '',
    double maxDistanceKm = 15.0,
    int limit = 10,
  }) async {
    try {
      // Get nearby clubs
      final List<Club> nearbyClubs = await getNearbyClubs(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        maxDistanceKm: maxDistanceKm,
        limit: limit * 2, // Get more to filter by query
      );

      // Apply text search if query is provided
      if (query.isNotEmpty) {
        return nearbyClubs
            .where((club) =>
                club.name.toLowerCase().contains(query.toLowerCase()) ||
                club.location.toLowerCase().contains(query.toLowerCase()))
            .take(limit)
            .toList();
      }

      return nearbyClubs.take(limit).toList();
    } catch (e) {
      print('Error searching clubs nearby: $e');
      return getMockClubs(query: query, nearest: true, limit: limit);
    }
  }

  // Get nearby venues from Google Places API
  Future<List<Place>> getNearbyVenuesFromPlaces({
    required double userLatitude,
    required double userLongitude,
    double radius = 3000, // 3km radius to limit to city area
    String keyword = '',
    String? cityName, // Optional city name for filtering
  }) async {
    try {
      return await _placesService.searchNightlifeVenues(
        latitude: userLatitude,
        longitude: userLongitude,
        radius: radius,
        keyword: keyword,
        cityName: cityName,
      );
    } catch (e) {
      print('Error getting nearby venues from Places API: $e');
      return [];
    }
  }

  // Search venues with autocomplete from Google Places
  Future<List<Place>> searchVenuesWithAutocomplete({
    required String query,
    double? userLatitude,
    double? userLongitude,
    double radius = 5000, // 5km radius for autocomplete to limit to city area
  }) async {
    try {
      return await _placesService.searchPlaces(
        query: query,
        latitude: userLatitude,
        longitude: userLongitude,
        radius: radius,
      );
    } catch (e) {
      print('Error searching venues with autocomplete: $e');
      return [];
    }
  }

  // Get venue details from Google Places
  Future<PlaceDetails?> getVenueDetails(String placeId) async {
    try {
      return await _placesService.getPlaceDetails(placeId);
    } catch (e) {
      print('Error getting venue details: $e');
      return null;
    }
  }

  // Convert Google Place to Club model
  Club placeToClub(Place place, {double? userLatitude, double? userLongitude}) {
    double distance = 0.0;
    if (userLatitude != null &&
        userLongitude != null &&
        place.latitude != null &&
        place.longitude != null) {
      distance = _calculateDistance(
          userLatitude, userLongitude, place.latitude!, place.longitude!);
    }

    // Create a unique ID by combining placeId with coordinates to avoid duplicates
    // If coordinates are missing, use a random number to ensure uniqueness
    final lat =
        place.latitude ?? (place.placeId?.hashCode ?? 0) % 1000 / 1000.0;
    final lng =
        place.longitude ?? (place.placeId?.hashCode ?? 0) % 1000 / 1000.0;
    final uniqueId = '${place.placeId ?? 'unknown'}_${lat}_${lng}';

    print(
        'ClubService: Converting place ${place.name} with ID: $uniqueId, lat: ${place.latitude}, lng: ${place.longitude}');
    print('ClubService: Address: ${place.formattedAddress}');

    // Use a shorter location format for better display
    String location = 'Unknown Location';
    if (place.formattedAddress != null && place.formattedAddress!.isNotEmpty) {
      // Extract just the street address and city, not the full formatted address
      final parts = place.formattedAddress!.split(',');
      if (parts.length >= 2) {
        location = '${parts[0].trim()}, ${parts[1].trim()}';
      } else {
        location = place.formattedAddress!;
      }
    }

    return Club(
      id: uniqueId,
      name: place.name ?? 'Unknown Venue',
      location: location,
      description: place.types?.join(', ') ?? '',
      imageUrl: place.photoReference != null
          ? _placesService.getPhotoUrl(place.photoReference!)
          : '',
      categories: place.types ?? [],
      rating: place.rating ?? 0.0,
      distanceKm: distance,
    );
  }

  // Get enhanced nearby clubs combining local data with Google Places
  Future<List<Club>> getEnhancedNearbyClubs({
    required double userLatitude,
    required double userLongitude,
    double maxDistanceKm = 5.0, // Reduced to 5km to limit to city area
    int limit = 20,
    String? cityName, // Optional city name for filtering
  }) async {
    try {
      // Get local clubs
      final List<Club> localClubs = await getNearbyClubs(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        maxDistanceKm: maxDistanceKm,
        limit: limit,
      );

      // Get Google Places venues
      final List<Place> placesVenues = await getNearbyVenuesFromPlaces(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        radius: (maxDistanceKm * 1000).toDouble(), // Convert km to meters
        cityName: cityName, // Use detected city name
      );

      // Convert Places to Clubs
      final List<Club> placesClubs = placesVenues
          .map((place) => placeToClub(place,
              userLatitude: userLatitude, userLongitude: userLongitude))
          .where((club) => club.distanceKm <= maxDistanceKm)
          .toList();

      // Combine and deduplicate
      final Map<String, Club> allClubs = {};

      // Add local clubs first (they have priority)
      for (Club club in localClubs) {
        allClubs[club.id] = club;
      }

      // Add Places clubs (only if not already exists)
      for (Club club in placesClubs) {
        if (!allClubs.containsKey(club.id)) {
          allClubs[club.id] = club;
        }
      }

      // Sort by distance and return
      final List<Club> result = allClubs.values.toList();
      result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      return result.take(limit).toList();
    } catch (e) {
      print('Error getting enhanced nearby clubs: $e');
      // Fallback to local clubs only
      return await getNearbyClubs(
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        maxDistanceKm: maxDistanceKm,
        limit: limit,
      );
    }
  }

  // Get personalized recommendations for a user
  Future<List<Club>> getPersonalizedRecommendations({
    required String userId,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
    int limit = 10,
  }) async {
    try {
      // Get all available venues
      final allVenues = await listClubs(limit: 100);

      // Get personalized recommendations
      return await _recommendationService.getPersonalizedRecommendations(
        allVenues: allVenues,
        userPreferences: userPreferences,
        userBehavior: userBehavior,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        limit: limit,
      );
    } catch (e) {
      print('Error getting personalized recommendations: $e');
      return [];
    }
  }

  // Get trending recommendations
  Future<List<Club>> getTrendingRecommendations({
    required String userId,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
    int limit = 5,
  }) async {
    try {
      final allVenues = await listClubs(limit: 100);

      return await _recommendationService.getTrendingRecommendations(
        allVenues: allVenues,
        userPreferences: userPreferences,
        userBehavior: userBehavior,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        limit: limit,
      );
    } catch (e) {
      print('Error getting trending recommendations: $e');
      return [];
    }
  }

  // Get diverse recommendations
  Future<List<Club>> getDiverseRecommendations({
    required String userId,
    required UserPreferences userPreferences,
    required UserBehavior userBehavior,
    double? userLatitude,
    double? userLongitude,
    int limit = 10,
  }) async {
    try {
      final allVenues = await listClubs(limit: 100);

      return await _recommendationService.getDiverseRecommendations(
        allVenues: allVenues,
        userPreferences: userPreferences,
        userBehavior: userBehavior,
        userLatitude: userLatitude,
        userLongitude: userLongitude,
        limit: limit,
      );
    } catch (e) {
      print('Error getting diverse recommendations: $e');
      return [];
    }
  }

  // Track user behavior
  void trackUserBehavior({
    required String userId,
    required String eventType,
    required String venueId,
    required String venueCategory,
    required String venueLocation,
    double rating = 0.0,
    int duration = 0,
  }) {
    _behaviorTrackingService.trackEvent(
      userId: userId,
      eventType: eventType,
      venueId: venueId,
      rating: rating,
      category: venueCategory,
      location: venueLocation,
      duration: duration,
    );
  }

  // Track venue visit
  void trackVenueVisit({
    required String userId,
    required String venueId,
    required String venueCategory,
    required String venueLocation,
    double rating = 0.0,
    int duration = 0,
  }) {
    _behaviorTrackingService.trackVenueVisit(
      userId: userId,
      venueId: venueId,
      venueCategory: venueCategory,
      venueLocation: venueLocation,
      rating: rating,
      duration: duration,
    );
  }

  // Track party creation
  void trackPartyCreation({
    required String userId,
    required String venueId,
    required String venueCategory,
    required String venueLocation,
  }) {
    _behaviorTrackingService.trackPartyCreation(
      userId: userId,
      venueId: venueId,
      venueCategory: venueCategory,
      venueLocation: venueLocation,
    );
  }

  // Track search behavior
  void trackSearch({
    required String userId,
    required String searchQuery,
    required String selectedVenueId,
    required String venueCategory,
  }) {
    _behaviorTrackingService.trackSearch(
      userId: userId,
      searchQuery: searchQuery,
      selectedVenueId: selectedVenueId,
      venueCategory: venueCategory,
    );
  }

  // Add sample data for development
  Future<void> addSampleData() async {
    try {
      final List<Map<String, dynamic>> sampleClubs = [
        {
          'name': 'Neon Pulse',
          'location': 'Downtown',
          'description':
              'EDM and dance hits with state-of-the-art sound system',
          'imageUrl':
              'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=1200',
          'categories': ['Hottest', 'Dance', 'EDM'],
          'rating': 4.7,
          'distanceKm': 1.2,
          'capacity': 500,
          'entryFee': 25.0,
          'openingHours': '22:00-04:00',
        },
        {
          'name': 'Velvet Room',
          'location': 'Midtown',
          'description': 'Sophisticated cocktails and live DJ performances',
          'imageUrl':
              'https://images.unsplash.com/photo-1520975916090-3105956d8ac38?q=80&w=1200',
          'categories': ['Nearest', 'Lounge', 'Cocktails'],
          'rating': 4.5,
          'distanceKm': 0.6,
          'capacity': 200,
          'entryFee': 15.0,
          'openingHours': '20:00-02:00',
        },
        {
          'name': 'Skyline Lounge',
          'location': 'Uptown',
          'description': 'Rooftop vibes with panoramic city views',
          'imageUrl':
              'https://images.unsplash.com/photo-1517095037594-166575f1e866?q=80&w=1200',
          'categories': ['Hottest', 'Rooftop', 'Luxury'],
          'rating': 4.8,
          'distanceKm': 3.4,
          'capacity': 150,
          'entryFee': 35.0,
          'openingHours': '21:00-03:00',
        },
        {
          'name': 'Bass Drop',
          'location': 'Westside',
          'description': 'Underground electronic music and techno',
          'imageUrl':
              'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800&h=400&fit=crop',
          'categories': ['Electronic', 'Techno', 'Underground'],
          'rating': 4.6,
          'distanceKm': 2.1,
          'capacity': 300,
          'entryFee': 20.0,
          'openingHours': '23:00-05:00',
        },
        {
          'name': 'Jazz Corner',
          'location': 'Eastside',
          'description': 'Live jazz music and craft cocktails',
          'imageUrl':
              'https://images.unsplash.com/photo-1566733971017-f8a6c8c2c6b3?w=800&h=400&fit=crop',
          'categories': ['Jazz', 'Live Music', 'Cocktails'],
          'rating': 4.4,
          'distanceKm': 1.8,
          'capacity': 120,
          'entryFee': 18.0,
          'openingHours': '19:00-01:00',
        },
      ];

      for (final clubData in sampleClubs) {
        await _clubsCollection.add(clubData);
      }

      print('Sample clubs added successfully');
    } catch (e) {
      print('Error adding sample data: $e');
    }
  }
}

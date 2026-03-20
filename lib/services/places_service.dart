import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bunny/models/place.dart';
import 'package:bunny/config/places_config.dart';

class PlacesService {
  static const String _apiKey = PlacesConfig.apiKey;
  static const String _baseUrl = PlacesConfig.baseUrl;

  // Search for nearby places (nightlife venues)
  Future<List<Place>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    double radius = 3000, // 3km radius to limit to city area
    String type = 'night_club',
    String keyword = '',
  }) async {
    try {
      final String url = '$_baseUrl/nearbysearch/json'
          '?location=$latitude,$longitude'
          '&radius=$radius'
          '&type=$type'
          '&keyword=$keyword'
          '&components=country:ph' // Restrict to Philippines only
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];

        return results.map((place) => Place.fromJson(place)).toList();
      } else {
        print('Error fetching places: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in searchNearbyPlaces: $e');
      return [];
    }
  }

  // Get place details by place_id
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final String url = '$_baseUrl/details/json'
          '?place_id=$placeId'
          '&fields=name,formatted_address,geometry,rating,user_ratings_total,photos,opening_hours,types,website,formatted_phone_number'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          return PlaceDetails.fromJson(data['result']);
        }
      } else {
        print('Error fetching place details: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('Error in getPlaceDetails: $e');
      return null;
    }
  }

  // Autocomplete search for places
  Future<List<Place>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
    double radius = 10000, // 10km radius
  }) async {
    try {
      String url = '$_baseUrl/autocomplete/json'
          '?input=$query'
          '&components=country:ph' // Restrict to Philippines only
          '&key=$_apiKey';

      if (latitude != null && longitude != null) {
        url += '&location=$latitude,$longitude&radius=$radius';
      }

      print('PlacesService: Searching with URL: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('PlacesService: Autocomplete response status: ${data['status']}');
        print('PlacesService: Autocomplete response: ${data.toString()}');
        final List<dynamic> predictions = data['predictions'] ?? [];
        print('PlacesService: Found ${predictions.length} predictions');

        if (data['status'] != 'OK') {
          print('PlacesService: API returned error status: ${data['status']}');
          return [];
        }

        // Create places directly from autocomplete predictions
        // This is more reliable than calling place details API for each prediction
        List<Place> places = [];
        for (int i = 0; i < predictions.length && i < 5; i++) {
          // Limit to 5 results
          var prediction = predictions[i];
          print(
              'PlacesService: Processing prediction $i: ${prediction['description']}');

          if (prediction['place_id'] != null) {
            // Extract structured data from prediction
            final structuredFormatting = prediction['structured_formatting'];
            final mainText = structuredFormatting?['main_text'] ?? 'Unknown';
            final secondaryText = structuredFormatting?['secondary_text'] ?? '';
            final fullDescription =
                prediction['description'] ?? 'Unknown Location';

            // Additional filtering to ensure Philippines only
            if (!_isPhilippinesLocation(fullDescription, secondaryText)) {
              print(
                  'PlacesService: Skipping non-Philippines location: $fullDescription');
              continue;
            }

            print('PlacesService: Creating place: $mainText at $secondaryText');

            // Create place directly from autocomplete data
            places.add(Place(
              placeId: prediction['place_id'],
              name: mainText,
              formattedAddress: fullDescription,
              latitude: null, // We don't have coordinates from autocomplete
              longitude: null,
              types: (prediction['types'] as List<dynamic>?)?.cast<String>(),
            ));
          }
        }

        print('PlacesService: Returning ${places.length} places');
        return places;
      } else {
        print(
            'Error fetching autocomplete: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error in searchPlaces: $e');
      return [];
    }
  }

  // Get photo URL for a place
  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=$_apiKey';
  }

  // Helper method to check if a location is in the Philippines
  bool _isPhilippinesLocation(String fullDescription, String secondaryText) {
    final description = fullDescription.toLowerCase();
    final secondary = secondaryText.toLowerCase();

    // Check for Philippines indicators
    final philippinesIndicators = [
      'philippines',
      'ph',
      'manila',
      'cebu',
      'davao',
      'quezon city',
      'makati',
      'taguig',
      'pasig',
      'mandaluyong',
      'san juan',
      'marikina',
      'paranaque',
      'las pinas',
      'muntinlupa',
      'caloocan',
      'malabon',
      'navotas',
      'valenzuela',
      'pateros',
      'cavite',
      'laguna',
      'rizal',
      'bulacan',
      'pampanga',
      'bataan',
      'zambales',
      'tarlac',
      'nueva ecija',
      'aurora',
      'batangas',
      'quezon',
      'rizal',
      'marinduque',
      'romblon',
      'palawan',
      'mindoro',
      'masbate',
      'catanduanes',
      'albay',
      'sorsogon',
      'camarines',
      'bicol',
      'ilocos',
      'la union',
      'pangasinan',
      'isabela',
      'cagayan',
      'quirino',
      'nueva vizcaya',
      'ifugao',
      'benguet',
      'mountain province',
      'abra',
      'apayao',
      'kalinga',
      'ilocos norte',
      'ilocos sur',
      'la union',
      'pangasinan',
      'benguet',
      'mountain province',
      'ifugao',
      'kalinga',
      'apayao',
      'abra',
      'cagayan',
      'isabela',
      'nueva vizcaya',
      'quirino',
      'batanes',
      'ncr',
      'national capital region',
      'metro manila',
      'ncr',
      'calabarzon',
      'mimaropa',
      'bicol region',
      'western visayas',
      'central visayas',
      'eastern visayas',
      'zamboanga peninsula',
      'northern mindanao',
      'davao region',
      'soccsksargen',
      'caraga',
      'bangsamoro',
      'cordillera administrative region',
      'cagayan valley',
      'central luzon',
      'calabarzon',
      'mimaropa',
      'bicol',
      'western visayas',
      'central visayas',
      'eastern visayas',
      'zamboanga peninsula',
      'northern mindanao',
      'davao',
      'soccsksargen',
      'caraga',
      'bangsamoro',
      'cordillera',
      'cagayan valley',
      'central luzon',
    ];

    // Check if any Philippines indicator is present
    for (String indicator in philippinesIndicators) {
      if (description.contains(indicator) || secondary.contains(indicator)) {
        return true;
      }
    }

    return false;
  }

  // Search for nightlife venues specifically
  Future<List<Place>> searchNightlifeVenues({
    required double latitude,
    required double longitude,
    double radius = 3000, // 3km radius to limit to city area
    String keyword = '',
    String? cityName, // Optional city name for filtering
  }) async {
    // Search for multiple nightlife-related types
    final List<String> nightlifeTypes = PlacesConfig.nightlifeTypes;

    List<Place> allPlaces = [];

    for (String type in nightlifeTypes) {
      final places = await searchNearbyPlaces(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        type: type,
        keyword: keyword,
      );
      allPlaces.addAll(places);
    }

    // Remove duplicates based on place_id
    final Map<String, Place> uniquePlaces = {};
    for (Place place in allPlaces) {
      if (place.placeId != null) {
        uniquePlaces[place.placeId!] = place;
      }
    }

    List<Place> filteredPlaces = uniquePlaces.values.toList();

    // First filter to ensure only Philippines locations
    filteredPlaces = filteredPlaces.where((place) {
      final address = place.formattedAddress ?? '';
      return _isPhilippinesLocation(address, '');
    }).toList();

    print(
        'PlacesService: After Philippines filtering: ${filteredPlaces.length} places');

    // Filter by city name if provided (but be less strict)
    if (cityName != null && cityName.isNotEmpty) {
      print('PlacesService: Filtering places by city: $cityName');
      print('PlacesService: Before filtering: ${filteredPlaces.length} places');

      // Try exact city match first
      List<Place> cityMatches = filteredPlaces.where((place) {
        final address = place.formattedAddress ?? '';
        final cityLower = cityName.toLowerCase();
        return address.toLowerCase().contains(cityLower);
      }).toList();

      // If no exact matches, try partial matches or return all venues
      if (cityMatches.isEmpty) {
        print('PlacesService: No exact city matches, trying partial matches');
        cityMatches = filteredPlaces.where((place) {
          final address = place.formattedAddress ?? '';
          final cityWords = cityName.toLowerCase().split(' ');
          return cityWords.any((word) => address.toLowerCase().contains(word));
        }).toList();
      }

      // If still no matches, return all venues (location-based filtering is more important)
      if (cityMatches.isEmpty) {
        print(
            'PlacesService: No city matches found, returning all venues (location-based filtering)');
        cityMatches = filteredPlaces;
      }

      filteredPlaces = cityMatches;
      print('PlacesService: After filtering: ${filteredPlaces.length} places');
    }

    return filteredPlaces;
  }
}

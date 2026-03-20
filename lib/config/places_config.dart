class PlacesConfig {
  // TODO: Replace with your actual Google Places API key
  // Get your API key from: https://console.cloud.google.com/
  // Enable the following APIs:
  // - Places API
  // - Places API (New)
  // - Geocoding API
  static const String apiKey = 'AIzaSyBLj1BC_FzqGkO2au9i2bdTwCZuHBscRiI';

  // API endpoints
  static const String baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Default search parameters
  static const double defaultRadius =
      3000.0; // 3km in meters to limit to city area
  static const int defaultLimit = 20;

  // Nightlife venue types to search for
  static const List<String> nightlifeTypes = [
    'night_club',
    'bar',
    'restaurant',
    'establishment'
  ];
}

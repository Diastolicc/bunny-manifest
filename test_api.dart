import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🚀 Google Places API Test');
  print('=' * 50);

  // Your API key from the config
  const String apiKey = 'AIzaSyBLj1BC_FzqGkO2au9i2bdTwCZuHBscRiI';
  const String baseUrl = 'https://maps.googleapis.com/maps/api/place';

  print('API Key: ${apiKey.substring(0, 10)}...');
  print('');

  // Test 1: Basic connectivity
  print('📋 Test 1: Basic API Connectivity');
  print('-' * 30);

  try {
    final String url = '$baseUrl/nearbysearch/json'
        '?location=37.7749,-122.4194' // San Francisco
        '&radius=5000' // 5km radius to limit to city
        '&type=restaurant'
        '&key=$apiKey';

    print('Making request to: $url');
    final response = await http.get(Uri.parse(url));

    print('Status Code: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('API Status: ${data['status']}');

      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        print('✅ SUCCESS: Found ${results.length} results');

        if (results.isNotEmpty) {
          final first = results[0];
          print('Sample result: ${first['name']} (Rating: ${first['rating']})');
        }
      } else {
        print(
            '❌ FAILED: API returned error - ${data['error_message'] ?? 'Unknown error'}');
      }
    } else {
      print('❌ FAILED: HTTP ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ FAILED: Exception - $e');
  }

  print('');

  // Test 2: Nightlife search
  print('📋 Test 2: Nightlife Venue Search');
  print('-' * 30);

  try {
    final String url = '$baseUrl/nearbysearch/json'
        '?location=37.7749,-122.4194'
        '&radius=5000' // 5km radius to limit to city
        '&type=night_club'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final results = data['results'] as List;
        print('✅ SUCCESS: Found ${results.length} nightlife venues');

        for (int i = 0; i < results.length && i < 3; i++) {
          final venue = results[i];
          print('  - ${venue['name']} (${venue['rating']}⭐)');
        }
      } else {
        print('❌ FAILED: ${data['error_message'] ?? 'Unknown error'}');
      }
    } else {
      print('❌ FAILED: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('❌ FAILED: Exception - $e');
  }

  print('');

  // Test 3: Autocomplete
  print('📋 Test 3: Autocomplete Search');
  print('-' * 30);

  try {
    final String url = '$baseUrl/autocomplete/json'
        '?input=nightclub'
        '&location=37.7749,-122.4194'
        '&radius=5000'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final predictions = data['predictions'] as List;
        print(
            '✅ SUCCESS: Found ${predictions.length} autocomplete suggestions');

        for (int i = 0; i < predictions.length && i < 3; i++) {
          final suggestion = predictions[i];
          print('  - ${suggestion['description']}');
        }
      } else {
        print('❌ FAILED: ${data['error_message'] ?? 'Unknown error'}');
      }
    } else {
      print('❌ FAILED: HTTP ${response.statusCode}');
    }
  } catch (e) {
    print('❌ FAILED: Exception - $e');
  }

  print('');
  print('🏁 Test completed!');
  print('If you see ✅ SUCCESS messages above, your API is working correctly.');
  print('If you see ❌ FAILED messages, check your API key and billing setup.');
}

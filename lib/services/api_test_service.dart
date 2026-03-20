import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bunny/config/places_config.dart';

class ApiTestService {
  static const String _baseUrl = PlacesConfig.baseUrl;
  static const String _apiKey = PlacesConfig.apiKey;

  // Test basic API connectivity
  static Future<Map<String, dynamic>> testApiConnectivity() async {
    try {
      print('🔍 Testing Google Places API connectivity...');
      print('API Key: ${_apiKey.substring(0, 10)}...');

      // Test with a simple nearby search
      final String url = '$_baseUrl/nearbysearch/json'
          '?location=37.7749,-122.4194' // San Francisco coordinates
          '&radius=1000'
          '&type=restaurant'
          '&key=$_apiKey';

      print('📡 Making request to: $url');

      final response = await http.get(Uri.parse(url));

      print('📊 Response Status: ${response.statusCode}');
      print('📊 Response Body Length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ API Response Status: ${data['status']}');

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          print('✅ Found ${results.length} results');

          if (results.isNotEmpty) {
            final firstResult = results[0];
            print('✅ First result: ${firstResult['name']}');
            print('✅ Rating: ${firstResult['rating']}');
            print('✅ Types: ${firstResult['types']}');
          }

          return {
            'success': true,
            'status': data['status'],
            'results_count': results.length,
            'message': 'API is working correctly!',
            'sample_result': results.isNotEmpty ? results[0] : null,
          };
        } else {
          return {
            'success': false,
            'status': data['status'],
            'error': data['error_message'] ?? 'Unknown API error',
            'message': 'API returned error status: ${data['status']}',
          };
        }
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'message': 'HTTP error: ${response.statusCode}',
          'response_body': response.body,
        };
      }
    } catch (e) {
      print('❌ Error testing API: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Network or parsing error occurred',
      };
    }
  }

  // Test nightlife venue search
  static Future<Map<String, dynamic>> testNightlifeSearch() async {
    try {
      print('🍸 Testing nightlife venue search...');

      final String url = '$_baseUrl/nearbysearch/json'
          '?location=37.7749,-122.4194' // San Francisco coordinates
          '&radius=2000'
          '&type=night_club'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          print('✅ Found ${results.length} nightlife venues');

          return {
            'success': true,
            'venues_found': results.length,
            'venues': results.take(3).toList(), // First 3 venues
            'message': 'Nightlife search working!',
          };
        } else {
          return {
            'success': false,
            'status': data['status'],
            'error': data['error_message'] ?? 'Unknown error',
            'message': 'Nightlife search failed: ${data['status']}',
          };
        }
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'message': 'HTTP error in nightlife search',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error in nightlife search',
      };
    }
  }

  // Test autocomplete functionality
  static Future<Map<String, dynamic>> testAutocomplete() async {
    try {
      print('🔍 Testing autocomplete search...');

      final String url = '$_baseUrl/autocomplete/json'
          '?input=nightclub'
          '&location=37.7749,-122.4194'
          '&radius=5000'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          print('✅ Found ${predictions.length} autocomplete suggestions');

          return {
            'success': true,
            'suggestions_found': predictions.length,
            'suggestions': predictions.take(3).toList(),
            'message': 'Autocomplete working!',
          };
        } else {
          return {
            'success': false,
            'status': data['status'],
            'error': data['error_message'] ?? 'Unknown error',
            'message': 'Autocomplete failed: ${data['status']}',
          };
        }
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'message': 'HTTP error in autocomplete',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error in autocomplete test',
      };
    }
  }

  // Run comprehensive API test
  static Future<Map<String, dynamic>> runComprehensiveTest() async {
    print('🚀 Starting comprehensive Google Places API test...\n');

    final results = <String, dynamic>{};

    // Test 1: Basic connectivity
    print('📋 Test 1: Basic API Connectivity');
    print('=' * 50);
    final connectivityTest = await testApiConnectivity();
    results['connectivity'] = connectivityTest;
    print('');

    // Test 2: Nightlife search
    print('📋 Test 2: Nightlife Venue Search');
    print('=' * 50);
    final nightlifeTest = await testNightlifeSearch();
    results['nightlife_search'] = nightlifeTest;
    print('');

    // Test 3: Autocomplete
    print('📋 Test 3: Autocomplete Search');
    print('=' * 50);
    final autocompleteTest = await testAutocomplete();
    results['autocomplete'] = autocompleteTest;
    print('');

    // Summary
    final allTestsPassed = connectivityTest['success'] == true &&
        nightlifeTest['success'] == true &&
        autocompleteTest['success'] == true;

    results['overall_success'] = allTestsPassed;
    results['summary'] = {
      'total_tests': 3,
      'passed_tests': [
        if (connectivityTest['success'] == true) 'Connectivity',
        if (nightlifeTest['success'] == true) 'Nightlife Search',
        if (autocompleteTest['success'] == true) 'Autocomplete',
      ].length,
      'message': allTestsPassed
          ? '🎉 All API tests passed! Your Google Places API is working perfectly!'
          : '⚠️ Some tests failed. Check the results above for details.',
    };

    print('📊 TEST SUMMARY');
    print('=' * 50);
    print('Overall Success: ${allTestsPassed ? "✅ PASS" : "❌ FAIL"}');
    print('Tests Passed: ${results['summary']['passed_tests']}/3');
    print('Message: ${results['summary']['message']}');

    return results;
  }
}

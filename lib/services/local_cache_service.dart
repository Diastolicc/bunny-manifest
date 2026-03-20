import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunny/models/party.dart';

class LocalCacheService {
  static const String _partyCacheKey = 'cached_parties';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const Duration _cacheExpiry =
      Duration(hours: 24); // Cache expires after 24 hours

  // In-memory fallback cache when shared_preferences fails
  static final Map<String, Party> _memoryCache = {};
  static DateTime? _memoryCacheTimestamp;

  // Flag to track if shared_preferences is working
  static bool? _sharedPreferencesWorking;

  // Check if shared_preferences is working
  static Future<bool> _isSharedPreferencesWorking() async {
    if (_sharedPreferencesWorking != null) {
      return _sharedPreferencesWorking!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      // Try a simple operation to test if it works
      await prefs.setString('_test_key', 'test');
      await prefs.remove('_test_key');
      _sharedPreferencesWorking = true;
      return true;
    } catch (e) {
      print('❌ SharedPreferences not working, using memory cache only: $e');
      _sharedPreferencesWorking = false;
      return false;
    }
  }

  // Save party data to local cache
  static Future<void> cacheParty(Party party) async {
    // Check if shared_preferences is working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Get existing cached parties
        final existingCache = prefs.getString(_partyCacheKey);
        Map<String, dynamic> cachedParties = {};

        if (existingCache != null) {
          cachedParties = jsonDecode(existingCache) as Map<String, dynamic>;
        }

        // Add/update the party in cache
        cachedParties[party.id] = party.toJson();

        // Save updated cache
        await prefs.setString(_partyCacheKey, jsonEncode(cachedParties));
        await prefs.setString(
            _cacheTimestampKey, DateTime.now().toIso8601String());

        print('✅ Party ${party.id} cached locally');
        return;
      } catch (e) {
        print('❌ Error caching party: $e');
        // Mark shared_preferences as not working and fall through to memory cache
        _sharedPreferencesWorking = false;
      }
    }

    // Use memory cache (either because shared_preferences failed or was already known to be broken)
    _memoryCache[party.id] = party;
    _memoryCacheTimestamp = DateTime.now();
    print('📱 Party ${party.id} cached in memory');
  }

  // Get party from local cache
  static Future<Party?> getCachedParty(String partyId) async {
    // Check if shared_preferences is working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Check if cache is expired
        final timestampStr = prefs.getString(_cacheTimestampKey);
        if (timestampStr != null) {
          final cacheTime = DateTime.parse(timestampStr);
          if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
            print('🕒 Cache expired, clearing...');
            await clearCache();
            return null;
          }
        }

        // Get cached parties
        final cachedData = prefs.getString(_partyCacheKey);
        if (cachedData == null) return null;

        final cachedParties = jsonDecode(cachedData) as Map<String, dynamic>;
        final partyData = cachedParties[partyId];

        if (partyData != null) {
          print('📱 Retrieved party $partyId from local cache');
          return Party.fromJson(partyData);
        }

        return null;
      } catch (e) {
        print('❌ Error retrieving cached party: $e');
        // Mark shared_preferences as not working and fall through to memory cache
        _sharedPreferencesWorking = false;
      }
    }

    // Use memory cache (either because shared_preferences failed or was already known to be broken)
    if (_memoryCacheTimestamp != null &&
        DateTime.now().difference(_memoryCacheTimestamp!) <= _cacheExpiry) {
      final party = _memoryCache[partyId];
      if (party != null) {
        print('📱 Retrieved party $partyId from memory cache');
        return party;
      }
    }
    return null;
  }

  // Cache multiple parties at once
  static Future<void> cacheParties(List<Party> parties) async {
    // Check if shared_preferences is working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Get existing cached parties
        final existingCache = prefs.getString(_partyCacheKey);
        Map<String, dynamic> cachedParties = {};

        if (existingCache != null) {
          cachedParties = jsonDecode(existingCache) as Map<String, dynamic>;
        }

        // Add all parties to cache
        for (final party in parties) {
          cachedParties[party.id] = party.toJson();
        }

        // Save updated cache
        await prefs.setString(_partyCacheKey, jsonEncode(cachedParties));
        await prefs.setString(
            _cacheTimestampKey, DateTime.now().toIso8601String());

        print('✅ ${parties.length} parties cached locally');
        return;
      } catch (e) {
        print('❌ Error caching parties: $e');
        // Mark shared_preferences as not working and fall through to memory cache
        _sharedPreferencesWorking = false;
      }
    }

    // Use memory cache (either because shared_preferences failed or was already known to be broken)
    for (final party in parties) {
      _memoryCache[party.id] = party;
    }
    _memoryCacheTimestamp = DateTime.now();
    print('📱 ${parties.length} parties cached in memory');
  }

  // Get all cached parties
  static Future<List<Party>> getAllCachedParties() async {
    // Check if shared_preferences is working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Check if cache is expired
        final timestampStr = prefs.getString(_cacheTimestampKey);
        if (timestampStr != null) {
          final cacheTime = DateTime.parse(timestampStr);
          if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
            print('🕒 Cache expired, clearing...');
            await clearCache();
            return [];
          }
        }

        // Get cached parties
        final cachedData = prefs.getString(_partyCacheKey);
        if (cachedData == null) return [];

        final cachedParties = jsonDecode(cachedData) as Map<String, dynamic>;
        final parties = <Party>[];

        for (final partyData in cachedParties.values) {
          try {
            parties.add(Party.fromJson(partyData as Map<String, dynamic>));
          } catch (e) {
            print('❌ Error parsing cached party: $e');
          }
        }

        print('📱 Retrieved ${parties.length} parties from local cache');
        return parties;
      } catch (e) {
        print('❌ Error retrieving cached parties: $e');
        // Mark shared_preferences as not working and fall through to memory cache
        _sharedPreferencesWorking = false;
      }
    }

    // Use memory cache (either because shared_preferences failed or was already known to be broken)
    if (_memoryCacheTimestamp != null &&
        DateTime.now().difference(_memoryCacheTimestamp!) <= _cacheExpiry) {
      final parties = _memoryCache.values.toList();
      print('📱 Retrieved ${parties.length} parties from memory cache');
      return parties;
    }
    return [];
  }

  // Clear all cached data
  static Future<void> clearCache() async {
    // Clear memory cache
    _memoryCache.clear();
    _memoryCacheTimestamp = null;

    // Try to clear shared_preferences if it's working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_partyCacheKey);
        await prefs.remove(_cacheTimestampKey);
        print('🗑️ Local cache cleared');
      } catch (e) {
        print('❌ Error clearing cache: $e');
        // Silently fail - clearing cache is not critical
      }
    }

    print('🗑️ Memory cache cleared');
  }

  // Check if cache is valid (not expired)
  static Future<bool> isCacheValid() async {
    // Check if shared_preferences is working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final timestampStr = prefs.getString(_cacheTimestampKey);

        if (timestampStr == null) return false;

        final cacheTime = DateTime.parse(timestampStr);
        return DateTime.now().difference(cacheTime) <= _cacheExpiry;
      } catch (e) {
        print('❌ Error checking cache validity: $e');
        // Mark shared_preferences as not working and fall through to memory cache
        _sharedPreferencesWorking = false;
      }
    }

    // Check memory cache
    return _memoryCacheTimestamp != null &&
        DateTime.now().difference(_memoryCacheTimestamp!) <= _cacheExpiry;
  }

  // Get cache info for debugging
  static Future<Map<String, dynamic>> getCacheInfo() async {
    Map<String, dynamic> info = {
      'sharedPreferencesWorking': _sharedPreferencesWorking,
      'memoryCacheCount': _memoryCache.length,
      'memoryCacheTimestamp': _memoryCacheTimestamp?.toIso8601String(),
      'isValid': await isCacheValid(),
    };

    // Try to get shared_preferences info if it's working
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final timestampStr = prefs.getString(_cacheTimestampKey);
        final cachedData = prefs.getString(_partyCacheKey);

        info['hasTimestamp'] = timestampStr != null;
        info['hasData'] = cachedData != null;

        if (timestampStr != null) {
          final cacheTime = DateTime.parse(timestampStr);
          info['cacheTime'] = cacheTime.toIso8601String();
          info['age'] = DateTime.now().difference(cacheTime).inMinutes;
        }

        if (cachedData != null) {
          final cachedParties = jsonDecode(cachedData) as Map<String, dynamic>;
          info['cachedCount'] = cachedParties.length;
        }
      } catch (e) {
        info['sharedPreferencesError'] = e.toString();
      }
    }

    return info;
  }

  // Generic method to cache JSON data with a custom key
  static Future<void> cacheJsonData(String key, dynamic data) async {
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(data));
        print('✅ Data cached with key: $key');
        return;
      } catch (e) {
        print('❌ Error caching JSON data: $e');
        _sharedPreferencesWorking = false;
      }
    }
    print('📱 Could not cache data to SharedPreferences');
  }

  // Generic method to retrieve cached JSON data with a custom key
  static Future<dynamic> getCachedJsonData(String key) async {
    if (await _isSharedPreferencesWorking()) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = prefs.getString(key);
        if (data != null) {
          print('✅ Data retrieved from cache with key: $key');
          return jsonDecode(data);
        }
      } catch (e) {
        print('❌ Error retrieving cached JSON data: $e');
        _sharedPreferencesWorking = false;
      }
    }
    return null;
  }
}

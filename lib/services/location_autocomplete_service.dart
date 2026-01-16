import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationAutocompleteService {
  // APIs configuration
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // Cache for countries and cities
  static List<String>? _countriesCache;
  // Map from country name (lowercase) -> ISO2 code (e.g. 'AU') for GeoNames fallback (if needed)
  static final Map<String, String> _countryNameToCode = {};
  static final Map<String, List<Map<String, dynamic>>> _citiesCache = {};

  /// Fetches all countries from REST Countries API, sorted alphabetically
  static Future<List<String>> getCountries() async {
    if (_countriesCache != null) {
      return _countriesCache!;
    }

    try {
      // Using REST Countries API for country list
      final response = await http.get(
        Uri.parse('https://restcountries.com/v3.1/all?fields=name,cca2'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final countries = <String>[];
        for (final country in data) {
          try {
            final name = (country['name']?['common'] ?? '').toString();
            final code = (country['cca2'] ?? '').toString();
            if (name.isNotEmpty) {
              countries.add(name);
              if (code.isNotEmpty) {
                _countryNameToCode[name.toLowerCase()] = code.toUpperCase();
              }
            }
          } catch (_) {}
        }
        countries.sort(); // Sort alphabetically

        _countriesCache = countries;
        debugPrint(
            '✓ Successfully fetched ${countries.length} countries from REST Countries API');
        return countries;
      }
    } catch (e) {
      debugPrint('❌ Error fetching countries from REST Countries API: $e');
    }

    // Fallback list if API fails
    debugPrint('⚠️ Using fallback countries list');
    return _getFallbackCountries();
  }

  /// Lookup ISO2 country code. Returns null if not found.
  static String? _getCountryCode(String? country) {
    if (country == null) return null;
    final key = country.trim().toLowerCase();
    return _countryNameToCode[key];
  }

  /// Search for cities with optional country filter using Nominatim API
  static Future<List<String>> searchCities(
    String query, {
    String? country,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      // Nominatim search query
      // Using q=[query], [country] for better results
      final q =
          country != null && country.isNotEmpty ? '$query, $country' : query;

      final uri = Uri.parse(
          '$_nominatimBaseUrl/search?format=json&q=${Uri.encodeComponent(q)}&limit=$limit&addressdetails=1');

      debugPrint('🔍 Fetching cities from Nominatim: $uri');
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MasjidConnect/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> cities = [];
        final Set<String> uniqueNames = {};

        for (final place in data) {
          final address = place['address'] as Map<String, dynamic>?;
          if (address == null) continue;

          // Nominatim returns city, town, village, or municipality
          String? cityName = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              address['suburb'] ??
              address['state_district'];

          if (cityName == null || cityName.isEmpty) continue;

          // Get country name from result for consistency, or use passed country
          final String resCountry = address['country'] ?? country ?? '';
          final String display = '$cityName, $resCountry';

          if (!uniqueNames.contains(display.toLowerCase())) {
            uniqueNames.add(display.toLowerCase());
            cities.add(display);
          }
        }

        debugPrint('✓ Found ${cities.length} cities from Nominatim for $query');
        return cities;
      } else {
        debugPrint('❌ Nominatim API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Nominatim API error: $e');
    }

    return [];
  }

  /// Resolve city name to coordinates using Nominatim API
  static Future<Map<String, double>?> resolveToCoordinates(
    String cityDisplay, {
    String? country,
  }) async {
    try {
      final q = country != null && country.isNotEmpty
          ? '$cityDisplay, $country'
          : cityDisplay;

      final uri = Uri.parse(
          '$_nominatimBaseUrl/search?format=json&q=${Uri.encodeComponent(q)}&limit=1');

      debugPrint('📍 Resolving coordinates for "$cityDisplay" via Nominatim...');
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MasjidConnect/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final place = data.first;
          final lat = double.tryParse(place['lat'].toString()) ?? 0.0;
          final lon = double.tryParse(place['lon'].toString()) ?? 0.0;

          debugPrint('✓ Resolved "$cityDisplay" to lat=$lat, lon=$lon');
          return {
            'lat': lat,
            'lon': lon,
          };
        } else {
          debugPrint('⚠️ City not found in Nominatim: "$cityDisplay"');
        }
      } else {
        debugPrint('❌ Nominatim resolve error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error resolving coordinates for "$cityDisplay": $e');
    }

    return null;
  }

  /// Fallback countries list (sorted alphabetically)
  static List<String> _getFallbackCountries() {
    return [
      'Afghanistan', 'Albania', 'Algeria', 'Australia', 'Austria',
      'Bahrain', 'Bangladesh', 'Belgium', 'Bosnia and Herzegovina', 'Brazil',
      'Canada', 'China', 'Denmark', 'Egypt', 'France',
      'Germany', 'India', 'Indonesia', 'Iran', 'Iraq',
      'Ireland', 'Italy', 'Japan', 'Jordan', 'Kuwait',
      'Lebanon', 'Libya', 'Malaysia', 'Morocco', 'Netherlands',
      'New Zealand', 'Nigeria', 'Norway', 'Oman', 'Pakistan',
      'Palestine', 'Philippines', 'Qatar', 'Russia', 'Saudi Arabia',
      'Singapore', 'Somalia', 'South Africa', 'Spain', 'Sudan',
      'Sweden', 'Switzerland', 'Syria', 'Tunisia', 'Turkey',
      'UAE', 'United Arab Emirates', 'UK', 'United Kingdom', 'USA', 'United States',
      'Yemen',
    ]..sort();
  }

  /// Clear all caches
  static void clearCache() {
    _countriesCache = null;
    _citiesCache.clear();
  }
}
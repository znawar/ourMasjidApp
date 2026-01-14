import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class LocationAutocompleteService {
  // Cache for countries and cities
  static List<String>? _countriesCache;
  static final Map<String, List<Map<String, String>>> _citiesCache = {};

  /// Get list of all countries
  static Future<List<String>> getCountries() async {
    if (_countriesCache != null) {
      return _countriesCache!;
    }

    try {
      // Using REST Countries API for country list
      final response = await http.get(
        Uri.parse('https://restcountries.com/v3.1/all?fields=name'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final countries = data
            .map((country) => country['name']['common'] as String)
            .toList()
          ..sort();
        
        _countriesCache = countries;
        return countries;
      }
    } catch (e) {
      debugPrint('Error fetching countries: $e');
    }

    // Fallback list if API fails
    return _getFallbackCountries();
  }

  /// Search for cities with optional country filter
  static Future<List<String>> searchCities(
    String query, {
    String? country,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) return [];

    // If country is specified, try to use cached major cities first
    if (country != null && country.isNotEmpty) {
      final majorCities = _getMajorCitiesForCountry(country);
      final queryLower = query.toLowerCase();
      final filtered = majorCities
          .where((city) => city.toLowerCase().contains(queryLower))
          .take(limit)
          .map((city) => '$city, $country')
          .toList();
      
      if (filtered.isNotEmpty) {
        return filtered;
      }
    }

    // Use Nominatim (OpenStreetMap) - free API, no key needed
    return _searchCitiesNominatim(query, country: country, limit: limit);
  }

  /// Fallback search using Nominatim (OpenStreetMap)
  static Future<List<String>> _searchCitiesNominatim(
    String query, {
    String? country,
    int limit = 50,
  }) async {
    try {
      final queryText = country != null && country.isNotEmpty
          ? '$query, $country'
          : query;

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search',
      ).replace(queryParameters: {
        'q': queryText,
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '1',
        'featuretype': 'city',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'MasjidAdminApp/1.0', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((place) {
          final address = place['address'] as Map<String, dynamic>?;
          final city = address?['city'] ?? 
                      address?['town'] ?? 
                      address?['village'] ?? 
                      place['display_name']?.toString().split(',').first;
          final country = address?['country'] ?? '';
          
          return '$city, $country';
        }).toSet().toList(); // Remove duplicates
      }
    } catch (e) {
      debugPrint('Nominatim API error: $e');
    }

    return [];
  }

  /// Get cities for a specific country (cached)
  static Future<List<Map<String, String>>> getCitiesForCountry(
    String country,
  ) async {
    if (country.trim().isEmpty) return [];

    final cacheKey = country.toLowerCase();
    if (_citiesCache.containsKey(cacheKey)) {
      return _citiesCache[cacheKey]!;
    }

    try {
      // For major cities, use a predefined list
      final majorCities = _getMajorCitiesForCountry(country);
      if (majorCities.isNotEmpty) {
        final cityMaps = majorCities.map((city) => {
          'name': city,
          'display': '$city, $country',
        }).toList();
        
        _citiesCache[cacheKey] = cityMaps;
        return cityMaps;
      }

      // Otherwise, fetch from API
      final cities = await searchCities('', country: country, limit: 200);
      final cityMaps = cities.map((display) {
        final cityName = display.split(',').first.trim();
        return {
          'name': cityName,
          'display': display,
        };
      }).toList();

      _citiesCache[cacheKey] = cityMaps;
      return cityMaps;
    } catch (e) {
      debugPrint('Error fetching cities for $country: $e');
      return [];
    }
  }

  /// Resolve city name to coordinates
  static Future<Map<String, double>?> resolveToCoordinates(
    String cityDisplay, {
    String? country,
  }) async {
    try {
      final queryText = country != null && country.isNotEmpty
          ? '$cityDisplay, $country'
          : cityDisplay;

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search',
      ).replace(queryParameters: {
        'q': queryText,
        'format': 'json',
        'limit': '1',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'MasjidAdminApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final place = data.first;
          return {
            'lat': double.parse(place['lat']),
            'lon': double.parse(place['lon']),
          };
        }
      }
    } catch (e) {
      debugPrint('Error resolving coordinates: $e');
    }

    return null;
  }

  /// Get ISO country code for country name (simplified mapping)
  static String _getCountryCode(String country) {
    final countryLower = country.toLowerCase();
    final Map<String, String> codes = {
      'united states': 'US',
      'usa': 'US',
      'united kingdom': 'GB',
      'uk': 'GB',
      'canada': 'CA',
      'australia': 'AU',
      'india': 'IN',
      'pakistan': 'PK',
      'bangladesh': 'BD',
      'uae': 'AE',
      'united arab emirates': 'AE',
      'saudi arabia': 'SA',
      'egypt': 'EG',
      'turkey': 'TR',
      'france': 'FR',
      'germany': 'DE',
      'indonesia': 'ID',
      'malaysia': 'MY',
      'singapore': 'SG',
    };

    return codes[countryLower] ?? '';
  }

  /// Major cities for popular countries (fallback)
  static List<String> _getMajorCitiesForCountry(String country) {
    final countryLower = country.toLowerCase();
    final Map<String, List<String>> cities = {
      'united states': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'],
      'usa': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose'],
      'united kingdom': ['London', 'Birmingham', 'Manchester', 'Leeds', 'Glasgow', 'Liverpool', 'Newcastle', 'Sheffield', 'Bristol', 'Edinburgh'],
      'uk': ['London', 'Birmingham', 'Manchester', 'Leeds', 'Glasgow', 'Liverpool', 'Newcastle', 'Sheffield', 'Bristol', 'Edinburgh'],
      'canada': ['Toronto', 'Montreal', 'Vancouver', 'Calgary', 'Ottawa', 'Edmonton', 'Mississauga', 'Winnipeg', 'Quebec City', 'Hamilton'],
      'australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide', 'Gold Coast', 'Canberra', 'Newcastle', 'Wollongong', 'Logan City'],
      'india': ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Surat'],
      'pakistan': ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar', 'Quetta', 'Sialkot', 'Gujranwala'],
      'bangladesh': ['Dhaka', 'Chittagong', 'Khulna', 'Rajshahi', 'Sylhet', 'Barisal', 'Rangpur', 'Comilla', 'Mymensingh', 'Narayanganj'],
      'uae': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain', 'Al Ain'],
      'united arab emirates': ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain', 'Al Ain'],
      'saudi arabia': ['Riyadh', 'Jeddah', 'Mecca', 'Medina', 'Dammam', 'Khobar', 'Tabuk', 'Buraidah', 'Khamis Mushait', 'Hofuf'],
      'egypt': ['Cairo', 'Alexandria', 'Giza', 'Shubra El Kheima', 'Port Said', 'Suez', 'Luxor', 'Mansoura', 'El Mahalla El Kubra', 'Tanta'],
      'turkey': ['Istanbul', 'Ankara', 'Izmir', 'Bursa', 'Adana', 'Gaziantep', 'Konya', 'Antalya', 'Kayseri', 'Mersin'],
      'indonesia': ['Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Makassar', 'Palembang', 'Tangerang', 'Depok', 'Bekasi'],
      'malaysia': ['Kuala Lumpur', 'George Town', 'Ipoh', 'Shah Alam', 'Petaling Jaya', 'Johor Bahru', 'Melaka', 'Kota Kinabalu', 'Kuching', 'Seremban'],
      'france': ['Paris', 'Marseille', 'Lyon', 'Toulouse', 'Nice', 'Nantes', 'Strasbourg', 'Montpellier', 'Bordeaux', 'Lille'],
      'germany': ['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt', 'Stuttgart', 'Düsseldorf', 'Dortmund', 'Essen', 'Leipzig'],
    };

    return cities[countryLower] ?? [];
  }

  /// Fallback countries list
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
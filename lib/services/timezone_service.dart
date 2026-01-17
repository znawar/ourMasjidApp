import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

class TimezoneResult {
  final String timezoneId; // e.g. "America/New_York"
  final int rawOffset; // seconds
  final int dstOffset; // seconds

  TimezoneResult({
    required this.timezoneId,
    required this.rawOffset,
    required this.dstOffset,
  });
}

class TimezoneService {
  // Try Google Time Zone API first if apiKey provided. Returns null on failure.
  // Example Google URL:
  // https://maps.googleapis.com/maps/api/timezone/json?location=LAT,LNG&timestamp=UNIX&key=API_KEY
  static Future<TimezoneResult?> getTimezoneFromGoogle(
      double latitude, double longitude, int timestampSeconds, String apiKey) async {
    try {
      final url = Uri.https('maps.googleapis.com', '/maps/api/timezone/json', {
        'location': '$latitude,$longitude',
        'timestamp': timestampSeconds.toString(),
        'key': apiKey,
      });
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data = jsonDecode(resp.body);
      if (data['status'] != 'OK') return null;
      final tzId = data['timeZoneId'] as String?;
      final raw = data['rawOffset'] as int? ?? 0;
      final dst = data['dstOffset'] as int? ?? 0;
      if (tzId == null) return null;
      return TimezoneResult(timezoneId: tzId, rawOffset: raw, dstOffset: dst);
    } catch (_) {
      return null;
    }
  }

  // Fallback using TimeZoneDB (requires api key). URL example:
  // http://api.timezonedb.com/v2.1/get-time-zone?key=API_KEY&format=json&by=position&lat=LAT&lng=LNG
  static Future<TimezoneResult?> getTimezoneFromTimeZoneDb(
      double latitude, double longitude, String apiKey) async {
    try {
      final url = Uri.http('api.timezonedb.com', '/v2.1/get-time-zone', {
        'key': apiKey,
        'format': 'json',
        'by': 'position',
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      });
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data = jsonDecode(resp.body);
      if (data['status'] != 'OK') return null;
      final tzId = data['zoneName'] as String?;
      final gmtOffset = data['gmtOffset'] as int? ?? 0; // seconds
      if (tzId == null) return null;
      // TimeZoneDB doesn't return dstOffset separately in this endpoint; use 0
      return TimezoneResult(timezoneId: tzId, rawOffset: gmtOffset, dstOffset: 0);
    } catch (_) {
      return null;
    }
  }

  // Free fallback using timeapi.io to resolve timezone from coordinates
  // when no paid API keys are configured.
  static Future<TimezoneResult?> getTimezoneFromFreeService(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse(
          'https://timeapi.io/api/TimeZone/coordinate?latitude=$latitude&longitude=$longitude');
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final tzId = (data['timeZone'] ??
              data['timeZoneName'] ??
              data['timeZoneId']) as String?;
      if (tzId == null || tzId.isEmpty) return null;
      // timeapi.io does not expose offsets separately; use 0s defaults.
      return TimezoneResult(timezoneId: tzId, rawOffset: 0, dstOffset: 0);
    } catch (_) {
      return null;
    }
  }

  /// Fetches current DateTime for a timezone ID using WorldTimeAPI (free, no key).
  /// Example: http://worldtimeapi.org/api/timezone/Australia/Sydney
  static Future<DateTime?> getCurrentTimeForTimezone(String timezoneId) async {
    try {
      final url = Uri.http('worldtimeapi.org', '/api/timezone/$timezoneId');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final Map<String, dynamic> data = jsonDecode(resp.body);
      final dtStr = data['datetime'] as String?;
      if (dtStr == null) return null;
      return DateTime.parse(dtStr);
    } catch (_) {
      return null;
    }
  }

  /// Returns a sorted list of all available IANA timezone IDs.
  static List<String> getAllTimezones() {
    try {
      final zones = tz.timeZoneDatabase.locations.keys.toList();
      zones.sort();
      return zones;
    } catch (e) {
      debugPrint('Error getting timezones: $e');
      return ['UTC'];
    }
  }

  /// Maps common country names to IANA timezone IDs using TimeZoneDB API
  static Future<String?> guessTimezoneFromCountry(String country) async {
    var c = country.trim().toLowerCase();
    
    debugPrint('🌍 TimezoneService.guessTimezoneFromCountry() input: "$country" -> "$c"');

    if (c.isEmpty) {
      debugPrint('⚠️ Empty country string');
      return null;
    }

    // Hardcoded country name to code mapping - check this first with fuzzy matching
    final countryCodeMap = {
      'united states': 'US',
      'usa': 'US',
      'united kingdom': 'GB',
      'uk': 'GB',
      'canada': 'CA',
      'australia': 'AU',
      'india': 'IN',
      'pakistan': 'PK',
      'bangladesh': 'BD',
      'banglade': 'BD', // Handle partial/truncated input
      'sri lanka': 'LK',
      'nepal': 'NP',
      'uae': 'AE',
      'united arab emirates': 'AE',
      'saudi arabia': 'SA',
      'malaysia': 'MY',
      'singapore': 'SG',
      'indonesia': 'ID',
      'turkey': 'TR',
      'egypt': 'EG',
      'morocco': 'MA',
      'south africa': 'ZA',
      'qatar': 'QA',
      'kuwait': 'KW',
      'oman': 'OM',
      'bahrain': 'BH',
      'jordan': 'JO',
      'lebanon': 'LB',
      'new zealand': 'NZ',
      'france': 'FR',
      'germany': 'DE',
      'spain': 'ES',
      'italy': 'IT',
      'netherlands': 'NL',
      'sweden': 'SE',
      'norway': 'NO',
      'denmark': 'DK',
      'ireland': 'IE',
      'portugal': 'PT',
      'switzerland': 'CH',
      'austria': 'AT',
      'belgium': 'BE',
    };

    // Try hardcoded map first (exact match)
    String? countryCode = countryCodeMap[c];
    if (countryCode != null) {
      debugPrint('🔍 Using hardcoded country code: $countryCode for "$c"');
    } else {
      // Try fuzzy match: check if any key starts with input or input starts with key
      for (final entry in countryCodeMap.entries) {
        if (entry.key.startsWith(c) || c.startsWith(entry.key)) {
          countryCode = entry.value;
          debugPrint('🔍 Using fuzzy-matched country code: $countryCode for "$c" (matched with "${entry.key}")');
          break;
        }
      }
    }

    // If still no code, try REST Countries API with fullText=false for partial match
    if (countryCode == null) {
      try {
        final url = Uri.https('restcountries.com', '/v3.1/name/$c', {
          'fullText': 'false', // Allow partial matches
        });
        final resp = await http.get(url).timeout(const Duration(seconds: 5));
        
        if (resp.statusCode == 200) {
          final List<dynamic> data = jsonDecode(resp.body);
          if (data.isNotEmpty) {
            final countryData = data[0] as Map<String, dynamic>;
            final cca2 = countryData['cca2'] as String?;
            if (cca2 != null && cca2.isNotEmpty) {
              countryCode = cca2;
              debugPrint('🔍 Found country code via REST API: $countryCode for "$c"');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ REST Countries API error: $e');
      }
    }

    // If we have a country code, use TimeZoneDB to get timezone
    if (countryCode != null && countryCode.isNotEmpty) {
      try {
        final url = Uri.http('api.timezonedb.com', '/v2.1/list-time-zone', {
          'key': '4068P1GO72CR',
          'format': 'json',
          'country': countryCode,
        });
        final resp = await http.get(url).timeout(const Duration(seconds: 8));
        
        if (resp.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(resp.body);
          if (data['status'] == 'OK') {
            final zones = data['zones'] as List<dynamic>?;
            if (zones != null && zones.isNotEmpty) {
              // Try to find the most populated/important city
              // Sort by population if available, otherwise use the first zone
              List<Map<String, dynamic>> zoneList = [];
              for (var zone in zones) {
                zoneList.add(zone as Map<String, dynamic>);
              }
              
              // Sort by population (descending)
              zoneList.sort((a, b) {
                final popA = a['population'] as int? ?? 0;
                final popB = b['population'] as int? ?? 0;
                return popB.compareTo(popA);
              });
              
              final bestZone = zoneList.first;
              final tzId = bestZone['zoneName'] as String?;
              if (tzId != null && tzId.isNotEmpty) {
                debugPrint('🔍 TimeZoneDB lookup for "$countryCode": Found timezone: $tzId');
                return tzId;
              }
            }
          } else {
            debugPrint('⚠️ TimeZoneDB error: ${data['error'] ?? "Unknown error"}');
          }
        } else {
          debugPrint('⚠️ TimeZoneDB API error: Status code ${resp.statusCode}');
        }
      } catch (e) {
        debugPrint('⚠️ TimeZoneDB API error: $e');
      }
    }

    debugPrint('🔍 Could not determine timezone for: "$c"');
    return null;
  }
}
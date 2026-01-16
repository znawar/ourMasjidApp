import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  /// Maps common country names to IANA timezone IDs for fallback when no coordinates.
  static Future<String?> guessTimezoneFromCountry(String country) async {
    var c = country.trim().toLowerCase();
    
    // Quick hardcoded common mapping to avoid API calls and get better results than first offset
    final commonMapping = {
      'australia': 'Australia/Sydney',
      'united kingdom': 'Europe/London',
      'uk': 'Europe/London',
      'usa': 'America/New_York',
      'united states': 'America/New_York',
      'canada': 'America/Toronto',
      'pakistan': 'Asia/Karachi',
      'india': 'Asia/Kolkata',
      'bangladesh': 'Asia/Dhaka',
      'uae': 'Asia/Dubai',
      'united arab emirates': 'Asia/Dubai',
      'saudi arabia': 'Asia/Riyadh',
      'malaysia': 'Asia/Kuala_Lumpur',
      'singapore': 'Asia/Singapore',
      'indonesia': 'Asia/Jakarta',
      'turkey': 'Europe/Istanbul',
      'egypt': 'Africa/Cairo',
      'morocco': 'Africa/Casablanca',
      'south africa': 'Africa/Johannesburg',
      'qatar': 'Asia/Qatar',
      'kuwait': 'Asia/Kuwait',
      'oman': 'Asia/Muscat',
      'bahrain': 'Asia/Bahrain',
      'jordan': 'Asia/Amman',
      'lebanon': 'Asia/Beirut',
      'new zealand': 'Pacific/Auckland',
      'france': 'Europe/Paris',
      'germany': 'Europe/Berlin',
      'spain': 'Europe/Madrid',
      'italy': 'Europe/Rome',
      'netherlands': 'Europe/Amsterdam',
      'sweden': 'Europe/Stockholm',
      'norway': 'Europe/Oslo',
      'denmark': 'Europe/Copenhagen',
      'ireland': 'Europe/Dublin',
      'portugal': 'Europe/Lisbon',
      'switzerland': 'Europe/Zurich',
      'austria': 'Europe/Vienna',
      'belgium': 'Europe/Brussels',
    };

    if (commonMapping.containsKey(c)) {
      debugPrint('🔍 Hardcoded mapping used for: "$c" -> ${commonMapping[c]}');
      return commonMapping[c];
    }
    
    debugPrint('🌍 TimezoneService.guessTimezoneFromCountry() input: "$country" -> "$c"');

    if (c.isEmpty) {
      debugPrint('⚠️ Empty country string');
      return null;
    }

    try {
      // Use REST Countries API to get timezone info for a country by name
      // Free service, no API key required
      final url = Uri.https('restcountries.com', '/v3.1/name/$c', {
        'fullText': 'true', // Exact match
      });
      final resp = await http.get(url);
      
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        if (data.isNotEmpty) {
          final countryData = data[0] as Map<String, dynamic>;
          
          // REST Countries API returns timezones as a Map with timezone names as keys
          // e.g. "timezones": ["UTC+00:00", "UTC+01:00"] or as a map {"UTC+00:00": "GMT", ...}
          // We need to find the actual IANA timezone ID
          final timezonesData = countryData['timezones'];
          
          if (timezonesData != null) {
            String? ianaTimezone;
            
            // Try to get IANA timezone from various possible API response formats
            if (timezonesData is List && timezonesData.isNotEmpty) {
              // If it's a list, find the first one that looks like an IANA timezone (e.g., "Asia/Dhaka")
              for (final tz in timezonesData) {
                final tzStr = tz.toString().trim();
                if (tzStr.contains('/')) {
                  ianaTimezone = tzStr;
                  break;
                }
              }
              // If no IANA format found, just use the first one
              if (ianaTimezone == null && timezonesData.isNotEmpty) {
                ianaTimezone = timezonesData[0].toString().trim();
              }
            } else if (timezonesData is Map) {
              // If it's a map, try to extract the first key that has a '/'
              for (final tzKey in timezonesData.keys) {
                final tzStr = tzKey.toString().trim();
                if (tzStr.contains('/')) {
                  ianaTimezone = tzStr;
                  break;
                }
              }
              // Fallback to first key if no IANA format
              if (ianaTimezone == null && timezonesData.isNotEmpty) {
                ianaTimezone = timezonesData.keys.first.toString().trim();
              }
            }
            
            if (ianaTimezone != null && ianaTimezone.isNotEmpty) {
              // Convert "UTC+05:30" or "UTC+05" to "Etc/GMT-5" or manual offset format
              if (ianaTimezone.startsWith('UTC')) {
                final match = RegExp(r"UTC([+-])(\d{1,2})(?::(\d{2}))?").firstMatch(ianaTimezone);
                if (match != null) {
                  final sign = match.group(1);
                  final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
                  final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
                  
                  // If it has minutes, we can't use Etc/GMT easily, so we'll keep the UTC format
                  // and handles it in the provider/TV display manual logic.
                  // But for pure hours, Etc/GMT is better if supported.
                  if (minutes == 0) {
                    final etcSign = sign == '+' ? '-' : '+';
                    ianaTimezone = 'Etc/GMT$etcSign$hours';
                  }
                }
              }

              debugPrint('🔍 REST Countries API lookup: "$c" -> Result: "$ianaTimezone"');
              return ianaTimezone;
            }
          }
        }
      } else if (resp.statusCode == 404) {
        debugPrint('⚠️ Country not found: "$c"');
      }
    } catch (e) {
      debugPrint('⚠️ REST Countries API error: $e');
    }
    
    debugPrint('🔍 Could not determine timezone for: "$c"');
    return null;
  }
}

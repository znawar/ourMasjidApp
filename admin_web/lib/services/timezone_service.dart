import 'dart:convert';
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
        'location': '\$latitude,\$longitude',
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
  static String? guessTimezoneFromCountry(String country) {
    final c = country.trim().toLowerCase();
    const map = {
      'australia': 'Australia/Sydney',
      'usa': 'America/New_York',
      'united states': 'America/New_York',
      'uk': 'Europe/London',
      'united kingdom': 'Europe/London',
      'canada': 'America/Toronto',
      'uae': 'Asia/Dubai',
      'united arab emirates': 'Asia/Dubai',
      'saudi arabia': 'Asia/Riyadh',
      'pakistan': 'Asia/Karachi',
      'india': 'Asia/Kolkata',
      'bangladesh': 'Asia/Dhaka',
      'malaysia': 'Asia/Kuala_Lumpur',
      'singapore': 'Asia/Singapore',
      'indonesia': 'Asia/Jakarta',
      'turkey': 'Europe/Istanbul',
      'egypt': 'Africa/Cairo',
      'south africa': 'Africa/Johannesburg',
      'nigeria': 'Africa/Lagos',
      'kenya': 'Africa/Nairobi',
      'new zealand': 'Pacific/Auckland',
      'france': 'Europe/Paris',
      'germany': 'Europe/Berlin',
      'netherlands': 'Europe/Amsterdam',
      'belgium': 'Europe/Brussels',
      'austria': 'Europe/Vienna',
      'morocco': 'Africa/Casablanca',
    };
    return map[c];
  }
}

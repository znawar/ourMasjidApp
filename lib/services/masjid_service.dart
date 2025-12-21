import 'dart:convert';
import 'package:http/http.dart' as http;

class MasjidService {
  static Future<List<Map<String, dynamic>>> getNearbyMasjids(double lat, double lng) async {
    const double radius = 5000; // 5km radius
    
    final String query = '''
      [out:json];
      (
        node[amenity=place_of_worship][religion=muslim](around:$radius,$lat,$lng);
        way[amenity=place_of_worship][religion=muslim](around:$radius,$lat,$lng);
      );
      out center;
    ''';

    try {
      final response = await http.get(
        Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;
        
        return elements.map((element) {
          return _parseMasjidData(element);
        }).toList();
      } else {
        throw Exception('Failed to load masjids from API');
      }
    } catch (e) {
      print('API Error: $e');
      throw Exception('Failed to connect to masjid database');
    }
  }

  static Map<String, dynamic> _parseMasjidData(Map<String, dynamic> element) {
    final tags = element['tags'] ?? {};
    final lat = element['lat'] ?? (element['center']?['lat'] ?? 0.0);
    final lon = element['lon'] ?? (element['center']?['lon'] ?? 0.0);

    return {
      'id': element['id'].toString(),
      'name': tags['name'] ?? 'Unknown Masjid',
      'address': _getAddress(tags),
      'latitude': lat,
      'longitude': lon,
      'prayerTimes': _getDefaultPrayerTimes(),
      'events': _getSampleEvents(),
      'announcements': _getSampleAnnouncements(),
    };
  }

  static String _getAddress(Map<String, dynamic> tags) {
    final street = tags['addr:street'];
    final city = tags['addr:city'];
    final postcode = tags['addr:postcode'];
    
    if (street != null && city != null) {
      return '$street, $city ${postcode ?? ''}'.trim();
    }
    return tags['addr:full'] ?? 'Address not available';
  }

  static Map<String, dynamic> _getDefaultPrayerTimes() {
    return {
      'fajr': {'adhan': '05:00', 'iqamah': '05:30'},
      'dhuhr': {'adhan': '12:30', 'iqamah': '13:00'},
      'asr': {'adhan': '16:00', 'iqamah': '16:30'},
      'maghrib': {'adhan': '18:30', 'iqamah': '18:35'},
      'isha': {'adhan': '20:00', 'iqamah': '20:30'},
    };
  }

  static List<dynamic> _getSampleEvents() {
    return [
      {
        'title': 'Friday Jumuah',
        'description': 'Weekly Friday prayer',
        'date': 'Every Friday',
        'time': '1:00 PM'
      },
    ];
  }

  static List<dynamic> _getSampleAnnouncements() {
    return [
      {
        'title': 'Welcome',
        'message': 'Welcome to our masjid',
        'date': 'Today',
        'important': false
      },
    ];
  }
} 

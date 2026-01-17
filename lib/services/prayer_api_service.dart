import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class PrayerApiService {
  static const String _baseUrl = 'https://api.aladhan.com/v1';
  
  // Map your dropdown values to Aladhan method numbers
  // Using short codes to match the UI dropdown values
  static final Map<String, int> _calculationMethods = {
    'MWL': 3,                    // Muslim World League
    'ISNA': 2,                   // Islamic Society of North America
    'Egypt': 5,                  // Egyptian General Authority
    'Makkah': 4,                 // Umm al-Qura University, Makkah
    'Karachi': 1,                // University of Islamic Sciences, Karachi
    'Tehran': 7,                 // Institute of Geophysics, University of Tehran
    'Shia': 0,                   // Shia Ithna-Ashari
    'Gulf': 8,                   // Gulf Region
    'Kuwait': 9,                 // Kuwait
    'Qatar': 10,                 // Qatar
    'Singapore': 11,             // Majlis Ugama Islam Singapura
    'France': 12,                // Union Organization islamic de France
    'Turkey': 13,                // Diyanet İşleri Başkanlığı
    'Russia': 14,                // Spiritual Administration of Muslims
    'Moonsighting': 15,          // Moonsighting Committee Worldwide
    'Custom': 3,                 // Default to MWL for custom
  };

  // Get prayer times by city
  static Future<Map<String, dynamic>> getPrayerTimesByCity({
    required String city,
    required String country,
    required String method,
    String school = 'Shafi', // Shafi or Hanafi
    String adjustmentMethod = 'AngleBased',
    int adjustment = 0,
    DateTime? date,
  }) async {
    try {
      final methodNumber = _calculationMethods[method] ?? 3;
      final schoolNumber = school == 'Hanafi' ? 1 : 0;
      final calcDate = date ?? DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(calcDate);
      
      final url = Uri.parse(
        '$_baseUrl/timingsByCity/$dateStr?'
        'city=${Uri.encodeComponent(city)}&'
        'country=${Uri.encodeComponent(country)}&'
        'method=$methodNumber&'
        'school=$schoolNumber&'
        'latitudeAdjustmentMethod=$adjustmentMethod&'
        'adjustment=$adjustment'
      );


      print('AlAdhan API Call: $url'); // Debug

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 200) {
          final timings = data['data']['timings'];
          final meta = data['data']['meta'];
          
          return {
            'timings': {
              'Fajr': timings['Fajr'] ?? '05:00',
              'Sunrise': timings['Sunrise'] ?? '06:00',
              'Dhuhr': timings['Dhuhr'] ?? '12:00',
              'Asr': timings['Asr'] ?? '15:00',
              'Maghrib': timings['Maghrib'] ?? '18:00',
              'Isha': timings['Isha'] ?? '19:00',
              'Imsak': timings['Imsak'] ?? '04:50',
              'Midnight': timings['Midnight'] ?? '00:00',
            },
            'timezone': meta['timezone']?.toString(),
          };
        } else {
          print('AlAdhan API responded with non-success code: ${data['code']} body: ${response.body}');
          return {'timings': getDefaultPrayerTimes()};
        }
      } else {
        print('AlAdhan HTTP Error: ${response.statusCode} body: ${response.body}');
        return {'timings': getDefaultPrayerTimes()};
      }
    } on TimeoutException catch (e) {
      print('AlAdhan API Timeout: $e');
      return {'timings': getDefaultPrayerTimes()};
    } catch (e) {
      print('AlAdhan API Error: $e');
      return {'timings': getDefaultPrayerTimes()};
    }
  }

  // Get prayer times by coordinates (more accurate)
  static Future<Map<String, dynamic>> getPrayerTimesByCoordinates({
    required double latitude,
    required double longitude,
    required String method,
    String school = 'Shafi',
    String adjustmentMethod = 'AngleBased',
    int adjustment = 0,
    DateTime? date,
  }) async {
    try {
      final methodNumber = _calculationMethods[method] ?? 3;
      final schoolNumber = school == 'Hanafi' ? 1 : 0;
      final calcDate = date ?? DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(calcDate);
      
      final url = Uri.parse(
        '$_baseUrl/timings/$dateStr?'
        'latitude=$latitude&'
        'longitude=$longitude&'
        'method=$methodNumber&'
        'school=$schoolNumber&'
        'latitudeAdjustmentMethod=$adjustmentMethod&'
        'adjustment=$adjustment'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200) {
          final timings = data['data']['timings'];
          final meta = data['data']['meta'];

          return {
            'timings': {
              'Fajr': timings['Fajr'] ?? '05:00',
              'Sunrise': timings['Sunrise'] ?? '06:00',
              'Dhuhr': timings['Dhuhr'] ?? '12:00',
              'Asr': timings['Asr'] ?? '15:00',
              'Maghrib': timings['Maghrib'] ?? '18:00',
              'Isha': timings['Isha'] ?? '19:00',
              'Imsak': timings['Imsak'] ?? '04:50',
              'Midnight': timings['Midnight'] ?? '00:00',
            },
            'timezone': meta['timezone']?.toString(),
          };
        } else {
          print('AlAdhan API responded with non-success code: ${data['code']} body: ${response.body}');
          return {'timings': getDefaultPrayerTimes()};
        }
      } else {
        print('AlAdhan HTTP Error: ${response.statusCode} body: ${response.body}');
        return {'timings': getDefaultPrayerTimes()};
      }
    } on TimeoutException catch (e) {
      print('AlAdhan API Timeout: $e');
      return {'timings': getDefaultPrayerTimes()};
    } catch (e) {
      print('AlAdhan API Error: $e');
      return {'timings': getDefaultPrayerTimes()};
    }
  }

  // Get calculation methods for dropdown
  static List<String> getCalculationMethods() {
    return _calculationMethods.keys.toList();
  }

  // Get default prayer times
  static Map<String, String> getDefaultPrayerTimes() {
    return {
      'Fajr': '05:00',
      'Sunrise': '06:30',
      'Dhuhr': '12:30',
      'Asr': '15:45',
      'Maghrib': '18:30',
      'Isha': '20:00',
      'Imsak': '04:50',
      'Midnight': '00:00',
    };
  }

  // Convert 12-hour to 24-hour format
  static String convertTo24Hour(String time12hr) {
    try {
      final timeParts = time12hr.split(' ');
      if (timeParts.length == 2) {
        final time = timeParts[0];
        final period = timeParts[1].toUpperCase();
        final parts = time.split(':');
        
        if (parts.length == 2) {
          int hour = int.parse(parts[0]);
          final minute = parts[1];
          
          if (period == 'PM' && hour != 12) {
            hour += 12;
          } else if (period == 'AM' && hour == 12) {
            hour = 0;
          }
          
          return '${hour.toString().padLeft(2, '0')}:$minute';
        }
      }
      return time12hr;
    } catch (e) {
      return time12hr;
    }
  }

  // Calculate iqamah time based on adhan and delay
  static String calculateIqamah(String adhanTime, int delayMinutes) {
    try {
      final parts = adhanTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      var time = DateTime(2024, 1, 1, hour, minute);
      time = time.add(Duration(minutes: delayMinutes));
      
      return '${time.hour.toString().padLeft(2, '0')}:'
             '${time.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return adhanTime;
    }
  }
}
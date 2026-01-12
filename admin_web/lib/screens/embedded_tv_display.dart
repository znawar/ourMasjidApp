import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:http/http.dart' as http;
import 'tv_connection_screen.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_times_provider.dart';
import '../services/timezone_service.dart';

class Wakelock {
  static Future<void> enable() async {}
  static Future<void> disable() async {}
}

class TVDisplayScreen extends StatefulWidget {
  final String? masjidId;
  final List<Map<String, String>>? announcements;
  final Map<String, Map<String, String>>? prayerTimes;

  const TVDisplayScreen({
    super.key,
    this.masjidId,
    this.announcements,
    this.prayerTimes,
  });

  @override
  State<TVDisplayScreen> createState() => _TVDisplayScreenState();
}

String _getHijriDate(DateTime gregorianDate) {
  final DateTime referenceDate = DateTime(2025, 10, 31);
  const int referenceHijriDay = 9;
  const int referenceHijriMonth = 5;
  const int referenceHijriYear = 1447;

  final int daysDifference = gregorianDate.difference(referenceDate).inDays;

  int hijriDay = referenceHijriDay + daysDifference;
  int hijriMonth = referenceHijriMonth;
  int hijriYear = referenceHijriYear;

  final Map<int, List<int>> hijriYearLengths = {
    1446: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29],
    1447: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29],
    1448: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 30],
  };

  List<int> currentYearLengths = hijriYearLengths[hijriYear] ??
      [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];

  while (hijriDay > currentYearLengths[hijriMonth - 1]) {
    hijriDay -= currentYearLengths[hijriMonth - 1];
    hijriMonth++;

    if (hijriMonth > 12) {
      hijriMonth = 1;
      hijriYear++;
      currentYearLengths = hijriYearLengths[hijriYear] ??
          [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
    }
  }

  while (hijriDay < 1) {
    hijriMonth--;
    if (hijriMonth < 1) {
      hijriMonth = 12;
      hijriYear--;
      currentYearLengths = hijriYearLengths[hijriYear] ??
          [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
    }
    hijriDay += currentYearLengths[hijriMonth - 1];
  }

  final List<String> hijriMonths = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Ula',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah'
  ];

  return '$hijriDay ${hijriMonths[hijriMonth - 1]} $hijriYear AH';
}

class _TVDisplayScreenState extends State<TVDisplayScreen> {
  Timer? _timer;
  DateTime now = DateTime.now();
  String nextPrayerName = '';
  String currentPrayerName = '';
  Duration nextPrayerCountdown = Duration.zero;
  Duration iqamahCountdown = Duration.zero;
  bool isAdhanTime = false;
  bool isIqamahTime = false;
  bool showIqamahStarted = false;
  Timer? _iqamahTimer;

  // Firebase data
  List<Map<String, dynamic>> firebaseAnnouncements = [];
  Map<String, dynamic> firebasePrayerTimes = {};
  Map<String, Map<String, String>> _currentPrayerTimes = {};
  bool isLoadingFirebase = true;

  String? _masjidName;
  bool _announcementsUsingFallback = false;

  // Location data
  double? _masjidLatitude;
  double? _masjidLongitude;
  String? _masjidCity;
  String? _masjidCountry;
  String? _calculationMethod;
  
  // Timezone
  String? _timezoneName;
  DateTime? _masjidLocalTime;
  bool _timezoneResolved = false;
  
  // Masjid-local time derived from timezone; no external time API needed

  late FirebaseFirestore firestore;
  StreamSubscription? _announcementsSub;
  StreamSubscription? _prayerTimesSub;
  StreamSubscription? _pairingDocSub;

  static const String _tvMasjidIdStorageKey = 'tvMasjidId';
  static const String _tvPairingCodeStorageKey = 'tvPairingCode';

  String? _resolvedMasjidId;

  @override
  void initState() {
    super.initState();
    Wakelock.enable().catchError((e) {});
    
    // Initialize timezone database
    tz_data.initializeTimeZones();

    _resolvedMasjidId = (widget.masjidId?.trim().isNotEmpty ?? false)
        ? widget.masjidId!.trim()
        : null;

    _initializeFirebase();

    // Initialize current time using this screen's own timezone logic.
    // As soon as a concrete timezone (e.g. "Australia/Adelaide") is
    // resolved from Firestore/coordinates, _updateLocalTime will use
    // it so the clock and timers are locked to the masjid location,
    // not the device/browser timezone.
    _updateLocalTime();
    now = _masjidLocalTime ?? DateTime.now();

    _startClock();
    _calculateNextPrayer();
    _checkCurrentPrayerTimes();
  }

  Future<void> _initializeFirebase() async {
    try {
      firestore = FirebaseFirestore.instance;

      // Always check stored prefs for pairing data so we can listen for deletion
      final prefs = await SharedPreferences.getInstance();
      final saved = (prefs.getString(_tvMasjidIdStorageKey) ?? '').trim();
      final savedPairCode = (prefs.getString(_tvPairingCodeStorageKey) ?? '').trim();

      if (_resolvedMasjidId == null && saved.isNotEmpty) {
        _resolvedMasjidId = saved;
      }

      if (savedPairCode.isNotEmpty) {
        _listenToPairingDoc(savedPairCode);
      }

      _listenToAnnouncements();
      _listenToPrayerTimes();
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  void _listenToPairingDoc(String code) {
    _pairingDocSub?.cancel();
    final ref = FirebaseFirestore.instance.collection('tv_pairs').doc(code);
    _pairingDocSub = ref.snapshots().listen((doc) async {
      // If doc is deleted or unclaimed / masjidId mismatch, disconnect
      if (!mounted) return;
      final data = doc.data();
      if (data == null) {
        await _disconnectTv();
        return;
      }

      final masjidId = (data['masjidId'] ?? '').toString().trim();
      final claimed = data['claimed'] == true;
      if (!claimed || masjidId.isEmpty || (masjidId != _resolvedMasjidId)) {
        await _disconnectTv();
      }
    }, onError: (_) async {
      await _disconnectTv();
    });
  }

  Future<void> _disconnectTv() async {
    // Clear saved pairing and masjid id so TV goes back to pairing screen
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tvMasjidIdStorageKey);
      await prefs.remove(_tvPairingCodeStorageKey);
    } catch (_) {}

    // Cancel listeners and navigate back to pairing flow
    _announcementsSub?.cancel();
    _prayerTimesSub?.cancel();
    _pairingDocSub?.cancel();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TVConnectionScreen()),
    );
  }

  void _listenToAnnouncements() {
    _announcementsSub?.cancel();

    final String? masjidId = _resolvedMasjidId;
    _announcementsUsingFallback = false;

    // Query by masjidId first, then filter active in-memory to avoid compound index requirement
    Query<Map<String, dynamic>> query = firestore.collection('announcements');

    if (masjidId != null && masjidId.trim().isNotEmpty) {
      query = query.where('masjidId', isEqualTo: masjidId.trim());
    }

    _announcementsSub = query.snapshots().listen((snapshot) {
      final announcements = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Filter active announcements in-memory
        if (data['active'] == true) {
          announcements.add(data);
        }
      }

      if (announcements.isEmpty &&
          !_announcementsUsingFallback &&
          masjidId != null &&
          masjidId.trim().isNotEmpty) {
        // No announcements for this masjid - just show empty state, don't fall back to all announcements
        _announcementsUsingFallback = true;
        if (!mounted) return;
        setState(() {
          firebaseAnnouncements = [];
          isLoadingFirebase = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        firebaseAnnouncements = announcements;
        isLoadingFirebase = false;
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() {
        isLoadingFirebase = false;
      });
    });
  }

  void _listenToPrayerTimes() {
    _prayerTimesSub?.cancel();

    final String? masjidId = _resolvedMasjidId;
    if (masjidId != null && masjidId.trim().isNotEmpty) {
      _prayerTimesSub = firestore
          .collection('masjids')
          .doc(masjidId)
          .snapshots()
          .listen((doc) async {
        final data = doc.data();
        if (data == null) return;
        
        print('=== PRAYER TIMES DATA FROM FIREBASE ===');
        print('Full data: $data');
        
        setState(() {
          firebasePrayerTimes = data;
          final name =
              (data['masjidName'] ?? data['name'] ?? '').toString().trim();
          _masjidName = name.isEmpty ? _masjidName : name;
          _currentPrayerTimes = _extractPrayerTimes(data);
          
          // Extract location data
          _extractLocationData(data);
          
          print('Extracted prayer times: $_currentPrayerTimes');
          print('Location: $_masjidCity, $_masjidCountry');
          
          isLoadingFirebase = false;
          _calculateNextPrayer();
          _checkCurrentPrayerTimes();
        });

        // Resolve timezone from city/country - don't block on it
        if (!_timezoneResolved && _masjidCity != null && _masjidCountry != null) {
          await _resolveTimezoneFromCityCountry();
        }
      });
      return;
    }

    _prayerTimesSub =
        firestore.collection('masjids').limit(1).snapshots().listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
      final doc = snapshot.docs.first;
      final data = doc.data();
      
      print('=== PRAYER TIMES DATA (FALLBACK) ===');
      print('Full data: $data');
      
      setState(() {
        firebasePrayerTimes = data;
        final name =
            (data['masjidName'] ?? data['name'] ?? '').toString().trim();
        _masjidName = name.isEmpty ? _masjidName : name;
        _currentPrayerTimes = _extractPrayerTimes(data);
        
        // Extract location data
        _extractLocationData(data);
        
        print('Extracted prayer times: $_currentPrayerTimes');
        print('Location: $_masjidCity, $_masjidCountry');
        
        isLoadingFirebase = false;
        _calculateNextPrayer();
        _checkCurrentPrayerTimes();
        
        // Resolve timezone from city/country
        if (!_timezoneResolved && _masjidCity != null && _masjidCountry != null) {
          _resolveTimezoneFromCityCountry();
        }
      });
    });
  }

  void _extractLocationData(Map<String, dynamic> data) {
    try {
      // Check for location in various possible structures
      if (data['location'] is Map) {
        final location = data['location'] as Map;
        _masjidCity = location['city']?.toString() ?? '';
        _masjidCountry = location['country']?.toString() ?? '';
        _masjidLatitude = (location['latitude'] is num) 
            ? (location['latitude'] as num).toDouble() 
            : null;
        _masjidLongitude = (location['longitude'] is num) 
            ? (location['longitude'] as num).toDouble() 
            : null;
        
        // Extract calculation method
        final method = location['calculationMethod']?.toString() ?? data['calculationMethod']?.toString() ?? '';
        if (method.isNotEmpty) {
          _calculationMethod = method;
        }
        
        // If a concrete timezone is stored in the document, use it immediately.
        // Ignore placeholder values like 'Auto' so we can resolve from lat/lng.
        final tzField = location['timezone'] ?? location['timeZone'] ?? location['tz'];
        if (tzField is String) {
          final tzStr = tzField.trim();
          if (tzStr.isNotEmpty && tzStr.toLowerCase() != 'auto') {
            _timezoneName = tzStr;
            _timezoneResolved = true;
            // Update local time now that we have a real timezone
            _updateLocalTime();
            print('Using stored timezone from document: $_timezoneName');
          }
        }
      }
      
      // Also check direct fields
      if ((_masjidCity == null || _masjidCity!.isEmpty) && data['city'] != null) {
        _masjidCity = data['city']?.toString() ?? '';
      }
      if ((_masjidCountry == null || _masjidCountry!.isEmpty) && data['country'] != null) {
        _masjidCountry = data['country']?.toString() ?? '';
      }
      
      print('Extracted location: $_masjidCity, $_masjidCountry');
      print('Calculation method: $_calculationMethod');
    } catch (e) {
      print('Error extracting location data: $e');
    }
  }

  Future<void> _resolveTimezoneFromCityCountry() async {
    // We require at least *some* location hint: city/country or coordinates.
    final hasCityOrCountry =
        (_masjidCity != null && _masjidCity!.trim().isNotEmpty) ||
        (_masjidCountry != null && _masjidCountry!.trim().isNotEmpty);
    final hasCoords = _masjidLatitude != null && _masjidLongitude != null;

    if (!hasCityOrCountry && !hasCoords) {
      return;
    }

    if (_timezoneResolved) return;

    try {
      String? tzId;

      // 1) Prefer coordinate-based lookup when we have lat/lng; this
      // gives us the exact city timezone (including Adelaide, etc.).
      if (hasCoords) {
        tzId = await _getTimezoneFromLatLng(_masjidLatitude!, _masjidLongitude!);
      }

      // 2) If that failed, try a simple city/country map with
      // explicit entries for common cities.
      if ((tzId == null || tzId.isEmpty) && hasCityOrCountry) {
        final city = _masjidCity?.trim() ?? '';
        final country = _masjidCountry?.trim() ?? '';
        tzId = _getSimpleTimezoneFromCityCountry(city, country);
      }

      // 3) As a last resort, fall back to a country-level guess.
      if ((tzId == null || tzId.isEmpty) && _masjidCountry != null && _masjidCountry!.trim().isNotEmpty) {
        tzId = TimezoneService.guessTimezoneFromCountry(_masjidCountry!.trim());
      }

      if (tzId != null && tzId.isNotEmpty) {
        _timezoneName = tzId;
        _timezoneResolved = true;
        print('Resolved timezone for TV display: $_timezoneName');
        _updateLocalTime();
        if (mounted) {
          setState(() {
            now = _masjidLocalTime ?? DateTime.now();
          });
        }
        return;
      }

      // If everything failed, fall back to device time but keep the flag
      // so we don't loop endlessly.
      _timezoneName = 'Device Time';
      _timezoneResolved = true;
      _updateLocalTime();
      if (mounted) {
        setState(() {
          now = _masjidLocalTime ?? DateTime.now();
        });
      }
    } catch (e) {
      print('Error resolving timezone: $e');
      _timezoneName = 'Device Time';
      _timezoneResolved = true;
      _updateLocalTime();
      if (mounted) {
        setState(() {
          now = _masjidLocalTime ?? DateTime.now();
        });
      }
    }
  }

  // Unused method - timezone is now handled via timezone_service and location data
  /* 
  Future<String?> _getTimezoneFromAPI(String city, String country) async {
    try {
      // Using TimezoneDB API (you need to sign up for a free API key)
      const apiKey = 'YOUR_TIMEZONEDB_API_KEY'; // Get from https://timezonedb.com/api
      final encodedCity = Uri.encodeComponent(city);
      final encodedCountry = Uri.encodeComponent(country);
      
      final response = await http.get(
        Uri.parse('http://api.timezonedb.com/v2.1/get-time-zone?key=$apiKey&format=json&by=city&city=$encodedCity&country=$encodedCountry')
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data['zoneName'];
        }
      }
      
      // If TimezoneDB fails, try Geonames API (alternative)
      const geonamesUsername = 'YOUR_GEONAMES_USERNAME'; // Get from http://www.geonames.org
      final geonamesResponse = await http.get(
        Uri.parse('http://api.geonames.org/timezoneJSON?formatted=true&lat=0&lng=0&username=$geonamesUsername&style=full')
      );
      
      if (geonamesResponse.statusCode == 200) {
        final geonamesData = json.decode(geonamesResponse.body);
        if (geonamesData['timezoneId'] != null) {
          return geonamesData['timezoneId'];
        }
      }
      
      return null;
    } catch (e) {
      print('API timezone error: $e');
      return null;
    }
  }
  */

  Future<String?> _getTimezoneFromLatLng(double lat, double lng) async {
    try {
      // Try timeapi.io which provides timezone by coordinates without an API key
      final url = 'https://timeapi.io/api/TimeZone/coordinate?latitude=$lat&longitude=$lng';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(resp.body);
        // timeapi.io returns 'timeZone' or 'timeZoneId' depending on version
        if (data['timeZone'] is String && (data['timeZone'] as String).isNotEmpty) {
          return data['timeZone'] as String;
        }
        if (data['timeZoneName'] is String && (data['timeZoneName'] as String).isNotEmpty) {
          return data['timeZoneName'] as String;
        }
        if (data['timeZoneId'] is String && (data['timeZoneId'] as String).isNotEmpty) {
          return data['timeZoneId'] as String;
        }
      }
    } catch (e) {
      print('Lat/Lng timezone lookup failed: $e');
    }
    return null;
  }

  String _getSimpleTimezoneFromCityCountry(String city, String country) {
    // Simple fallback for common cities
    final cityLower = city.toLowerCase();
    const timezoneMap = {
      
      'sydney': 'Australia/Sydney',
      'adelaide': 'Australia/Adelaide',
      'riyadh': 'Asia/Riyadh',
      'jeddah': 'Asia/Riyadh',
      'dubai': 'Asia/Dubai',
      'abu dhabi': 'Asia/Dubai',
      'karachi': 'Asia/Karachi',
      'lahore': 'Asia/Karachi',
      'delhi': 'Asia/Kolkata',
      'mumbai': 'Asia/Kolkata',
      'dhaka': 'Asia/Dhaka',
      'istanbul': 'Europe/Istanbul',
      'cairo': 'Africa/Cairo',
      'jakarta': 'Asia/Jakarta',
      'kuala lumpur': 'Asia/Kuala_Lumpur',
      'london': 'Europe/London',
      'new york': 'America/New_York',
      'los angeles': 'America/Los_Angeles',
      'chicago': 'America/Chicago',
    };
    
    if (timezoneMap.containsKey(cityLower)) {
      return timezoneMap[cityLower]!;
    }
    
    // Default to UTC
    return 'UTC';
  }

  void _updateLocalTime() {
    try {
      if (_timezoneName == null || _timezoneName!.isEmpty || _timezoneName == 'Device Time') {
        _masjidLocalTime = DateTime.now();
        return;
      }

      // Use timezone package to compute masjid-local time. This handles
      // DST and city-level differences for the stored IANA timezone.
      try {
        final location = tz.getLocation(_timezoneName!);
        _masjidLocalTime = tz.TZDateTime.now(location);
        print('TV local time update -> tz: $_timezoneName, masjidLocal: $_masjidLocalTime, device: ${DateTime.now()}');
      } catch (e) {
        print('Unknown timezone "$_timezoneName" – falling back to device time: $e');
        _masjidLocalTime = DateTime.now();
      }
    } catch (e) {
      print('Error updating local time: $e');
      _masjidLocalTime = DateTime.now();
    }
  }

  Map<String, Map<String, String>> _extractPrayerTimes(
      Map<String, dynamic> data) {
    final result = <String, Map<String, String>>{};

    // First, try to get the prayer times structure
    final dynamic raw =
        data['prayerTimes'] ?? data['prayer_times'] ?? data['times'];

    // Default prayer order
    const defaultPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is! String) return;
        if (value is Map) {
          final adhan = (value['adhan'] ?? value['azan'] ?? value['startTime'] ?? '').toString();
          final iqamah = (value['iqamah'] ?? value['iqama'] ?? value['congregationTime'] ?? '').toString();
          
          // Also check for delay-based iqamah calculation
          final delay = value['delay'] is int ? value['delay'] : (int.tryParse(value['delay']?.toString() ?? '0') ?? 0);
          
          String finalIqamah = iqamah;
          
          // If iqamah is empty but delay exists, calculate iqamah
          if (finalIqamah.isEmpty && delay > 0 && adhan.isNotEmpty) {
            try {
              // Always base this on the masjid-local clock used by the TV
              final base = _masjidLocalTime ?? DateTime.now();
              final adhanTime = _parseTimeToDateTime(adhan, base);
              if (adhanTime != null) {
                final iqamahTime = adhanTime.add(Duration(minutes: delay));
                finalIqamah = DateFormat('HH:mm').format(iqamahTime);
              }
            } catch (e) {
              print('Error calculating iqamah from delay: $e');
            }
          }
          
          result[key] = {
            'adhan': adhan,
            'iqamah': finalIqamah,
          };
        }
      });
      return result;
    }

    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final name = item['name']?.toString() ?? '';
        if (name.isEmpty) continue;
        final adhan = item['adhan']?.toString() ?? 
                      item['azan']?.toString() ?? 
                      item['startTime']?.toString() ?? '';
        final iqamah = item['iqamah']?.toString() ?? 
                       item['iqama']?.toString() ?? 
                       item['congregationTime']?.toString() ?? '';
        
        // Check for delay-based iqamah
        final delay = item['delay'] is int
            ? item['delay']
            : (int.tryParse(item['delay']?.toString() ?? '0') ?? 0);
        String finalIqamah = iqamah;

        if (finalIqamah.isEmpty && delay > 0 && adhan.isNotEmpty) {
          try {
            final base = _masjidLocalTime ?? DateTime.now();
            final adhanTime = _parseTimeToDateTime(adhan, base);
            if (adhanTime != null) {
              final iqamahTime = adhanTime.add(Duration(minutes: delay));
              finalIqamah = DateFormat('HH:mm').format(iqamahTime);
            }
          } catch (e) {
            print('Error calculating iqamah from delay: $e');
          }
        }
        
        result[name] = {
          'adhan': adhan,
          'iqamah': finalIqamah,
        };
      }
    }

    // If we still don't have data, try to extract from the iqamahUseDelay structure
    if (result.isEmpty) {
      try {
        // Look for iqamahUseDelay map
        final iqamahUseDelay = data['iqamahUseDelay'];
        if (iqamahUseDelay is Map) {
          for (final prayer in defaultPrayers) {
            final prayerTimes = data['prayerTimes'];
            String adhan = '';
            int delay = 0;
            
            if (prayerTimes is Map && prayerTimes[prayer] is Map) {
              final prayerData = prayerTimes[prayer] as Map;
              adhan = prayerData['adhan']?.toString() ?? 
                      prayerData['startTime']?.toString() ?? '';
              delay = prayerData['delay'] is int 
                  ? prayerData['delay'] 
                  : (int.tryParse(prayerData['delay']?.toString() ?? '0') ?? 0);
            }
            
            // Check if using delay or fixed time
            final useDelay = iqamahUseDelay[prayer] == true;

            String iqamah = '';
            if (useDelay) {
              if (adhan.isNotEmpty && delay > 0) {
                try {
                  final base = _masjidLocalTime ?? DateTime.now();
                  final adhanTime = _parseTimeToDateTime(adhan, base);
                  if (adhanTime != null) {
                    final iqamahTime = adhanTime.add(Duration(minutes: delay));
                    iqamah = DateFormat('HH:mm').format(iqamahTime);
                  }
                } catch (e) {
                  print('Error calculating iqamah from delay for $prayer: $e');
                }
              }
            } else {
              // Look for fixed iqamah time
              if (prayerTimes is Map && prayerTimes[prayer] is Map) {
                final prayerData = prayerTimes[prayer] as Map;
                iqamah = prayerData['iqamah']?.toString() ?? 
                         prayerData['congregationTime']?.toString() ?? '';
              }
            }
            
            result[prayer] = {
              'adhan': adhan,
              'iqamah': iqamah,
            };
          }
        }
      } catch (e) {
        print('Error extracting iqamahUseDelay data: $e');
      }
    }

    // If still empty, create default structure
    if (result.isEmpty) {
      for (final prayer in defaultPrayers) {
        result[prayer] = {
          'adhan': '--:--',
          'iqamah': '--:--',
        };
      }
    }

    return result;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _iqamahTimer?.cancel();
    Wakelock.disable();
    _announcementsSub?.cancel();
    _prayerTimesSub?.cancel();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Always drive the TV clock from the masjid-local timezone
      // resolved on this screen, completely independent of the
      // device/browser timezone.
      _updateLocalTime();
      final DateTime newNow = _masjidLocalTime ?? DateTime.now();

      setState(() {
        now = newNow;
        _calculateNextPrayer();
        _checkCurrentPrayerTimes();
      });
    });
  }

  void _checkCurrentPrayerTimes() {
    final source = _currentPrayerTimes.isNotEmpty
        ? _currentPrayerTimes
        : (widget.prayerTimes ?? const {});

    // Reset states
    isAdhanTime = false;
    isIqamahTime = false;
    currentPrayerName = '';
    iqamahCountdown = Duration.zero;
    showIqamahStarted = false;

    if (source.isEmpty) return;

    // Determine the current prayer as the latest adhan that has occurred
    // (including yesterday's times for after-midnight cases).
    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    DateTime? latestAdhan;
    String? latestPrayerName;

    for (final prayer in prayerOrder) {
      final entry = source.entries.firstWhere(
        (e) => e.key.toLowerCase() == prayer.toLowerCase(),
        orElse: () => MapEntry('', const {}),
      );
      if (entry.key.isEmpty) continue;

      final adhanStr = (entry.value['adhan'] ?? '').toString();
      final todayAdhan = _parseTimeToDateTime(adhanStr, now);
      if (todayAdhan == null) continue;

      // Today
      if (!todayAdhan.isAfter(now)) {
        if (latestAdhan == null || todayAdhan.isAfter(latestAdhan)) {
          latestAdhan = todayAdhan;
          latestPrayerName = prayer;
        }
      }

      // Yesterday (for after-midnight periods before Fajr)
      final yesterdayAdhan = todayAdhan.subtract(const Duration(days: 1));
      if (!yesterdayAdhan.isAfter(now)) {
        if (latestAdhan == null || yesterdayAdhan.isAfter(latestAdhan)) {
          latestAdhan = yesterdayAdhan;
          latestPrayerName = prayer;
        }
      }
    }

    if (latestAdhan == null || latestPrayerName == null) {
      return;
    }

    // Handle iqamah status/countdown for the current prayer
    final entry = source.entries.firstWhere(
      (e) => latestPrayerName != null && e.key.toLowerCase() == latestPrayerName.toLowerCase(),
      orElse: () => MapEntry('', const {}),
    );

    if (entry.key.isEmpty) return;

    final iqamahStr = (entry.value['iqamah'] ?? '').toString();
    DateTime? iqamahTime;
    if (iqamahStr.isNotEmpty && iqamahStr != '--:--') {
      iqamahTime = _parseTimeToDateTime(iqamahStr, latestAdhan);
    }

  
    final DateTime windowStart = latestAdhan;
    final DateTime windowEnd;
    if (iqamahTime != null && !iqamahTime.isBefore(windowStart)) {
      windowEnd = iqamahTime.add(const Duration(minutes: 20));
    } else {
      windowEnd = windowStart.add(const Duration(minutes: 30));
    }

    // If we're outside the active window, do not show any
    // "current prayer in progress" state.
    if (now.isBefore(windowStart) || now.isAfter(windowEnd)) {
      _iqamahTimer?.cancel();
      return;
    }

    currentPrayerName = latestPrayerName;

    // No iqamah configured: treat the whole window as generic adhan time.
    if (iqamahTime == null || iqamahStr.isEmpty || iqamahStr == '--:--') {
      isAdhanTime = true;
      isIqamahTime = false;
      showIqamahStarted = false;
      iqamahCountdown = Duration.zero;
      _iqamahTimer?.cancel();
      return;
    }

    if (now.isBefore(iqamahTime)) {
      // Between adhan and iqamah – show countdown
      isAdhanTime = true;
      iqamahCountdown = iqamahTime.difference(now);
      isIqamahTime = false;
      showIqamahStarted = false;
      _iqamahTimer?.cancel();
    } else {
      // At or after iqamah, but still within the prayer window
      isAdhanTime = true;
      isIqamahTime = true;
      final iqamahEndTime = iqamahTime.add(const Duration(minutes: 20));
      if (now.isBefore(iqamahEndTime)) {
        showIqamahStarted = true;
        iqamahCountdown = Duration.zero;

        _iqamahTimer?.cancel();
        _iqamahTimer = Timer(iqamahEndTime.difference(now), () {
          if (mounted) {
            setState(() {
              showIqamahStarted = false;
              isIqamahTime = false;
              isAdhanTime = false;
            });
          }
        });
      } else {
        // Safety fallback; normally covered by windowEnd check above.
        showIqamahStarted = false;
        isIqamahTime = false;
        isAdhanTime = false;
      }
    }
  }

  void _calculateNextPrayer() {
    // Always base "next prayer" purely on the same `now`
    // value that is shown on the digital clock so the
    // countdown and the clock stay perfectly in sync.
    final DateTime base = now;
    DateTime? nextTime;
    String? nextName;

    // Only consider the 5 main prayers in canonical order,
    // to match the admin dashboard logic.
    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    final source = _currentPrayerTimes.isNotEmpty
        ? _currentPrayerTimes
        : (widget.prayerTimes ?? const {});

    for (final prayer in prayerOrder) {
      // Find this prayer in the source map case-insensitively
      final entry = source.entries.firstWhere(
        (e) => e.key.toLowerCase() == prayer.toLowerCase(),
        orElse: () => MapEntry('', const {}),
      );

      if (entry.key.isEmpty) continue;

      final adhan = (entry.value['adhan'] ?? '--:--').toString().trim();
      final parsed = _parseTimeToDateTime(adhan, base);
      if (parsed == null) continue;

      var candidate = parsed;
      // If today's adhan time has already passed in masjid-local
      // time, treat the "next" occurrence as tomorrow.
      if (!candidate.isAfter(base)) {
        candidate = candidate.add(const Duration(days: 1));
      }

      if (nextTime == null || candidate.isBefore(nextTime)) {
        nextTime = candidate;
        nextName = prayer;
      }
    }

    if (nextTime != null && nextName != null) {
      nextPrayerName = nextName;
      nextPrayerCountdown = nextTime.difference(base);
    } else {
      // If we couldn't determine a valid next prayer (e.g. bad data),
      // reset the display instead of leaving a stale countdown.
      nextPrayerName = '';
      nextPrayerCountdown = Duration.zero;
    }
  }

  DateTime? _parseTimeToDateTime(String input, DateTime base) {
    final value = input.trim();
    if (value.isEmpty || value == '--' || value == '--:--') return null;

    DateTime? parsed;
    for (final fmt in [
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
      DateFormat('h:mm a'),
      DateFormat('h:mm a'),
    ]) {
      try {
        parsed = fmt.parseStrict(value);
        break;
      } catch (_) {}
    }

    int hour = -1;
    int minute = -1;

    if (parsed != null) {
      hour = parsed.hour;
      minute = parsed.minute;
    } else {
      if (!value.contains(':')) return null;
      final parts = value.split(':');
      if (parts.length < 2) return null;
      hour = int.tryParse(parts[0]) ?? -1;
      minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;
    }

    if (hour < 0 || minute < 0 || hour > 23 || minute > 59) return null;

    // Create a naive DateTime first
    final naiveDt = DateTime(base.year, base.month, base.day, hour, minute);

    // If we have a resolved timezone for the masjid, create a TZDateTime in that timezone
    // so comparisons with _masjidLocalTime (also a TZDateTime) work correctly.
    if (_timezoneName != null && _timezoneName!.isNotEmpty && _timezoneName != 'Device Time') {
      try {
        final location = tz.getLocation(_timezoneName!);
        // Create a TZDateTime in the masjid's timezone using the naive time as-is
        return tz.TZDateTime(location, naiveDt.year, naiveDt.month, naiveDt.day, naiveDt.hour, naiveDt.minute);
      } catch (e) {
        print('Error creating TZDateTime for prayer time: $e');
      }
    }

    // Fallback: return naive DateTime (less accurate for timezone mismatches)
    return naiveDt;
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  bool _isRamadanModeEnabled() {
    try {
      final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
      final st = provider.prayerSettings?.specialTimes;
      if (st != null) {
        return st.ramadanModeEnabled;
      }
    } catch (_) {
      // fall back to raw firebase map if available
      final specialTimes = firebasePrayerTimes['specialTimes'];
      if (specialTimes is Map) {
        return specialTimes['ramadanModeEnabled'] == true;
      }
    }
    return false;
  }

  String _getSuhoorEndTime() {
    try {
      final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
      final st = provider.prayerSettings?.specialTimes;
      
      // If manual mode is enabled, return the manually set time
      if (st?.useManualRamadanTimes == true) {
        final time = st?.suhoorEndTime;
        if (time != null && time.isNotEmpty) {
          return time;
        }
      }
      
      // Otherwise, calculate from Fajr + Imsak offset
      final fajr = provider.prayerSettings?.prayerTimes['Fajr']?.adhan;
      final offset = st?.imsakOffsetMinutes ?? -15;
      if (fajr != null && fajr.isNotEmpty) {
        return _calculateTimeWithOffset(fajr, offset);
      }
    } catch (_) {
      // Fall back to raw firebase map if provider fails
      final specialTimes = firebasePrayerTimes['specialTimes'];
      if (specialTimes is Map) {
        final useManual = specialTimes['useManualRamadanTimes'] == true;
        if (useManual) {
          final time = specialTimes['suhoorEndTime'];
          if (time is String && time.isNotEmpty) {
            return time;
          }
        }
        
        // Calculate from current prayer times data
        final fajrTime = _currentPrayerTimes['Fajr']?['adhan'] ?? '';
        final offset = (specialTimes['imsakOffsetMinutes'] is int 
            ? specialTimes['imsakOffsetMinutes'] 
            : -15) as int;
        if (fajrTime.isNotEmpty) {
          return _calculateTimeWithOffset(fajrTime, offset);
        }
      }
    }
    return '--:--';
  }

  String _getIftarTime() {
    try {
      final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
      final st = provider.prayerSettings?.specialTimes;
      
      // If manual mode is enabled, return the manually set time
      if (st?.useManualRamadanTimes == true) {
        final time = st?.iftarTime;
        if (time != null && time.isNotEmpty) {
          return time;
        }
      }
      
      // Otherwise, calculate from Maghrib + Iftar offset
      final maghrib = provider.prayerSettings?.prayerTimes['Maghrib']?.adhan;
      final offset = st?.iftarOffsetMinutes ?? 0;
      if (maghrib != null && maghrib.isNotEmpty) {
        return _calculateTimeWithOffset(maghrib, offset);
      }
    } catch (_) {
      // Fall back to raw firebase map if provider fails
      final specialTimes = firebasePrayerTimes['specialTimes'];
      if (specialTimes is Map) {
        final useManual = specialTimes['useManualRamadanTimes'] == true;
        if (useManual) {
          final time = specialTimes['iftarTime'];
          if (time is String && time.isNotEmpty) {
            return time;
          }
        }
        
        // Calculate from current prayer times data
        final maghribTime = _currentPrayerTimes['Maghrib']?['adhan'] ?? '';
        final offset = (specialTimes['iftarOffsetMinutes'] is int 
            ? specialTimes['iftarOffsetMinutes'] 
            : 0) as int;
        if (maghribTime.isNotEmpty) {
          return _calculateTimeWithOffset(maghribTime, offset);
        }
      }
    }
    return '--:--';
  }

  /// Helper method to calculate time with offset (positive or negative)
  String _calculateTimeWithOffset(String timeStr, int offsetMinutes) {
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return '--:--';
      
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;
      
      if (hour < 0 || minute < 0 || hour > 23 || minute > 59) return '--:--';
      
      // Create a naive DateTime and add the offset
      var resultTime = DateTime(2024, 1, 1, hour, minute);
      resultTime = resultTime.add(Duration(minutes: offsetMinutes));
      
      // Handle day wrapping
      if (resultTime.day > 1) resultTime = resultTime.subtract(const Duration(days: 1));
      if (resultTime.day < 1) resultTime = resultTime.add(const Duration(days: 1));
      
      return '${resultTime.hour.toString().padLeft(2, '0')}:${resultTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error calculating time with offset: $e');
      return '--:--';
    }
  }

  Widget _buildRamadanTimeRow(String label, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
            letterSpacing: 1,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 24,
            color: Color(0xFFFFD700),
            fontWeight: FontWeight.w900,
            fontFamily: 'RobotoMono',
            letterSpacing: 2,
            shadows: [
              Shadow(
                blurRadius: 6,
                color: Colors.black,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerTimesBar() {
    final prayerList = _currentPrayerTimes.isNotEmpty
        ? _currentPrayerTimes
        : (widget.prayerTimes ?? const <String, Map<String, String>>{});

    if (prayerList.isEmpty) {
      return const SizedBox.shrink();
    }

    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final mediaSize = MediaQuery.of(context).size;
    final screenWidth = mediaSize.width;
    final screenHeight = mediaSize.height;
    // Slightly increase the minimum scale so that the bar and
    // its contents stay comfortably readable even on 720p TVs.
    final scale = (screenHeight / 1080.0).clamp(0.9, 1.4);
    final tileWidth = (screenWidth / prayerOrder.length) - 2;
    
    bool isActivePrayer(String prayer) {
      return prayer.toLowerCase() == currentPrayerName.toLowerCase() &&
          (isAdhanTime || isIqamahTime || showIqamahStarted);
    }

    return Container(
      height: 120 * scale,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1976D2),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 25,
            spreadRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: prayerOrder.map((prayer) {
          final entry = prayerList.entries.firstWhere(
            (e) => e.key.toLowerCase() == prayer.toLowerCase(),
            orElse: () => MapEntry(prayer, const {}),
          );

          final bool isNext = nextPrayerName.toLowerCase() == entry.key.toLowerCase();
          final bool isActive = isActivePrayer(prayer);

          return SizedBox(
            width: tileWidth.clamp(220.0 * scale, 320.0 * scale),
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: 3, 
                vertical: isNext ? 0 : 5,
              ),
                decoration: BoxDecoration(
                gradient: isNext
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF00C853),
                          Color(0xFF00E676),
                          Color(0xFF69F0AE),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [0.0, 0.5, 1.0],
                      )
                    : isActive
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFF9800),
                              Color(0xFFFFB74D),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFF1E88E5),
                              Color(0xFF42A5F5),
                              Color(0xFF64B5F6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 0.5, 1.0],
                          ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isNext
                    ? [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.8),
                          blurRadius: 20,
                          spreadRadius: 4,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                          offset: const Offset(0, -1),
                          blurStyle: BlurStyle.inner,
                        ),
                      ]
                    : isActive
                        ? [
                            BoxShadow(
                              color: Colors.orangeAccent.withOpacity(0.6),
                              blurRadius: 12,
                              spreadRadius: 3,
                              offset: const Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2,
                              offset: const Offset(0, 3),
                            ),
                          ],
                border: Border.all(
                  color: isNext
                      ? Colors.white.withOpacity(0.9)
                      : isActive
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.3),
                  width: isNext ? 2.5 : (isActive ? 2.0 : 1.5),
                ),
              ),
              transform: isNext 
                  ? Matrix4.translationValues(0, -5, 0)
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prayer Name on Left Side
                  Container(
                    width: 90 * scale,
                    decoration: BoxDecoration(
                      color: isNext 
                          ? Colors.green[900]?.withOpacity(0.3)
                          : Colors.blue[900]?.withOpacity(0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        entry.key,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'Roboto',
                          letterSpacing: 0.7,
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black.withOpacity(0.8),
                              offset: const Offset(2, 2),
                            ),
                            if (isNext)
                              Shadow(
                                blurRadius: 3,
                                color: Colors.white.withOpacity(0.4),
                                offset: const Offset(-1, -1),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Times Section on Right
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isNext ? 4 : 8, vertical: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const double baseNeededHeight = 80.0;
                          final double available = constraints.maxHeight;
                          // Keep text large and readable, but still allow
                          // a bit of shrink when vertical space is tight.
                          final double localScale = (available / baseNeededHeight)
                              .clamp(0.7, 1.0);

                          final double headingFont = (isNext ? 13 : 16) * scale * localScale;
                          final double timeFont = (isNext ? 26 : 24) * scale * localScale;

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // HEADINGS Row - ADHAN and IQAMAH side by side
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ADHAN',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: headingFont,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 5,
                                            color: Colors.black.withOpacity(0.8),
                                            offset: const Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'IQAMAH',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: headingFont,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 5,
                                            color: Colors.black.withOpacity(0.8),
                                            offset: const Offset(1, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 2),

                              // TIMES Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // ADHAN Time
                                  Expanded(
                                    child: Text(
                                      entry.value['adhan'] ?? '--:--',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: timeFont,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontFamily: 'RobotoMono',
                                        letterSpacing: 1.2,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 6,
                                            color: Colors.black.withOpacity(0.8),
                                            offset: const Offset(2, 2),
                                          ),
                                          if (isNext)
                                            Shadow(
                                              blurRadius: 3,
                                              color: Colors.greenAccent.withOpacity(0.5),
                                              offset: const Offset(-1, -1),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // IQAMAH Time
                                  Expanded(
                                    child: Text(
                                      entry.value['iqamah'] ?? '--:--',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: timeFont,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontFamily: 'RobotoMono',
                                        letterSpacing: 1.2,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 6,
                                            color: Colors.black.withOpacity(0.8),
                                            offset: const Offset(2, 2),
                                          ),
                                          if (isNext)
                                            Shadow(
                                              blurRadius: 3,
                                              color: Colors.greenAccent.withOpacity(0.5),
                                              offset: const Offset(-1, -1),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPrayerTimesBarVertical() {
    final prayerList = _currentPrayerTimes.isNotEmpty
        ? _currentPrayerTimes
        : (widget.prayerTimes ?? const <String, Map<String, String>>{});

    if (prayerList.isEmpty) {
      return const SizedBox.shrink();
    }

    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final screenHeight = MediaQuery.of(context).size.height;
    // Match the horizontal bar's behavior so that text remains
    // clearly visible even on smaller displays.
    final scale = (screenHeight / 1080.0).clamp(0.9, 1.4);
    
    bool isActivePrayer(String prayer) {
      return prayer.toLowerCase() == currentPrayerName.toLowerCase() &&
          (isAdhanTime || isIqamahTime || showIqamahStarted);
    }

    return Container(
      height: 90 * scale,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1976D2),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 25,
            spreadRadius: 8,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: prayerOrder.map((prayer) {
          final entry = prayerList.entries.firstWhere(
            (e) => e.key.toLowerCase() == prayer.toLowerCase(),
            orElse: () => MapEntry(prayer, const {}),
          );

          final bool isNext = nextPrayerName.toLowerCase() == entry.key.toLowerCase();
          final bool isActive = isActivePrayer(prayer);

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: isNext
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF00C853),
                          Color(0xFF00E676),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : isActive
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFFF9800),
                              Color(0xFFFFB74D),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFF1E88E5),
                              Color(0xFF42A5F5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: isNext
                        ? Colors.greenAccent.withOpacity(0.6)
                        : isActive
                            ? Colors.orangeAccent.withOpacity(0.5)
                            : Colors.blueAccent.withOpacity(0.4),
                    blurRadius: isNext ? 12 : 6,
                    spreadRadius: isNext ? 2 : 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Prayer Name
                      Text(
                        entry.key,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontFamily: 'Roboto',
                          shadows: [
                            Shadow(
                              blurRadius: 3,
                              color: Colors.black,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      
                      // Times in single line: A: time I: time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Adhan
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'A:',
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                entry.value['adhan'] ?? '--:--',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'RobotoMono',
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2,
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Iqamah
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'I:',
                                style: TextStyle(
                                  fontSize: 11 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                entry.value['iqamah'] ?? '--:--',
                                style: TextStyle(
                                  fontSize: 16 * scale,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'RobotoMono',
                                  shadows: [
                                    Shadow(
                                      blurRadius: 2,
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdhanIqamahDisplay() {
    final size = MediaQuery.of(context).size;
    final scale = (size.height / 1080.0).clamp(0.7, 1.4);
    // 1. Show "Prayer has started" after iqamah
    if (showIqamahStarted && isIqamahTime) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mosque,
                size: 120 * scale,
                color: Colors.green,
              ),
              SizedBox(height: 40 * scale),
              Text(
                '$currentPrayerName PRAYER HAS STARTED',
                style: TextStyle(
                  fontSize: 48 * scale,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                  fontFamily: 'Roboto',
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 20 * scale),
              Text(
                'IQAMAH HAS BEEN CALLED',
                style: TextStyle(
                  fontSize: 28 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              SizedBox(height: 40 * scale),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Text(
                  'PLEASE JOIN THE CONGREGATION',
                  style: TextStyle(
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Roboto',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 2. Show countdown if we're between adhan and iqamah
    if (isAdhanTime && !isIqamahTime && iqamahCountdown.inSeconds > 0) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_filled,
                size: 120 * scale,
                color: Colors.amber,
              ),
              SizedBox(height: 40 * scale),
              Text(
                'IQAMAH',
                style: TextStyle(
                  fontSize: 48 * scale,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                  fontFamily: 'Roboto',
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 20 * scale),
              Text(
                'For $currentPrayerName',
                style: TextStyle(
                  fontSize: 36 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              SizedBox(height: 40 * scale),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'STARTS IN',
                      style: TextStyle(
                        fontSize: 24 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    SizedBox(height: 15 * scale),
                    Text(
                      _formatDuration(iqamahCountdown),
                      style: TextStyle(
                        fontSize: 64 * scale,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'RobotoMono',
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30 * scale),
              Text(
                'PLEASE PREPARE FOR PRAYER',
                style: TextStyle(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.8),
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 3. Show generic "Adhan time" if no iqamah specified
    if (isAdhanTime && !isIqamahTime) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mosque,
                size: 120 * scale,
                color: Colors.blue,
              ),
              SizedBox(height: 40 * scale),
              Text(
                'ADHAN TIME',
                style: TextStyle(
                  fontSize: 48 * scale,
                  fontWeight: FontWeight.w900,
                  color: Colors.blue,
                  fontFamily: 'Roboto',
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 20 * scale),
              Text(
                'For $currentPrayerName',
                style: TextStyle(
                  fontSize: 36 * scale,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              SizedBox(height: 40 * scale),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'PRAYER TIME',
                      style: TextStyle(
                        fontSize: 24 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    SizedBox(height: 15 * scale),
                    Text(
                      'IN PROGRESS',
                      style: TextStyle(
                        fontSize: 32 * scale,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 30 * scale),
              Text(
                'PLEASE JOIN THE PRAYER',
                style: TextStyle(
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.8),
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 4. Default: Show announcements carousel
    return CarouselSlider.builder(
      itemCount: firebaseAnnouncements.length,
      itemBuilder: (context, index, realIndex) {
        final item = firebaseAnnouncements[index];
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Image.network(
            item['imagePath'] ?? item['image'] ?? '',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF42A5F5),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading Image...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey[900],
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                      ),
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      item['title']?.toUpperCase() ?? 'ANNOUNCEMENT',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Roboto',
                        letterSpacing: 1,
                      ),
                    ),
                    if (item['description'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                        child: Text(
                          item['description'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
      options: CarouselOptions(
        autoPlay: true,
        height: double.infinity,
        autoPlayInterval: const Duration(seconds: 7),
        autoPlayCurve: Curves.easeInOut,
        enlargeCenterPage: false,
        viewportFraction: 1.0,
        enableInfiniteScroll: true,
        padEnds: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final currentTime = now;
    final timeStr = DateFormat.Hms().format(currentTime);
    final dayStr = DateFormat.EEEE().format(currentTime);
    final monthDateStr = DateFormat.yMMMMd().format(currentTime);
    final hijriStr = _getHijriDate(currentTime);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 85,
                  child: (isAdhanTime || showIqamahStarted) 
                      ? _buildAdhanIqamahDisplay()
                      : firebaseAnnouncements.isEmpty
                          ? Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1976D2),
                                          Color(0xFF42A5F5),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF1976D2)
                                              .withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 50,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    isLoadingFirebase
                                        ? 'LOADING ANNOUNCEMENTS'
                                        : 'NO ANNOUNCEMENTS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  if (isLoadingFirebase)
                                    const SizedBox(height: 20),
                                  if (isLoadingFirebase)
                                    SizedBox(
                                      width: 200,
                                      child: LinearProgressIndicator(
                                        backgroundColor: Colors.grey[800],
                                        color: const Color(0xFF42A5F5),
                                        minHeight: 4,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : _buildAdhanIqamahDisplay(),
                ),
                Container(
                  width: 260,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0D47A1),
                        Color(0xFF1976D2),
                        Color(0xFF42A5F5),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.5, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                        offset: const Offset(5, 0),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'RobotoMono',
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                dayStr.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                monthDateStr.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 1,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                hijriStr.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 1,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            const Text(
                              "NEXT PRAYER",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Roboto',
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    blurRadius: 8,
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                nextPrayerName.isNotEmpty
                                    ? nextPrayerName.toUpperCase()
                                    : '--',
                                style: const TextStyle(
                                  fontSize: 36,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 15,
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'STARTS IN',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Roboto',
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _formatDuration(nextPrayerCountdown),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'RobotoMono',
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Ramadan Section
                        if (_isRamadanModeEnabled()) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.nights_stay,
                                color: const Color(0xFFFFD700),
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'RAMADAN',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Color(0xFFFFD700),
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Roboto',
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildRamadanTimeRow(
                              'SUHOOR ENDS', _getSuhoorEndTime()),
                          const SizedBox(height: 10),
                          _buildRamadanTimeRow('IFTAR', _getIftarTime()),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Prayer times bar
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              if (screenWidth < 1000) {
                return _buildPrayerTimesBarVertical();
              } else {
                return _buildPrayerTimesBar();
              }
            },
          ),
        ],
      ),
    );
  }
}
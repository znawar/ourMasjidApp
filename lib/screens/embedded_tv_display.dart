import 'dart:async';
import 'dart:convert';
import 'package:admin_web/models/prayer_settings_model.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
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
  
  // Timezone
  String? _timezoneName;
  DateTime? _masjidLocalTime;
  bool _timezoneResolved = false;
  Timer? _timezoneRetryTimer;
  int _timezoneRetryAttempts = 0;
  static const int _maxTimezoneRetryAttempts = 5;
  bool _timezoneResolutionInProgress = false;
  
  // Masjid-local time derived from timezone; no external time API needed
  String? _iqamahBackgroundImageUrl;

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
void _updateLocalTime() {
  try {
    final tzName = _timezoneName?.trim().toLowerCase();
    
    // Log current state for debugging
    debugPrint('⏰ _updateLocalTime called. Timezone: "$_timezoneName", Resolved: $_timezoneResolved');
    
    if (tzName == null || 
        tzName.isEmpty || 
        tzName == 'auto' || 
        tzName.contains('device')) {
      _masjidLocalTime = DateTime.now();
      debugPrint('⏰ Using device time (${_masjidLocalTime}) - no valid timezone');
      return;
    }

    try {
      // Try to use the timezone package
      final location = tz.getLocation(_timezoneName!);
      _masjidLocalTime = tz.TZDateTime.now(location);
      debugPrint('✅✅✅ Using resolved timezone "$_timezoneName" -> Masjid time: ${_masjidLocalTime} | Device time: ${DateTime.now()}');
    } catch (tzError) {
      debugPrint('⚠️ Could not use timezone "$_timezoneName": $tzError');
      
      // Fallback for manual offset formats
      if (_timezoneName!.startsWith('Etc/GMT') || _timezoneName!.startsWith('UTC')) {
        // Parse offset and create custom location
        final match = RegExp(r"(?:Etc/GMT|UTC)([+-])(\d{1,2})(?::(\d{2}))?").firstMatch(_timezoneName!);
        if (match != null) {
          final signStr = match.group(1);
          final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
          final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
          
          int offsetSeconds = (hours * 3600) + (minutes * 60);
          
          // Determine direction (Etc/GMT-5 = UTC+5)
          bool shouldAdd = false;
          if (_timezoneName!.startsWith('UTC')) {
            shouldAdd = (signStr == '+');
          } else {
            shouldAdd = (signStr == '-');
          }
          
          final totalOffset = shouldAdd ? offsetSeconds : -offsetSeconds;
          
          // Calculate manual offset
          _masjidLocalTime = DateTime.now().add(Duration(seconds: totalOffset));
          debugPrint('✅ Using manual offset "$_timezoneName" (${totalOffset ~/ 3600}h ${(totalOffset.abs() % 3600) ~/ 60}m) -> ${_masjidLocalTime}');
        } else {
          debugPrint('❌ Could not parse timezone pattern "$_timezoneName", using device time');
          _masjidLocalTime = DateTime.now();
        }
      } else {
        debugPrint('❌ Unknown timezone format "$_timezoneName", using device time');
        _masjidLocalTime = DateTime.now();
      }
    }
  } catch (e) {
    debugPrint('❌ Critical error in _updateLocalTime: $e');
    _masjidLocalTime = DateTime.now();
  }
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
      _fetchIqamahBackgroundImage();
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  Future<void> _fetchIqamahBackgroundImage() async {
    try {
      debugPrint('🔄 Starting to fetch iqamah background image...');
      
      // Try to fetch from global settings first
      final settingsDoc = await firestore.collection('settings').doc('app_config').get();
      if (settingsDoc.exists) {
        final imageBase64 = settingsDoc.data()?['iqamahBackgroundImage'] as String?;
        if (imageBase64 != null && imageBase64.isNotEmpty) {
          if (mounted) {
            setState(() {
              _iqamahBackgroundImageUrl = imageBase64;
            });
          }
          debugPrint('✅ Loaded iqamah background image from settings (${imageBase64.length} chars)');
          return;
        }
      }
      
      // Fallback: try to fetch from specific masjid document if available
      if (_resolvedMasjidId != null) {
        final masjidDoc = await firestore.collection('masjids').doc(_resolvedMasjidId).get();
        if (masjidDoc.exists) {
          final imageBase64 = masjidDoc.data()?['iqamahBackgroundImage'] as String?;
          if (imageBase64 != null && imageBase64.isNotEmpty) {
            if (mounted) {
              setState(() {
                _iqamahBackgroundImageUrl = imageBase64;
              });
            }
            debugPrint('✅ Loaded iqamah background image from masjid document (${imageBase64.length} chars)');
            return;
          }
        }
      }
      
      debugPrint('⚠️ No iqamah background image found in Firestore');
    } catch (e) {
      debugPrint('❌ Error fetching iqamah background image: $e');
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
    final LocationSettings loc = LocationSettings.fromMap(
      data['location'] as Map<String, dynamic>?,
      data,
    );

    final String? newCity = loc.city;
    final String? newCountry = loc.country;
    final double? newLat = loc.latitude != 0.0 ? loc.latitude : null;
    final double? newLon = loc.longitude != 0.0 ? loc.longitude : null;
    final String? newTz = (loc.timezone.isNotEmpty && 
                          loc.timezone.toLowerCase() != 'auto') ? loc.timezone : null;

    // Check if location has actually changed
    final bool locationChanged = 
        newCity != _masjidCity || 
        newCountry != _masjidCountry || 
        newLat != _masjidLatitude || 
        newLon != _masjidLongitude ||
        newTz != _timezoneName;

    if (locationChanged) {
      debugPrint('📍📍📍 Location changed for TV: resetting timezone resolution');
      _timezoneResolved = false; // Reset flag
      _resetTimezoneRetryState();
    }

    _masjidCity = newCity;
    _masjidCountry = newCountry;
    _masjidLatitude = newLat;
    _masjidLongitude = newLon;

    // If we have a direct timezone in the data, use it immediately
    if (newTz != null && newTz.isNotEmpty) {
      _timezoneName = newTz;
      _timezoneResolved = true;
      _resetTimezoneRetryState();
      _updateLocalTime();
      debugPrint('✅ Using stored timezone from document: $_timezoneName');
    } else if (locationChanged) {
      _timezoneName = 'Auto';
      // Trigger resolution if we have city/country info
      if ((newCity != null && newCity.isNotEmpty) || 
          (newCountry != null && newCountry.isNotEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _resolveTimezoneFromCityCountry();
        });
      }
    }

    debugPrint('TV Extracted location: $_masjidCity, $_masjidCountry, TZ: $_timezoneName');
  } catch (e) {
    debugPrint('Error extracting location data for TV: $e');
  }
}
  Future<void> _resolveTimezoneFromCityCountry() async {
  if (_timezoneResolutionInProgress) {
    debugPrint('⏳ Timezone resolution already in progress, skipping duplicate call');
    return;
  }

  final hasCityOrCountry =
      (_masjidCity != null && _masjidCity!.trim().isNotEmpty) ||
      (_masjidCountry != null && _masjidCountry!.trim().isNotEmpty);
  final hasCoords = _masjidLatitude != null && _masjidLongitude != null;
  final hasLocationHint = hasCityOrCountry || hasCoords;

  debugPrint('🌍 Starting timezone resolution: City=$_masjidCity, Country=$_masjidCountry, Coords=($_masjidLatitude, $_masjidLongitude)');

  if (!hasLocationHint) {
    debugPrint('❌ No location data available for timezone resolution');
    _timezoneResolved = true;
    return;
  }

  // Check if already resolved with a valid timezone (not "Auto" or "Device Time")
  final currentTz = _timezoneName?.trim().toLowerCase();
  if (_timezoneResolved && 
      currentTz != null && 
      currentTz.isNotEmpty &&
      !currentTz.contains('auto') &&
      !currentTz.contains('device')) {
    debugPrint('⏭️ Timezone already resolved: $_timezoneName');
    return;
  }

  _timezoneResolutionInProgress = true;
  try {
    String? tzId;

    // FIRST PRIORITY: Try using coordinates
    if (hasCoords) {
      debugPrint('🔍 Attempting coordinate-based timezone lookup: ($_masjidLatitude, $_masjidLongitude)');
      
      // Try multiple services in order
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // 1. Try TimeZoneDB first (most reliable)
      tzId = await _tryGetTimezoneFromCoordinates();
      
      if (tzId == null || tzId.isEmpty) {
        // 2. Try Google API if available
        // tzId = await TimezoneService.getTimezoneFromGoogle(...);
        // 3. Fallback to free service
        final res = await TimezoneService.getTimezoneFromFreeService(_masjidLatitude!, _masjidLongitude!);
        if (res != null) {
          tzId = res.timezoneId;
          debugPrint('✅ Free service coordinate lookup succeeded: $tzId');
        }
      }
    }

    // SECOND PRIORITY: Try to get timezone from city/country using TimeZoneDB API
    if ((tzId == null || tzId.isEmpty) && hasCityOrCountry) {
      debugPrint('🔍 Attempting city/country lookup via TimeZoneDB');
      tzId = await _getTimezoneFromCityCountryUsingAPI();
      
      if (tzId != null && tzId.isNotEmpty && tzId != 'UTC') {
        debugPrint('✅ City/country lookup succeeded: $tzId');
      }
    }

    // THIRD PRIORITY: Country guess fallback
    if ((tzId == null || tzId.isEmpty) && _masjidCountry != null && _masjidCountry!.trim().isNotEmpty) {
      debugPrint('🔍 Attempting country-level guess: ${_masjidCountry!.trim()}');
      tzId = await TimezoneService.guessTimezoneFromCountry(_masjidCountry!.trim());
      if (tzId != null && tzId.isNotEmpty) {
        debugPrint('✅ Country guess succeeded: $tzId');
      } else {
        debugPrint('⚠️ Country guess failed');
      }
    }

    // FOURTH PRIORITY: Check if we already have a timezone in firebase data
    if ((tzId == null || tzId.isEmpty) && firebasePrayerTimes.isNotEmpty) {
      try {
        final LocationSettings loc = LocationSettings.fromMap(
          firebasePrayerTimes['location'] as Map<String, dynamic>?,
          firebasePrayerTimes,
        );
        final storedTz = loc.timezone;
        if (storedTz.isNotEmpty && storedTz.toLowerCase() != 'auto') {
          tzId = storedTz;
          debugPrint('✅ Using stored timezone from document: $tzId');
        }
      } catch (e) {
        debugPrint('⚠️ Error extracting stored timezone: $e');
      }
    }

    if (tzId != null && tzId.isNotEmpty) {
      // Mark as resolved and update everything
      _timezoneName = tzId;
      _timezoneResolved = true;
      _resetTimezoneRetryState();
      
      debugPrint('✅✅✅ Resolved timezone for TV display: $_timezoneName');
      
      // Force update local time
      _updateLocalTime();
      
      if (mounted) {
        setState(() {
          // Use the updated masjid local time
          now = _masjidLocalTime ?? DateTime.now();
          // Recalculate everything
          _calculateNextPrayer();
          _checkCurrentPrayerTimes();
        });
      }
      return;
    }

    debugPrint('❌ All timezone resolution methods failed, using device time');
    _timezoneName = 'Device Time';
    _timezoneResolved = true;
    _resetTimezoneRetryState();
    
    _updateLocalTime();
    if (mounted) {
      setState(() {
        now = _masjidLocalTime ?? DateTime.now();
        _calculateNextPrayer();
        _checkCurrentPrayerTimes();
      });
    }

  } catch (e) {
    debugPrint('❌ Error resolving timezone: $e');
    _timezoneName = 'Device Time';
    _timezoneResolved = true;
    _resetTimezoneRetryState();
    
    _updateLocalTime();
    if (mounted) {
      setState(() {
        now = _masjidLocalTime ?? DateTime.now();
        _calculateNextPrayer();
        _checkCurrentPrayerTimes();
      });
    }
  } finally {
    _timezoneResolutionInProgress = false;
  }
}

// NEW METHOD: Try to get timezone from coordinates using TimeZoneDB
Future<String?> _tryGetTimezoneFromCoordinates() async {
  try {
    const apiKey = '4068P1GO72CR'; // Your TimeZoneDB API key
    final result = await TimezoneService.getTimezoneFromTimeZoneDb(
      _masjidLatitude!,
      _masjidLongitude!,
      apiKey,
    );
    
    if (result != null && result.timezoneId.isNotEmpty) {
      debugPrint('✅ TimeZoneDB coordinate lookup succeeded: ${result.timezoneId}');
      return result.timezoneId;
    }
  } catch (e) {
    debugPrint('⚠️ TimeZoneDB coordinate lookup error: $e');
  }
  return null;
}

// NEW METHOD: Get timezone from city/country using TimeZoneDB API
Future<String?> _getTimezoneFromCityCountryUsingAPI() async {
  try {
    // First, try to get country code
    String? countryCode;
    final country = _masjidCountry?.trim() ?? '';
    
    if (country.isNotEmpty) {
      // Try to get country code from REST Countries API
      try {
        final url = Uri.https('restcountries.com', '/v3.1/name/$country', {
          'fullText': 'true',
        });
        final resp = await http.get(url).timeout(const Duration(seconds: 5));
        
        if (resp.statusCode == 200) {
          final List<dynamic> data = jsonDecode(resp.body);
          if (data.isNotEmpty) {
            final countryData = data[0] as Map<String, dynamic>;
            countryCode = countryData['cca2'] as String?;
          }
        }
      } catch (e) {
        debugPrint('⚠️ REST Countries API error: $e');
      }
    }
    
    // If we have country code, try TimeZoneDB
    if (countryCode != null && countryCode.isNotEmpty) {
      const apiKey = '4068P1GO72CR';
      final url = Uri.http('api.timezonedb.com', '/v2.1/list-time-zone', {
        'key': apiKey,
        'format': 'json',
        'country': countryCode,
      });
      
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      
      if (resp.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(resp.body);
        if (data['status'] == 'OK') {
          final zones = data['zones'] as List<dynamic>?;
          if (zones != null && zones.isNotEmpty) {
            // Try to find the capital or most populated city
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
            
            // Also check if we have city name match
            final city = _masjidCity?.trim().toLowerCase() ?? '';
            if (city.isNotEmpty) {
              for (var zone in zoneList) {
                final zoneName = (zone['zoneName'] as String?)?.toLowerCase() ?? '';
                if (zoneName.contains(city)) {
                  return zone['zoneName'] as String;
                }
              }
            }
            
            // Return most populated city's timezone
            final bestZone = zoneList.first;
            return bestZone['zoneName'] as String?;
          }
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error in city/country API lookup: $e');
  }
  
  return null;
}

  Future<String> _getSimpleTimezoneFromCityCountry(String city, String country) async {
    // Use the same timezone service API that the provider uses
    // This ensures consistency across the app
    final guess = await TimezoneService.guessTimezoneFromCountry(country);
    if (guess != null && guess.isNotEmpty) {
      return guess;
    }
    
    // If country guess fails, default to UTC
    return 'UTC';
  }

  void _resetTimezoneRetryState() {
    _timezoneRetryAttempts = 0;
    _timezoneRetryTimer?.cancel();
    _timezoneRetryTimer = null;
  }

  void _scheduleTimezoneRetry() {
    if (_timezoneRetryAttempts >= _maxTimezoneRetryAttempts) {
      debugPrint('⚠️ Max timezone retry attempts reached ($_timezoneRetryAttempts). Giving up.');
      _timezoneResolved = true;
      return;
    }

    _timezoneRetryAttempts++;
    int delaySeconds = 15 + (_timezoneRetryAttempts - 1) * 6;
    if (delaySeconds > 45) {
      delaySeconds = 45;
    }

    debugPrint('⏳ Scheduling timezone retry #$_timezoneRetryAttempts in ${delaySeconds}s');
    _timezoneRetryTimer?.cancel();
    _timezoneRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      _resolveTimezoneFromCityCountry();
    });
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
    _timezoneRetryTimer?.cancel();
    Wakelock.disable();
    _announcementsSub?.cancel();
    _prayerTimesSub?.cancel();
    super.dispose();
  }

  /// Builds an ImageProvider from base64 Firestore data or asset path
  /// - If imageData starts with "data:", decodes as base64 MemoryImage
  /// - Otherwise treats as asset path and loads AssetImage
  ImageProvider _buildImageProvider(String? imageData) {
    try {
      debugPrint('🔍 _buildImageProvider called with imageData: ${imageData?.substring(0, 50)}...');
      
      if (imageData == null || imageData.isEmpty) {
        debugPrint('⚠️ No image data provided, using solid color');
        return AssetImage('assets/images/iqamah_background.jpg');
      }
      
      // Check if this is a base64 data URI (e.g., from Firestore)
      if (imageData.startsWith('data:')) {
        debugPrint('✅ Detected base64 data URI format');
        // Extract base64 portion after "data:image/...;base64,"
        final parts = imageData.split(',');
        if (parts.length < 2) {
          debugPrint('❌ Invalid base64 data URI format - missing comma');
          return AssetImage('assets/images/iqamah_background.jpg');
        }
        
        final base64String = parts.last.trim();
        if (base64String.isEmpty) {
          debugPrint('❌ Base64 string is empty after splitting');
          return AssetImage('assets/images/iqamah_background.jpg');
        }
        
        debugPrint('📦 Decoding base64 string of length: ${base64String.length}');
        final decodedBytes = base64Decode(base64String);
        if (decodedBytes.isEmpty) {
          debugPrint('❌ Decoded image bytes are empty');
          return AssetImage('assets/images/iqamah_background.jpg');
        }
        
        debugPrint('✅ Successfully decoded ${decodedBytes.length} bytes to MemoryImage');
        return MemoryImage(decodedBytes);
      } else {
        debugPrint('ℹ️ Treating as asset path: $imageData');
        // Treat as asset path
        return AssetImage(imageData);
      }
    } catch (e) {
      debugPrint('❌ Error building image provider: $e');
      // Fallback to asset image
      return AssetImage('assets/images/iqamah_background.jpg');
    }
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
      
      // Log every 30 seconds to track time updates
      if (DateTime.now().second % 30 == 0) {
        debugPrint('⏰ TV Clock: $_timezoneName | Local: $newNow | Device: ${DateTime.now()}');
      }
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

    if (source.isEmpty) {
      debugPrint('⚠️ No prayer times available');
      return;
    }

    debugPrint('🔍 Checking prayer times. Current time: $now');
    debugPrint('📋 Available prayers: ${source.keys.toList()}');

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
      debugPrint('⏰ Outside prayer window. Start: $windowStart, End: $windowEnd, Now: $now');
      _iqamahTimer?.cancel();
      return;
    }

    currentPrayerName = latestPrayerName;
    debugPrint('✅ In prayer window for $latestPrayerName. Window: $windowStart to $windowEnd');

    // No iqamah configured: treat the whole window as generic adhan time.
    if (iqamahTime == null || iqamahStr.isEmpty || iqamahStr == '--:--') {
      debugPrint('ℹ️ No iqamah time. Treating as generic adhan time.');
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

    final DateTime base = now;
    DateTime? nextTime;
    String? nextName;

  
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

  // Parse the time string (HH:mm format)
  int hour = -1;
  int minute = -1;
  
  try {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    
    hour = int.tryParse(parts[0]) ?? -1;
    minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;
    
    if (hour < 0 || minute < 0 || hour > 23 || minute > 59) return null;
  } catch (e) {
    debugPrint('❌ Error parsing time "$input": $e');
    return null;
  }

  // Create DateTime in the masjid's timezone context
  // Base is already in masjid-local time (from _updateLocalTime)
  final naiveDt = DateTime(base.year, base.month, base.day, hour, minute);
  
  // If we have a resolved timezone, convert to TZDateTime
  if (_timezoneName != null && 
      _timezoneName!.isNotEmpty && 
      !_timezoneName!.toLowerCase().contains('device') &&
      !_timezoneName!.toLowerCase().contains('auto')) {
    try {
      final location = tz.getLocation(_timezoneName!);
      return tz.TZDateTime(location, naiveDt.year, naiveDt.month, naiveDt.day, hour, minute);
    } catch (e) {
      debugPrint('⚠️ Could not create TZDateTime for "$_timezoneName": $e');
      return naiveDt;
    }
  }
  
  // Fallback: return naive DateTime
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

 // Replace the _buildPrayerTimesBar() method with this new gel buttons method
Widget _buildGelPrayerButtons() {
  final prayerList = _currentPrayerTimes.isNotEmpty
      ? _currentPrayerTimes
      : (widget.prayerTimes ?? const <String, Map<String, String>>{});

  if (prayerList.isEmpty) {
    return const SizedBox.shrink();
  }

  const prayerOrder = ['FAJR', 'DHUHR', 'ASR', 'MAGHRIB', 'ISHA'];
  final mediaSize = MediaQuery.of(context).size;
  final screenHeight = mediaSize.height;
  final scale = (screenHeight / 1080.0).clamp(0.9, 1.4);
  
  bool isActivePrayer(String prayer) {
    return prayer.toLowerCase() == currentPrayerName.toLowerCase() &&
        (isAdhanTime || isIqamahTime || showIqamahStarted);
  }

  return Positioned(
    bottom: 40,
    left: 0,
    right: 0,
    child: Container(
      height: 160 * scale,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: prayerOrder.map((prayer) {
          final entry = prayerList.entries.firstWhere(
            (e) => e.key.toLowerCase() == prayer.toLowerCase(),
            orElse: () => MapEntry(prayer, const {}),
          );

          final bool isNext = nextPrayerName.toLowerCase() == entry.key.toLowerCase();
          final bool isActive = isActivePrayer(prayer);

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 12 * scale),
            child: Container(
              width: 250 * scale,
              height: 150 * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20 * scale),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isNext
                      ? [
                          const Color(0xFF69F0AE).withOpacity(0.5),
                          const Color(0xFF00C853).withOpacity(0.5),
                          const Color(0xFF00C853).withOpacity(0.5),
                        ]
                      : isActive
                          ? [
                              const Color(0xFFFFB74D).withOpacity(0.5),
                              const Color(0xFFFF9800).withOpacity(0.5),
                              const Color(0xFFFF9800).withOpacity(0.5),
                            ]
                          : [
                              const Color(0xFF64B5F6).withOpacity(0.5),
                              const Color(0xFF1976D2).withOpacity(0.5),
                              const Color(0xFF1976D2).withOpacity(0.5),
                            ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5 * scale,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20 * scale,
                    left: -20 * scale,
                    child: Container(
                      width: 60 * scale,
                      height: 60 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: EdgeInsets.all(12 * scale),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 30 * scale,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Roboto',
                            letterSpacing: 1 * scale,
                            shadows: [
                              Shadow(
                                blurRadius: 4 * scale,
                                color: Colors.black.withOpacity(0.5),
                                offset: Offset(1 * scale, 1 * scale),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 8 * scale),
                        
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'ADHAN: ',
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                Text(
                                  entry.value['adhan'] ?? '--:--',
                                  style: TextStyle(
                                    fontSize: 22 * scale,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFamily: 'RobotoMono',
                                    shadows: [
                                      Shadow(
                                        blurRadius: 3 * scale,
                                        color: Colors.black.withOpacity(0.5),
                                        offset: Offset(1 * scale, 1 * scale),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 6 * scale),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'IQAMAH: ',
                                  style: TextStyle(
                                    fontSize: 20 * scale,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                Text(
                                  entry.value['iqamah'] ?? '--:--',
                                  style: TextStyle(
                                    fontSize: 22 * scale,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFamily: 'RobotoMono',
                                    shadows: [
                                      Shadow(
                                        blurRadius: 3 * scale,
                                        color: Colors.black.withOpacity(0.5),
                                        offset: Offset(1 * scale, 1 * scale),
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
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}  
  Widget _buildAdhanIqamahDisplay() {
  debugPrint('🎬 Building Adhan/Iqamah Display');
  debugPrint('  isAdhanTime: $isAdhanTime');
  debugPrint('  isIqamahTime: $isIqamahTime');
  debugPrint('  showIqamahStarted: $showIqamahStarted');
  debugPrint('  currentPrayerName: $currentPrayerName');
  debugPrint('  iqamahCountdown: $iqamahCountdown');
  
  final size = MediaQuery.of(context).size;
  final scale = (size.height / 1080.0).clamp(0.7, 1.4);
  
  // 1. Show "Prayer has started" after iqamah
  if (showIqamahStarted && isIqamahTime) {
    return Stack(
      children: [
        // Background color fallback
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.5),
                Colors.white.withOpacity(0.5),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Background image - from Firestore (base64) or fallback to asset
        if (_iqamahBackgroundImageUrl != null && _iqamahBackgroundImageUrl!.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _buildImageProvider(_iqamahBackgroundImageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        // White-Blue gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.blue.withOpacity(0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mosque,
                size: 140 * scale,
                color: Colors.green,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.7),
                    blurRadius: 10,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              SizedBox(height: 50 * scale),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Prayer for ',
                      style: TextStyle(
                        fontSize: 90* scale,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.7),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: currentPrayerName,
                      style: TextStyle(
                        fontSize: 90 * scale,
                        fontWeight: FontWeight.w900,
                        color: Colors.green,
                        fontFamily: 'Roboto',
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.7),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    TextSpan(
                      text: ' has started',
                      style: TextStyle(
                        fontSize: 90 * scale,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.7),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildGelPrayerButtons(),
      ],
    );
  }
  
  // 2. Show countdown if we're between adhan and iqamah
  if (isAdhanTime && !isIqamahTime && iqamahCountdown.inSeconds > 0) {
    return Stack(
      children: [
        // Background color fallback
        Container(
          color: Colors.grey.shade900,
        ),
        // Background image - from Firestore (base64) or fallback to asset
        if (_iqamahBackgroundImageUrl != null && _iqamahBackgroundImageUrl!.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: _buildImageProvider(_iqamahBackgroundImageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
        // White-Blue gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.blue.withOpacity(0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Content
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 100 * (MediaQuery.of(context).size.height / 1080.0)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  'Prayer for',
                style: TextStyle(
                  fontSize: 90* scale,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.7),
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12 * scale),
              Text(
                currentPrayerName,
                style: TextStyle(
                  fontSize: 100 * scale,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                  fontFamily: 'Roboto',
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black.withOpacity(0.8),
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 50 * scale),
              Column(
                children: [
                  Text(
                    'In',
                    style: TextStyle(
                      fontSize: 90 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Roboto',
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.7),
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20 * scale),
                    Text(
                      _formatDuration(iqamahCountdown),
                      style: TextStyle(
                        fontSize: 96 * scale,
                        fontWeight: FontWeight.w900,
                        color: Colors.amber,
                        fontFamily: 'RobotoMono',
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.8),
                            offset: Offset(2, 2),
                          ),
                  
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
      
          ),
        ),
        _buildGelPrayerButtons(),
      ],
    );
  }
  
  // 3. Show generic "Adhan time" if no iqamah specified
  if (isAdhanTime && !isIqamahTime) {
    return Stack(
      children: [
        Container(
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
        ),
        _buildGelPrayerButtons(),
      ],
    );
  }
  
  // 4. Default: Show announcements carousel with gel buttons floating on top
  return Stack(
    children: [
      CarouselSlider.builder(
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
      ),
      _buildGelPrayerButtons(),
    ],
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
    body: Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  (isAdhanTime || showIqamahStarted)
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
                ],
              ),
            ),
            Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1976D2).withOpacity(0.4),
                    const Color(0xFF42A5F5).withOpacity(0.3),
                    const Color(0xFF64B5F6).withOpacity(0.2),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -40,
                    left: -40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
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
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}
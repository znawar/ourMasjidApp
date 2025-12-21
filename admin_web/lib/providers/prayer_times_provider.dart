import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/prayer_api_service.dart';
import '../models/prayer_settings_model.dart';

class PrayerTimesProvider with ChangeNotifier {
  late final FirebaseFirestore _firestore;
  bool _firebaseInitialized = false;
  
  PrayerSettings? _prayerSettings;
  bool _isLoading = false;
  String? _errorMessage;
  String? _masjidId;
  bool _isCalculating = false;

  PrayerTimesProvider() {
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      _firestore = FirebaseFirestore.instance;
      _firebaseInitialized = true;
    } catch (e) {
      _firebaseInitialized = false;
      debugPrint('Firebase not available in this context: $e');
    }
  }

  PrayerSettings? get prayerSettings => _prayerSettings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isCalculating => _isCalculating;

  // Initialize with masjidId
  void setMasjidId(String masjidId) {
    final trimmed = masjidId.trim();
    if (trimmed.isEmpty) {
      _masjidId = null;
      _prayerSettings = null;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (_masjidId == trimmed) return;
    _masjidId = trimmed;
    _loadPrayerSettings();
  }

  bool _ensureReady() {
    if (_masjidId == null || _prayerSettings == null) {
      _errorMessage = 'Masjid not loaded yet. Please wait for sign-in to finish.';
      notifyListeners();
      return false;
    }
    return true;
  }

  // Load prayer settings from Firestore
  Future<void> _loadPrayerSettings() async {
    if (_masjidId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      if (!_firebaseInitialized) {
        throw Exception('Firebase not initialized');
      }
      
      final doc = await _firestore.collection('masjids').doc(_masjidId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _prayerSettings = PrayerSettings.fromFirestore(data, _masjidId!);
        
        // Also save to local storage for offline access
        await _saveToLocalStorage();
      } else {
        // Create default settings if masjid doesn't exist
        _createDefaultSettings();
      }
    } catch (e) {
      _errorMessage = 'Failed to load prayer settings: $e';
      // Try to load from local storage
      await _loadFromLocalStorage();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save to local storage
  Future<void> _saveToLocalStorage() async {
    if (_prayerSettings == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert to a JSON-serializable format without Timestamp
      final firebaseData = _prayerSettings!.toFirestore();
      final serializableData = Map<String, dynamic>.from(firebaseData);
      
      // Remove the timestamp as it's not JSON serializable
      serializableData.remove('lastUpdated');
      
      final jsonString = jsonEncode(serializableData);
      await prefs.setString('prayerSettings_$_masjidId', jsonString);
      debugPrint('✅ Saved to local storage');
    } catch (e) {
      debugPrint('❌ Error saving to local storage: $e');
    }
  }

  // Load from local storage
  Future<void> _loadFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('prayerSettings_$_masjidId');
    
    if (jsonString != null) {
      try {
        final data = jsonDecode(jsonString);
        _prayerSettings = PrayerSettings.fromFirestore(data, _masjidId!);
      } catch (e) {
        _createDefaultSettings();
      }
    } else {
      _createDefaultSettings();
    }
  }

  // Create default settings
  void _createDefaultSettings() {
    final defaultPrayerTimes = <String, PrayerTime>{
      'Fajr': PrayerTime(adhan: '05:00', iqamah: '05:15', delay: 15),
      'Dhuhr': PrayerTime(adhan: '12:30', iqamah: '13:00', delay: 30),
      'Asr': PrayerTime(adhan: '15:45', iqamah: '16:00', delay: 15),
      'Maghrib': PrayerTime(adhan: '18:30', iqamah: '18:35', delay: 5),
      'Isha': PrayerTime(adhan: '20:00', iqamah: '20:15', delay: 15),
    };

    _prayerSettings = PrayerSettings(
      masjidId: _masjidId ?? '',
      prayerTimes: defaultPrayerTimes,
      calculationSettings: CalculationSettings(),
      location: LocationSettings(
        latitude: 0.0,
        longitude: 0.0,
        city: '',
        country: '',
      ),
      iqamahUseDelay: {
        for (final key in defaultPrayerTimes.keys) key: true,
      },
      jumuahTimes: const ['13:30', '13:30'],
      specialTimes: const SpecialTimes(),
      prayerTimeOverrides: const {},
      lastUpdated: DateTime.now(),
    );
  }

  Future<void> updateIqamahMode(String prayerName, bool useDelay) async {
    if (!_ensureReady()) return;

    final updatedMap = Map<String, bool>.from(_prayerSettings!.iqamahUseDelay);
    updatedMap[prayerName] = useDelay;

    // If switching to delay mode, ensure iqamah is computed from adhan + delay.
    Map<String, PrayerTime>? updatedPrayerTimes;
    if (useDelay) {
      final current = _prayerSettings!.prayerTimes[prayerName];
      if (current != null) {
        updatedPrayerTimes = Map<String, PrayerTime>.from(_prayerSettings!.prayerTimes);
        final computedIqamah = PrayerApiService.calculateIqamah(current.adhan, current.delay);
        updatedPrayerTimes[prayerName] = current.copyWith(iqamah: computedIqamah);
      }
    }

    _prayerSettings = _prayerSettings!.copyWith(
      iqamahUseDelay: updatedMap,
      prayerTimes: updatedPrayerTimes ?? _prayerSettings!.prayerTimes,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> updateJumuahTimes(List<String> times) async {
    if (!_ensureReady()) return;

    _prayerSettings = _prayerSettings!.copyWith(
      jumuahTimes: List<String>.from(times),
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> updateSpecialTimes(SpecialTimes times) async {
    if (!_ensureReady()) return;

    _prayerSettings = _prayerSettings!.copyWith(
      specialTimes: times,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  Future<void> updatePrayerOverrides(Map<String, PrayerTimeOverride> overrides) async {
    if (!_ensureReady()) return;

    _prayerSettings = _prayerSettings!.copyWith(
      prayerTimeOverrides: overrides,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  // Calculate prayer times automatically using API
  Future<void> calculatePrayerTimes() async {
    if (!_ensureReady()) return;
    if (_prayerSettings!.location.latitude == 0.0 && 
        _prayerSettings!.location.longitude == 0.0 &&
        _prayerSettings!.location.city.isEmpty) {
      _errorMessage = 'Please set location first';
      notifyListeners();
      return;
    }

    _isCalculating = true;
    notifyListeners();

    try {
      Map<String, String> apiTimes;
      
      debugPrint('🔄 Fetching prayer times with method: ${_prayerSettings!.calculationSettings.method}');
      debugPrint('📍 Location: ${_prayerSettings!.location.city}, ${_prayerSettings!.location.country}');
      
      if (_prayerSettings!.location.latitude != 0.0 && 
          _prayerSettings!.location.longitude != 0.0) {
        // Use coordinates
        debugPrint('Using coordinates: ${_prayerSettings!.location.latitude}, ${_prayerSettings!.location.longitude}');
        apiTimes = await PrayerApiService.getPrayerTimesByCoordinates(
          latitude: _prayerSettings!.location.latitude,
          longitude: _prayerSettings!.location.longitude,
          method: _prayerSettings!.calculationSettings.method,
          school: _prayerSettings!.calculationSettings.asrMethod,
          adjustmentMethod: _prayerSettings!.calculationSettings.adjustmentMethod,
          adjustment: _prayerSettings!.calculationSettings.adjustmentMinutes,
        );
      } else {
        // Use city/country
        debugPrint('Using city/country');
        apiTimes = await PrayerApiService.getPrayerTimesByCity(
          city: _prayerSettings!.location.city,
          country: _prayerSettings!.location.country,
          method: _prayerSettings!.calculationSettings.method,
          school: _prayerSettings!.calculationSettings.asrMethod,
          adjustmentMethod: _prayerSettings!.calculationSettings.adjustmentMethod,
          adjustment: _prayerSettings!.calculationSettings.adjustmentMinutes,
        );
      }

      debugPrint('✅ API Response: $apiTimes');

      // Update prayer times with API results
      final updatedPrayerTimes = Map<String, PrayerTime>.from(_prayerSettings!.prayerTimes);
      
      apiTimes.forEach((prayerName, adhanTime) {
        // Convert from 12-hour to 24-hour format if needed
        final adhan24h = PrayerApiService.convertTo24Hour(adhanTime);
        debugPrint('📿 $prayerName: $adhanTime → $adhan24h');
        
        if (updatedPrayerTimes.containsKey(prayerName)) {
          final current = updatedPrayerTimes[prayerName]!;
          final useDelay = _prayerSettings!.iqamahUseDelay[prayerName] ?? true;
          final iqamah = useDelay
              ? PrayerApiService.calculateIqamah(adhan24h, current.delay)
              : current.iqamah;
          debugPrint(
            useDelay
                ? '   Iqamah (delay ${current.delay}min): $iqamah'
                : '   Iqamah (fixed): $iqamah',
          );
          
          updatedPrayerTimes[prayerName] = current.copyWith(
            adhan: adhan24h,
            iqamah: iqamah,
          );
        }
      });

      _prayerSettings = _prayerSettings!.copyWith(
        prayerTimes: updatedPrayerTimes,
        lastUpdated: DateTime.now(),
      );

      debugPrint('💾 Saving updated prayer times...');
      await _saveToFirestore();
      await _saveToLocalStorage();
      
      _errorMessage = null;
      debugPrint('🎉 Prayer times updated successfully!');
    } catch (e) {
      _errorMessage = 'Failed to calculate prayer times: $e';
      debugPrint('❌ Error calculating prayer times: $e');
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  // Update a specific prayer time
  Future<void> updatePrayerTime(String prayerName, PrayerTime newTime) async {
    if (!_ensureReady()) return;

    final updatedPrayerTimes = Map<String, PrayerTime>.from(_prayerSettings!.prayerTimes);

    final useDelay = _prayerSettings!.iqamahUseDelay[prayerName] ?? true;
    final updatedTime = useDelay
        ? newTime.copyWith(iqamah: PrayerApiService.calculateIqamah(newTime.adhan, newTime.delay))
        : newTime;

    updatedPrayerTimes[prayerName] = updatedTime;
    
    _prayerSettings = _prayerSettings!.copyWith(
      prayerTimes: updatedPrayerTimes,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  // Update calculation settings
  Future<void> updateCalculationSettings(CalculationSettings newSettings) async {
    if (!_ensureReady()) return;

    _prayerSettings = _prayerSettings!.copyWith(
      calculationSettings: newSettings,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  // Update location settings
  Future<void> updateLocationSettings(LocationSettings newLocation) async {
    if (!_ensureReady()) return;

    _prayerSettings = _prayerSettings!.copyWith(
      location: newLocation,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  /// Save the full prayer times map + iqamah mode map in one Firestore write.
  /// This avoids "cursor jump" glitches caused by saving on every keystroke.
  Future<void> savePrayerTimesBulk({
    required Map<String, PrayerTime> prayerTimes,
    required Map<String, bool> iqamahUseDelay,
  }) async {
    if (!_ensureReady()) return;

    final normalizedUseDelay = Map<String, bool>.from(iqamahUseDelay);
    final updatedPrayerTimes = <String, PrayerTime>{};
    for (final entry in prayerTimes.entries) {
      final prayerName = entry.key;
      final time = entry.value;
      final useDelay = normalizedUseDelay[prayerName] ?? (_prayerSettings!.iqamahUseDelay[prayerName] ?? true);
      updatedPrayerTimes[prayerName] = useDelay
          ? time.copyWith(iqamah: PrayerApiService.calculateIqamah(time.adhan, time.delay))
          : time;
    }

    _prayerSettings = _prayerSettings!.copyWith(
      prayerTimes: updatedPrayerTimes,
      iqamahUseDelay: normalizedUseDelay,
      lastUpdated: DateTime.now(),
    );

    await _saveToFirestore();
    await _saveToLocalStorage();
    notifyListeners();
  }

  // Save to Firestore
  Future<void> _saveToFirestore() async {
    if (_prayerSettings == null || _masjidId == null || !_firebaseInitialized) {
      debugPrint('⚠️ Cannot save to Firestore: prayerSettings=$_prayerSettings, masjidId=$_masjidId, firebaseInit=$_firebaseInitialized');
      return;
    }

    try {
      debugPrint('💾 Saving prayer settings to Firestore for masjid: $_masjidId');
      final data = _prayerSettings!.toFirestore();
      debugPrint('📤 Data to save: Prayer times - ${_prayerSettings!.prayerTimes.keys.join(", ")}');
      
      // Use set with merge: true to create document if it doesn't exist, or update if it does
      await _firestore
          .collection('masjids')
          .doc(_masjidId)
          .set(data, SetOptions(merge: true));
      
      debugPrint('✅ Successfully saved to Firestore!');
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to save to database: $e';
      debugPrint('❌ Firebase save error: $e');
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
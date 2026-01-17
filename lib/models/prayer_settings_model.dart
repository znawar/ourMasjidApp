import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerSettings {
  final String masjidId;
  final Map<String, PrayerTime> prayerTimes;
  final CalculationSettings calculationSettings;
  final LocationSettings location;
  // Whether each prayer's iqamah is defined as a delay after adhan (true) or a fixed time (false).
  // This is UI/state only; calculation logic can still use `delay`.
  final Map<String, bool> iqamahUseDelay;

  // Optional fields used by the admin UI for Masjidbox-style screens.
  // These are stored in Firestore but are intentionally not used by calculation logic.
  final List<String> jumuahTimes;
  final SpecialTimes specialTimes;
  final Map<String, PrayerTimeOverride> prayerTimeOverrides;
  final DateTime lastUpdated;

  PrayerSettings({
    required this.masjidId,
    required this.prayerTimes,
    required this.calculationSettings,
    required this.location,
    required this.iqamahUseDelay,
    required this.jumuahTimes,
    required this.specialTimes,
    required this.prayerTimeOverrides,
    required this.lastUpdated,
  });

  factory PrayerSettings.fromFirestore(
      Map<String, dynamic> data, String masjidId) {
    final prayerTimesMap = (data['prayerTimes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, PrayerTime.fromMap(value)),
    );

    final rawIqamahUseDelay = data['iqamahUseDelay'];
    final iqamahUseDelay = <String, bool>{
      for (final key in prayerTimesMap.keys) key: true,
    };
    if (rawIqamahUseDelay is Map) {
      rawIqamahUseDelay.forEach((key, value) {
        if (key is String) {
          iqamahUseDelay[key] = value == true;
        }
      });
    }

    final rawJumuahTimes = data['jumuahTimes'];
    final jumuahTimes = <String>[];
    if (rawJumuahTimes is List) {
      for (final item in rawJumuahTimes) {
        if (item is String) jumuahTimes.add(item);
      }
    }

    final rawSpecialTimes = data['specialTimes'];
    final specialTimes = rawSpecialTimes is Map<String, dynamic>
        ? SpecialTimes.fromMap(rawSpecialTimes)
        : const SpecialTimes();

    final rawOverrides = data['prayerTimeOverrides'];
    final overrides = <String, PrayerTimeOverride>{};
    if (rawOverrides is Map) {
      rawOverrides.forEach((key, value) {
        if (key is String && value is Map<String, dynamic>) {
          overrides[key] = PrayerTimeOverride.fromMap(value);
        }
      });
    }

    return PrayerSettings(
      masjidId: masjidId,
      prayerTimes: prayerTimesMap,
      calculationSettings:
          CalculationSettings.fromMap(data['calculationSettings'] ?? {}),
      location: LocationSettings.fromMap(
        data['location'] as Map<String, dynamic>?,
        data,
      ),
      iqamahUseDelay: iqamahUseDelay,
      jumuahTimes: jumuahTimes,
      specialTimes: specialTimes,
      prayerTimeOverrides: overrides,
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final prayerTimesMap = prayerTimes.map(
      (key, value) => MapEntry(key, value.toMap()),
    );

    return {
      'masjidId': masjidId,
      'prayerTimes': prayerTimesMap,
      'calculationSettings': calculationSettings.toMap(),
      'location': location.toMap(),
      'iqamahUseDelay': iqamahUseDelay,
      'jumuahTimes': jumuahTimes,
      'specialTimes': specialTimes.toMap(),
      'prayerTimeOverrides':
          prayerTimeOverrides.map((k, v) => MapEntry(k, v.toMap())),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  PrayerSettings copyWith({
    String? masjidId,
    Map<String, PrayerTime>? prayerTimes,
    CalculationSettings? calculationSettings,
    LocationSettings? location,
    Map<String, bool>? iqamahUseDelay,
    List<String>? jumuahTimes,
    SpecialTimes? specialTimes,
    Map<String, PrayerTimeOverride>? prayerTimeOverrides,
    DateTime? lastUpdated,
  }) {
    return PrayerSettings(
      masjidId: masjidId ?? this.masjidId,
      prayerTimes: prayerTimes ?? this.prayerTimes,
      calculationSettings: calculationSettings ?? this.calculationSettings,
      location: location ?? this.location,
      iqamahUseDelay: iqamahUseDelay ?? this.iqamahUseDelay,
      jumuahTimes: jumuahTimes ?? this.jumuahTimes,
      specialTimes: specialTimes ?? this.specialTimes,
      prayerTimeOverrides: prayerTimeOverrides ?? this.prayerTimeOverrides,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class SpecialTimes {
  final int imsakOffsetMinutes; // relative to Fajr
  final int iftarOffsetMinutes; // relative to Maghrib
  final int taraweehOffsetMinutes; // relative to Isha
  final bool ramadanModeEnabled;
  final bool
      useManualRamadanTimes; // true = use manual suhoor/iftar times, false = use calculated times
  final String? suhoorEndTime; // HH:mm format - when Suhoor ends (manual)
  final String? iftarTime; // HH:mm format - when Iftar starts (manual)

  const SpecialTimes({
    this.imsakOffsetMinutes = -15,
    this.iftarOffsetMinutes = 0,
    this.taraweehOffsetMinutes = 0,
    this.ramadanModeEnabled = false,
    this.useManualRamadanTimes = false,
    this.suhoorEndTime,
    this.iftarTime,
  });

  factory SpecialTimes.fromMap(Map<String, dynamic> map) {
    return SpecialTimes(
      imsakOffsetMinutes: map['imsakOffsetMinutes'] is int
          ? map['imsakOffsetMinutes'] as int
          : -15,
      iftarOffsetMinutes: map['iftarOffsetMinutes'] is int
          ? map['iftarOffsetMinutes'] as int
          : 0,
      taraweehOffsetMinutes: map['taraweehOffsetMinutes'] is int
          ? map['taraweehOffsetMinutes'] as int
          : 0,
      ramadanModeEnabled: map['ramadanModeEnabled'] == true,
      useManualRamadanTimes: map['useManualRamadanTimes'] == true,
      suhoorEndTime: map['suhoorEndTime'] is String
          ? map['suhoorEndTime'] as String
          : null,
      iftarTime: map['iftarTime'] is String ? map['iftarTime'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imsakOffsetMinutes': imsakOffsetMinutes,
      'iftarOffsetMinutes': iftarOffsetMinutes,
      'taraweehOffsetMinutes': taraweehOffsetMinutes,
      'ramadanModeEnabled': ramadanModeEnabled,
      'useManualRamadanTimes': useManualRamadanTimes,
      if (suhoorEndTime != null) 'suhoorEndTime': suhoorEndTime,
      if (iftarTime != null) 'iftarTime': iftarTime,
    };
  }

  SpecialTimes copyWith({
    int? imsakOffsetMinutes,
    int? iftarOffsetMinutes,
    int? taraweehOffsetMinutes,
    bool? ramadanModeEnabled,
    bool? useManualRamadanTimes,
    String? suhoorEndTime,
    String? iftarTime,
  }) {
    return SpecialTimes(
      imsakOffsetMinutes: imsakOffsetMinutes ?? this.imsakOffsetMinutes,
      iftarOffsetMinutes: iftarOffsetMinutes ?? this.iftarOffsetMinutes,
      taraweehOffsetMinutes:
          taraweehOffsetMinutes ?? this.taraweehOffsetMinutes,
      ramadanModeEnabled: ramadanModeEnabled ?? this.ramadanModeEnabled,
      useManualRamadanTimes:
          useManualRamadanTimes ?? this.useManualRamadanTimes,
      suhoorEndTime: suhoorEndTime ?? this.suhoorEndTime,
      iftarTime: iftarTime ?? this.iftarTime,
    );
  }
}

class PrayerTimeOverride {
  final String? minTime; // HH:mm
  final String? maxTime; // HH:mm

  const PrayerTimeOverride({
    this.minTime,
    this.maxTime,
  });

  factory PrayerTimeOverride.fromMap(Map<String, dynamic> map) {
    final min = map['minTime'];
    final max = map['maxTime'];
    return PrayerTimeOverride(
      minTime: min is String && min.trim().isNotEmpty ? min : null,
      maxTime: max is String && max.trim().isNotEmpty ? max : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minTime': minTime,
      'maxTime': maxTime,
    };
  }

  PrayerTimeOverride copyWith({
    String? minTime,
    String? maxTime,
  }) {
    return PrayerTimeOverride(
      minTime: minTime ?? this.minTime,
      maxTime: maxTime ?? this.maxTime,
    );
  }
}

class PrayerTime {
  final String adhan;
  final String iqamah;
  final int delay; // in minutes

  PrayerTime({
    required this.adhan,
    required this.iqamah,
    required this.delay,
  });

  factory PrayerTime.fromMap(Map<String, dynamic> map) {
    return PrayerTime(
      adhan: map['adhan'] ?? '05:00',
      iqamah: map['iqamah'] ?? '05:15',
      delay: map['delay'] ?? 15,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adhan': adhan,
      'iqamah': iqamah,
      'delay': delay,
    };
  }

  PrayerTime copyWith({
    String? adhan,
    String? iqamah,
    int? delay,
  }) {
    return PrayerTime(
      adhan: adhan ?? this.adhan,
      iqamah: iqamah ?? this.iqamah,
      delay: delay ?? this.delay,
    );
  }
}

class CalculationSettings {
  final String method;
  final String asrMethod; // Shafi or Hanafi
  final String highLatitudeRule;
  final String adjustmentMethod;
  final bool useAutoCalculation;
  final int adjustmentMinutes;

  CalculationSettings({
    this.method = 'MWL',
    this.asrMethod = 'Shafi',
    this.highLatitudeRule = 'AngleBased',
    this.adjustmentMethod = 'AngleBased',
    this.useAutoCalculation = false,
    this.adjustmentMinutes = 0,
  });

  factory CalculationSettings.fromMap(Map<String, dynamic> map) {
    return CalculationSettings(
      method: map['method'] ?? 'MWL',
      asrMethod: map['asrMethod'] ?? 'Shafi',
      highLatitudeRule: map['highLatitudeRule'] ?? 'AngleBased',
      adjustmentMethod: map['adjustmentMethod'] ?? 'AngleBased',
      useAutoCalculation: map['useAutoCalculation'] ?? false,
      adjustmentMinutes: map['adjustmentMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'asrMethod': asrMethod,
      'highLatitudeRule': highLatitudeRule,
      'adjustmentMethod': adjustmentMethod,
      'useAutoCalculation': useAutoCalculation,
      'adjustmentMinutes': adjustmentMinutes,
    };
  }

  CalculationSettings copyWith({
    String? method,
    String? asrMethod,
    String? highLatitudeRule,
    String? adjustmentMethod,
    bool? useAutoCalculation,
    int? adjustmentMinutes,
  }) {
    return CalculationSettings(
      method: method ?? this.method,
      asrMethod: asrMethod ?? this.asrMethod,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      adjustmentMethod: adjustmentMethod ?? this.adjustmentMethod,
      useAutoCalculation: useAutoCalculation ?? this.useAutoCalculation,
      adjustmentMinutes: adjustmentMinutes ?? this.adjustmentMinutes,
    );
  }
}

class LocationSettings {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final String timezone;

  LocationSettings({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    this.timezone = 'Auto',
  });

  factory LocationSettings.fromMap(Map<String, dynamic>? map, [Map<String, dynamic>? topLevelData]) {
    // If we have a location map, use it as primary
    if (map != null) {
      return LocationSettings(
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        city: map['city']?.toString() ?? '',
        country: map['country']?.toString() ?? '',
        timezone: map['timezone']?.toString() ?? 
                 map['timeZone']?.toString() ?? 
                 map['tz']?.toString() ?? 'Auto',
      );
    }
    
    // Fallback to top-level data if location map is missing (legacy/flat format)
    if (topLevelData != null) {
      return LocationSettings(
        latitude: (topLevelData['latitude'] as num? ?? topLevelData['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (topLevelData['longitude'] as num? ?? topLevelData['lon'] as num?)?.toDouble() ?? 0.0,
        city: topLevelData['city']?.toString() ?? 
              topLevelData['masjidCity']?.toString() ?? '',
        country: topLevelData['country']?.toString() ?? 
                 topLevelData['masjidCountry']?.toString() ?? '',
        timezone: topLevelData['timezone']?.toString() ?? 
                 topLevelData['timeZone']?.toString() ?? 
                 topLevelData['tz']?.toString() ?? 'Auto',
      );
    }

    return LocationSettings(
      latitude: 0.0,
      longitude: 0.0,
      city: '',
      country: '',
      timezone: 'Auto',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'country': country,
      'timezone': timezone,
    };
  }

  LocationSettings copyWith({
    double? latitude,
    double? longitude,
    String? city,
    String? country,
    String? timezone,
  }) {
    return LocationSettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
    );
  }
}

// Add to prayer_settings_model.dart
extension CalculationSettingsCopyWithExtension on CalculationSettings {
  CalculationSettings copyWith({
    String? method,
    String? asrMethod,
    String? highLatitudeRule,
    String? adjustmentMethod,
    bool? useAutoCalculation,
    int? adjustmentMinutes,
  }) {
    return CalculationSettings(
      method: method ?? this.method,
      asrMethod: asrMethod ?? this.asrMethod,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      adjustmentMethod: adjustmentMethod ?? this.adjustmentMethod,
      useAutoCalculation: useAutoCalculation ?? this.useAutoCalculation,
      adjustmentMinutes: adjustmentMinutes ?? this.adjustmentMinutes,
    );
  }
}

extension LocationSettingsCopyWithExtension on LocationSettings {
  LocationSettings copyWith({
    double? latitude,
    double? longitude,
    String? city,
    String? country,
    String? timezone,
  }) {
    return LocationSettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      city: city ?? this.city,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
    );
  }
}

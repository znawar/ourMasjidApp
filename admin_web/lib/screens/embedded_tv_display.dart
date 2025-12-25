import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _currentPrayerForIqamah;

  // Firebase data
  List<Map<String, dynamic>> firebaseAnnouncements = [];
  Map<String, dynamic> firebasePrayerTimes = {};
  Map<String, Map<String, String>> _currentPrayerTimes = {};
  bool isLoadingFirebase = true;

  String? _masjidName;
  bool _announcementsUsingFallback = false;

  late FirebaseFirestore firestore;
  StreamSubscription? _announcementsSub;
  StreamSubscription? _prayerTimesSub;

  static const String _tvMasjidIdStorageKey = 'tvMasjidId';

  String? _resolvedMasjidId;

  @override
  void initState() {
    super.initState();
    Wakelock.enable().catchError((e) {});

    _resolvedMasjidId = (widget.masjidId?.trim().isNotEmpty ?? false)
        ? widget.masjidId!.trim()
        : null;

    _initializeFirebase();
    _startClock();
    _calculateNextPrayer();
    _checkCurrentPrayerTimes();
  }

  Future<void> _initializeFirebase() async {
    try {
      firestore = FirebaseFirestore.instance;

      if (_resolvedMasjidId == null) {
        final prefs = await SharedPreferences.getInstance();
        final saved = (prefs.getString(_tvMasjidIdStorageKey) ?? '').trim();
        if (saved.isNotEmpty) {
          _resolvedMasjidId = saved;
        }
      }

      _listenToAnnouncements();
      _listenToPrayerTimes();
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  void _listenToAnnouncements() {
    _announcementsSub?.cancel();

    final String? masjidId = _resolvedMasjidId;
    _announcementsUsingFallback = false;

    // Query by masjidId first, then filter active in-memory to avoid compound index requirement
    Query<Map<String, dynamic>> query =
        firestore.collection('announcements');

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
          .listen((doc) {
        final data = doc.data();
        if (data == null) return;
        setState(() {
          firebasePrayerTimes = data;
          final name =
              (data['masjidName'] ?? data['name'] ?? '').toString().trim();
          _masjidName = name.isEmpty ? _masjidName : name;
          _currentPrayerTimes = _extractPrayerTimes(data);
          isLoadingFirebase = false;
          _calculateNextPrayer();
          _checkCurrentPrayerTimes();
        });
      });
      return;
    }

    _prayerTimesSub =
        firestore.collection('masjids').limit(1).snapshots().listen((snapshot) {
      if (snapshot.docs.isEmpty) return;
      final doc = snapshot.docs.first;
      final data = doc.data();
      setState(() {
        firebasePrayerTimes = data;
        final name =
            (data['masjidName'] ?? data['name'] ?? '').toString().trim();
        _masjidName = name.isEmpty ? _masjidName : name;
        _currentPrayerTimes = _extractPrayerTimes(data);
        isLoadingFirebase = false;
        _calculateNextPrayer();
        _checkCurrentPrayerTimes();
      });
    });
  }

  Map<String, Map<String, String>> _extractPrayerTimes(
      Map<String, dynamic> data) {
    final result = <String, Map<String, String>>{};

    final dynamic raw =
        data['prayerTimes'] ?? data['prayer_times'] ?? data['times'];

    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is! String) return;
        if (value is Map) {
          final adhan = (value['adhan'] ?? value['azan'] ?? '').toString();
          final iqamah = (value['iqamah'] ?? value['iqama'] ?? '').toString();
          result[key] = {
            'adhan': adhan,
            'iqamah': iqamah,
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
        final adhan =
            item['adhan']?.toString() ?? item['azan']?.toString() ?? '';
        final iqamah =
            item['iqamah']?.toString() ?? item['iqama']?.toString() ?? '';
        result[name] = {
          'adhan': adhan,
          'iqamah': iqamah,
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
      setState(() {
        now = DateTime.now();
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
    bool foundAdhan = false;

    source.forEach((prayerName, times) {
      final adhanTime = _parseTimeToDateTime(times['adhan'] ?? '', now);
      final iqamahTime = _parseTimeToDateTime(times['iqamah'] ?? '', now);

      if (adhanTime != null) {
        // Check if current time is within 20 minutes after adhan
        final adhanEndTime = adhanTime.add(const Duration(minutes: 20));
        if (now.isAfter(adhanTime) && now.isBefore(adhanEndTime)) {
          foundAdhan = true;
          currentPrayerName = prayerName;
          _currentPrayerForIqamah = prayerName;
          
          // Calculate time until iqamah
          if (iqamahTime != null) {
            if (now.isBefore(iqamahTime)) {
              iqamahCountdown = iqamahTime.difference(now);
              isIqamahTime = false;
              showIqamahStarted = false;
            } else {
              // Check if within 20 minutes after iqamah
              final iqamahEndTime = iqamahTime.add(const Duration(minutes: 20));
              if (now.isBefore(iqamahEndTime)) {
                isIqamahTime = true;
                showIqamahStarted = true;
                iqamahCountdown = Duration.zero;
                
                // Start timer to hide iqamah message after 20 minutes
                _iqamahTimer?.cancel();
                _iqamahTimer = Timer(iqamahEndTime.difference(now), () {
                  if (mounted) {
                    setState(() {
                      showIqamahStarted = false;
                      isIqamahTime = false;
                    });
                  }
                });
              } else {
                isIqamahTime = false;
                showIqamahStarted = false;
              }
            }
          }
        }
      }
    });

    setState(() {
      isAdhanTime = foundAdhan;
    });
  }

  void _calculateNextPrayer() {
    final today = now;
    DateTime? nextTime;
    String nextName = '';

    final source = _currentPrayerTimes.isNotEmpty
        ? _currentPrayerTimes
        : (widget.prayerTimes ?? const {});
    source.forEach((name, times) {
      final adhan = (times['adhan'] ?? '--:--').toString().trim();
      final parsed = _parseTimeToDateTime(adhan, today);
      if (parsed == null) return;
      var time = parsed;
      if (time.isBefore(now)) time = time.add(const Duration(days: 1));
      if (nextTime == null || time.isBefore(nextTime!)) {
        nextTime = time;
        nextName = name;
      }
    });

    if (nextTime != null) {
      nextPrayerName = nextName;
      nextPrayerCountdown = nextTime!.difference(now);
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

    if (parsed == null) {
      if (!value.contains(':')) return null;
      final parts = value.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute =
          int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;
      if (hour < 0 || minute < 0 || hour > 23 || minute > 59) return null;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    return DateTime(
        base.year, base.month, base.day, parsed.hour, parsed.minute);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  bool _isRamadanModeEnabled() {
    final specialTimes = firebasePrayerTimes['specialTimes'];
    if (specialTimes is Map) {
      return specialTimes['ramadanModeEnabled'] == true;
    }
    return false;
  }

  String _getSuhoorEndTime() {
    final specialTimes = firebasePrayerTimes['specialTimes'];
    if (specialTimes is Map) {
      final time = specialTimes['suhoorEndTime'];
      if (time is String && time.isNotEmpty) {
        return time;
      }
    }
    return '--:--';
  }

  String _getIftarTime() {
    final specialTimes = firebasePrayerTimes['specialTimes'];
    if (specialTimes is Map) {
      final time = specialTimes['iftarTime'];
      if (time is String && time.isNotEmpty) {
        return time;
      }
    }
    return '--:--';
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
      return Center(
        child: Text(
          isLoadingFirebase
              ? 'Loading prayer times...'
              : 'No prayer times configured',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }

    // Define the correct prayer order
    const prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    // Create ordered list of prayer entries
    final orderedEntries = <MapEntry<String, Map<String, String>>>[];
    for (final prayerName in prayerOrder) {
      // Try exact match first, then case-insensitive
      final entry = prayerList.entries.firstWhere(
        (e) => e.key == prayerName,
        orElse: () => prayerList.entries.firstWhere(
          (e) => e.key.toLowerCase() == prayerName.toLowerCase(),
          orElse: () => MapEntry('', <String, String>{}),
        ),
      );
      if (entry.key.isNotEmpty) {
        orderedEntries.add(entry);
      }
    }
    
    // Add any remaining prayers not in the standard order
    for (final entry in prayerList.entries) {
      final alreadyAdded = orderedEntries.any(
        (e) => e.key.toLowerCase() == entry.key.toLowerCase(),
      );
      if (!alreadyAdded) {
        orderedEntries.add(entry);
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;
    
    return Container(
      height: 85,
      child: Row(
        children: orderedEntries.map((entry) {
          final bool isNextPrayer = nextPrayerName.toLowerCase() == entry.key.toLowerCase();
          final bool isCurrentPrayer = currentPrayerName.toLowerCase() == entry.key.toLowerCase();
          
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: isNextPrayer 
                  ? Colors.green
                  : isCurrentPrayer && (isAdhanTime || isIqamahTime)
                    ? Colors.orange
                    : const Color(0xFF1976D2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isNextPrayer 
                      ? Colors.green.withOpacity(0.7)
                      : Colors.black.withOpacity(0.4),
                    blurRadius: isNextPrayer ? 15 : 8,
                    spreadRadius: isNextPrayer ? 2 : 1,
                    offset: Offset(0, isNextPrayer ? 3 : 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Center(
                      child: isSmallScreen
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  entry.key,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.value['adhan'] ?? '--:--',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Iqamah: ${entry.value['iqamah'] ?? '--:--'}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                              ],
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    entry.key,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontFamily: 'Roboto',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ADHAN',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                      Text(
                                        entry.value['adhan'] ?? '--:--',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontFamily: 'RobotoMono',
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'IQAMAH',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                          fontFamily: 'Roboto',
                                        ),
                                      ),
                                      Text(
                                        entry.value['iqamah'] ?? '--:--',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontFamily: 'RobotoMono',
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ),
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
    if (showIqamahStarted) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mosque,
                size: 120,
                color: Colors.green,
              ),
              const SizedBox(height: 40),
              Text(
                'IQAMAH HAS STARTED',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                  fontFamily: 'Roboto',
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'FOR $_currentPrayerForIqamah',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Text(
                  'PLEASE JOIN THE CONGREGATION',
                  style: TextStyle(
                    fontSize: 24,
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

    if (isAdhanTime && !isIqamahTime) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_filled,
                size: 120,
                color: Colors.amber,
              ),
              const SizedBox(height: 40),
              Text(
                'IQAMAH',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.amber,
                  fontFamily: 'Roboto',
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'For $currentPrayerName',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _formatDuration(iqamahCountdown),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'RobotoMono',
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'PLEASE PREPARE FOR PRAYER',
                style: TextStyle(
                  fontSize: 20,
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
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
    final timeStr = DateFormat.Hms().format(now);
    final dayStr = DateFormat.EEEE().format(now);
    final monthDateStr = DateFormat.yMMMMd().format(now);
    final hijriStr = _getHijriDate(now);

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
                  child: (isAdhanTime || showIqamahStarted) && firebaseAnnouncements.isNotEmpty
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
                                          color: const Color(0xFF1976D2).withOpacity(0.5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                                nextPrayerName.isNotEmpty ? nextPrayerName.toUpperCase() : '--',
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
                          _buildRamadanTimeRow('SUHOOR ENDS', _getSuhoorEndTime()),
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

          Container(
            height: 85,
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
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: _buildPrayerTimesBar(),
          ),
        ],
      ),
    );
  }
}
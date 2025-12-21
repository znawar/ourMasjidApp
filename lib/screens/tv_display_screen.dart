import 'dart:async';
import 'dart:math';
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
  Duration nextPrayerCountdown = Duration.zero;

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

  // Pairing
  static const String _tvMasjidIdStorageKey = 'tvMasjidId';
  static const String _tvPairingCodeStorageKey = 'tvPairingCode';
  static const Duration _pairingExpiry = Duration(minutes: 10);
  StreamSubscription? _pairingSub;
  String? _pairingCode;
  bool _pairingActive = false;
  DateTime? _pairingExpiresAt;

  String? _resolvedMasjidId;

  @override
  void initState() {
    super.initState();
    // Wakelock may throw on some web/platform implementations (e.g. wakelock_web)
    // so call it and swallow async errors to avoid crashing the UI.
    Wakelock.enable().catchError((_) {});

    _resolvedMasjidId = (widget.masjidId?.trim().isNotEmpty ?? false)
        ? widget.masjidId!.trim()
        : null;
    // Allow passing masjidId via URL query param on web builds.
    try {
      final fromUrl = Uri.base.queryParameters['masjidId']?.trim();
      if ((fromUrl?.isNotEmpty ?? false) && _resolvedMasjidId == null) {
        _resolvedMasjidId = fromUrl;
      }
    } catch (_) {}

    _initializeFirebase();
    _startClock();
    _calculateNextPrayer();
  }

  Future<void> _initializeFirebase() async {
    try {
      firestore = FirebaseFirestore.instance;

      // Optional reset: open TV with ?mode=tv&reset=1 to clear persisted pairing.
      try {
        final reset = Uri.base.queryParameters['reset']?.toLowerCase().trim();
        if (reset == '1' || reset == 'true' || reset == 'yes') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_tvMasjidIdStorageKey);
          await prefs.remove(_tvPairingCodeStorageKey);
          _resolvedMasjidId = null;
        }
      } catch (_) {}

      // Persistent: if no URL/widget masjidId, try local storage.
      if (_resolvedMasjidId == null) {
        final prefs = await SharedPreferences.getInstance();
        final saved = (prefs.getString(_tvMasjidIdStorageKey) ?? '').trim();
        if (saved.isNotEmpty) {
          _resolvedMasjidId = saved;
        }
      }

      // Persist the resolved masjidId when present.
      if (_resolvedMasjidId != null && _resolvedMasjidId!.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tvMasjidIdStorageKey, _resolvedMasjidId!.trim());
        await prefs.remove(_tvPairingCodeStorageKey);
      }

      _listenToAnnouncements();
      _syncMasjidOrStartPairing();
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  void _syncMasjidOrStartPairing() {
    final current = _resolvedMasjidId;
    if (current != null && current.trim().isNotEmpty) {
      _pairingActive = false;
      _pairingSub?.cancel();
      _pairingSub = null;
      _pairingCode = null;
      _pairingExpiresAt = null;

      _listenToAnnouncements();
      _listenToPrayerTimes();
      return;
    }

    _startPairing();
  }

  Future<void> _startPairing() async {
    if (_pairingActive) return;
    _pairingActive = true;
    if (mounted) setState(() {});

    // Reuse a recent code if saved locally (refresh-safe).
    final prefs = await SharedPreferences.getInstance();
    final savedCode = (prefs.getString(_tvPairingCodeStorageKey) ?? '').trim();
    if (savedCode.length == 6) {
      _pairingCode = savedCode;
      _pairingExpiresAt = DateTime.now().add(_pairingExpiry);
      _listenForPairingClaim(savedCode);
      if (mounted) setState(() {});
      return;
    }

    final newCode = await _createUniquePairingCode();
    if (!mounted) return;

    _pairingCode = newCode;
    _pairingExpiresAt = DateTime.now().add(_pairingExpiry);
    await prefs.setString(_tvPairingCodeStorageKey, newCode);
    _listenForPairingClaim(newCode);
    setState(() {});
  }

  Future<String> _createUniquePairingCode() async {
    // The TV may not be authenticated, so Firestore writes might be blocked.
    // Generate a code locally; try to create the pairing doc, but don't depend on it.
    final code = _generatePairingCode();
    try {
      await firestore.collection('tv_pairs').doc(code).set({
        'code': code,
        'claimed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresInMinutes': _pairingExpiry.inMinutes,
      }, SetOptions(merge: true));
    } catch (_) {
      // Ignore; admin pairing can still create/claim the doc.
    }
    return code;
  }

  String _generatePairingCode() {
    final n = Random().nextInt(1000000);
    return n.toString().padLeft(6, '0');
  }

  void _listenForPairingClaim(String code) {
    _pairingSub?.cancel();
    _pairingSub =
        firestore.collection('tv_pairs').doc(code).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;
      final masjidId = (data['masjidId'] ?? '').toString().trim();
      if (masjidId.isEmpty) return;
      _setResolvedMasjidId(masjidId);
    });
  }

  Future<void> _setResolvedMasjidId(String masjidId) async {
    final trimmed = masjidId.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tvMasjidIdStorageKey, trimmed);
    await prefs.remove(_tvPairingCodeStorageKey);

    if (!mounted) return;
    setState(() {
      _resolvedMasjidId = trimmed;
      _pairingActive = false;
      _pairingCode = null;
      _pairingExpiresAt = null;
    });

    _pairingSub?.cancel();
    _pairingSub = null;
    _listenToPrayerTimes();
  }

  Future<void> _newPairingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tvPairingCodeStorageKey);
    if (!mounted) return;
    setState(() {
      _pairingActive = false;
      _pairingCode = null;
      _pairingExpiresAt = null;
    });
    await _startPairing();
  }

  void _listenToAnnouncements() {
    _announcementsSub?.cancel();

    final String? masjidId = _resolvedMasjidId;
    _announcementsUsingFallback = false;

    Query<Map<String, dynamic>> query =
        firestore.collection('announcements').where('active', isEqualTo: true);

    if (masjidId != null && masjidId.trim().isNotEmpty) {
      query = query.where('masjidId', isEqualTo: masjidId.trim());
    }

    _announcementsSub = query.snapshots().listen((snapshot) {
      final announcements = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        announcements.add(doc.data());
      }

      // Backward-compat: if no per-masjid announcements exist yet, fall back to
      // showing global active announcements so the TV isn't blank.
      if (announcements.isEmpty &&
          !_announcementsUsingFallback &&
          masjidId != null &&
          masjidId.trim().isNotEmpty) {
        _announcementsUsingFallback = true;
        _listenToAnnouncementsFallback();
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

  void _listenToAnnouncementsFallback() {
    _announcementsSub?.cancel();
    _announcementsSub = firestore
        .collection('announcements')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final announcements = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        announcements.add(doc.data());
      }
      if (!mounted) return;
      setState(() {
        firebaseAnnouncements = announcements;
        isLoadingFirebase = false;
      });
    });
  }

  void _listenToPrayerTimes() {
    _prayerTimesSub?.cancel();

    // Admin web saves prayer settings into `masjids/<masjidId>`.
    // Prefer a specific masjidId when provided.
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
        });
      });
      return;
    }

    // Fallback: pick the first masjid doc.
    if (_pairingActive) {
      setState(() {
        isLoadingFirebase = false;
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
      });
    });
  }

  Map<String, Map<String, String>> _extractPrayerTimes(
      Map<String, dynamic> data) {
    final result = <String, Map<String, String>>{};

    final dynamic raw =
        data['prayerTimes'] ?? data['prayer_times'] ?? data['times'];

    // New/expected shape from admin web:
    // prayerTimes: { "Fajr": {adhan, iqamah, delay}, ... }
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

    // Legacy shape (older TV code):
    // prayerTimes: [{name, adhan, iqamah}, ...]
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
    Wakelock.disable();
    _announcementsSub?.cancel();
    _prayerTimesSub?.cancel();
    _pairingSub?.cancel();
    // nothing to dispose for carousel here
    super.dispose();
  }

  Widget _buildPairingScreen() {
    final code = _pairingCode;
    final expiresAt = _pairingExpiresAt;
    final remaining =
        expiresAt == null ? null : expiresAt.difference(DateTime.now());
    final minutesLeft = remaining == null
        ? null
        : (remaining.inSeconds <= 0 ? 0 : (remaining.inSeconds / 60).ceil());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tv, size: 54, color: Color(0xFF1976D2)),
                      const SizedBox(height: 12),
                      const Text(
                        'Connect this TV',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'In Admin Web → Settings → TV Display Settings, enter this pairing code:',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF1976D2), width: 2),
                        ),
                        child: Text(
                          code ?? '------',
                          style: const TextStyle(
                            fontSize: 52,
                            letterSpacing: 6,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (minutesLeft != null)
                        Text(
                          'Expires in ~${minutesLeft} min',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _newPairingCode,
                        icon: const Icon(Icons.refresh),
                        label: const Text('New Code'),
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
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        now = DateTime.now();
        _calculateNextPrayer();
        // Keep only clock/timer updates here; carousel auto-play is handled by CarouselSlider options on web
      });
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
      // Last resort: try splitting HH:mm
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
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: prayerList.entries.map((entry) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: nextPrayerName == entry.key ? null : Colors.white,
              gradient: nextPrayerName == entry.key
                  ? const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2196F3),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.key,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: nextPrayerName == entry.key
                        ? Colors.white
                        : const Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.value['adhan'] ?? '--:--',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: nextPrayerName == entry.key
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.value['iqamah'] ?? '--:--',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: nextPrayerName == entry.key
                        ? Colors.white70
                        : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final timeStr = DateFormat.Hms().format(now);
    final dateStr = DateFormat.yMMMMEEEEd().format(now);
    final hijriStr = _getHijriDate(now);

    if ((_resolvedMasjidId == null || _resolvedMasjidId!.trim().isEmpty) &&
        _pairingActive) {
      return _buildPairingScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // 🟦 Top Bar - Compact
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mosque, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        (_masjidName == null || _masjidName!.trim().isEmpty)
                            ? 'Our Masjid App'
                            : _masjidName!.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🟩 Main Content - Maximized space for images
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 🕌 Announcements Section - Maximum space
                        Expanded(
                          flex: 8, // More space for images
                          child: Container(
                            margin: const EdgeInsets.only(right: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: firebaseAnnouncements.isEmpty
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            isLoadingFirebase
                                                ? 'Loading announcements...'
                                                : 'No announcements',
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 20),
                                          ),
                                        )
                                      : CarouselSlider.builder(
                                          itemCount:
                                              firebaseAnnouncements.length,
                                          itemBuilder:
                                              (context, index, realIndex) {
                                            final item =
                                                firebaseAnnouncements[index];
                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: Image.network(
                                                  item['imagePath'] ??
                                                      item['image'] ??
                                                      '',
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      alignment:
                                                          Alignment.center,
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 60,
                                                              color:
                                                                  Colors.grey),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            item['title'] ??
                                                                'Announcement',
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey[600],
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                          options: CarouselOptions(
                                            autoPlay: true,
                                            height: screenSize.height * 0.65,
                                            autoPlayInterval:
                                                const Duration(seconds: 5),
                                            enlargeCenterPage: true,
                                            viewportFraction: 0.625,
                                            aspectRatio: 16 / 9,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 🕒 Clock and Next Prayer Section - Compact but visible
                        Expanded(
                          flex: 2, // Less space for clock
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.access_time,
                                      size: 32, color: Color(0xFF2196F3)),
                                  const SizedBox(height: 8),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    hijriStr,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Next Prayer",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    nextPrayerName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color(0xFF2196F3),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'is in',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF2196F3),
                                              Color(0xFF1976D2)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.blue.withOpacity(0.18),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _formatDuration(nextPrayerCountdown),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 🟨 Bottom Prayer Times Bar - TV friendly (no scroll)
                Container(
                  height: 120.0,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  color: Colors.white,
                  child: _buildPrayerTimesBar(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

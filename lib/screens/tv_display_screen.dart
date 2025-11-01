import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';  

// Fallback no-op Wakelock implementation in case the wakelock package is not available.
// This prevents a missing package import from breaking compilation; if you later add
// the wakelock (or wakelock_plus) package to pubspec.yaml, you can remove this shim
// and import the real package instead.
class Wakelock {
  static Future<void> enable() async {}
  static Future<void> disable() async {}
}

class TVDisplayScreen extends StatefulWidget {
  final List<Map<String, String>> announcements;
  final Map<String, Map<String, String>> prayerTimes;

  const TVDisplayScreen({
    super.key,
    required this.announcements,
    required this.prayerTimes,
  });

  @override
  State<TVDisplayScreen> createState() => _TVDisplayScreenState();
}
String _getHijriDate(DateTime gregorianDate) {
    final DateTime referenceDate = DateTime(2025, 10, 31);
    final int referenceHijriDay = 9;
    final int referenceHijriMonth = 5;
    final int referenceHijriYear = 1447;
    
    final int daysDifference = gregorianDate.difference(referenceDate).inDays;
    
    int hijriDay = referenceHijriDay + daysDifference;
    int hijriMonth = referenceHijriMonth;
    int hijriYear = referenceHijriYear;
    
    final Map<int, List<int>> hijriYearLengths = {
      1446: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29],
      1447: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29],
      1448: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 30],
    };
    
    List<int> currentYearLengths = hijriYearLengths[hijriYear] ?? [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
    
    while (hijriDay > currentYearLengths[hijriMonth - 1]) {
      hijriDay -= currentYearLengths[hijriMonth - 1];
      hijriMonth++;
      
      if (hijriMonth > 12) {
        hijriMonth = 1;
        hijriYear++;
        currentYearLengths = hijriYearLengths[hijriYear] ?? [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
      }
    }
    
    while (hijriDay < 1) {
      hijriMonth--;
      if (hijriMonth < 1) {
        hijriMonth = 12;
        hijriYear--;
        currentYearLengths = hijriYearLengths[hijriYear] ?? [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
      }
      hijriDay += currentYearLengths[hijriMonth - 1];
    }
    
    final List<String> hijriMonths = [
      'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 
      'Jumada al-Ula', 'Jumada al-Thani', 'Rajab', 'Sha\'ban', 
      'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah'
    ];
    
    return '$hijriDay ${hijriMonths[hijriMonth - 1]} $hijriYear AH';
  }

class _TVDisplayScreenState extends State<TVDisplayScreen> {
  Timer? _timer;
  DateTime now = DateTime.now();
  String nextPrayerName = '';
  Duration nextPrayerCountdown = Duration.zero;
  // Carousel state (original CarouselSlider will be used on web builds)

  @override
  void initState() {
    super.initState();
    // Wakelock may throw on some web/platform implementations (e.g. wakelock_web)
    // so call it and swallow async errors to avoid crashing the UI.
    Wakelock.enable().catchError((_) {});
  // no page controller needed when using CarouselSlider
    _startClock();
    _calculateNextPrayer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    Wakelock.disable();
  // nothing to dispose for carousel here
    super.dispose();
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

    widget.prayerTimes.forEach((name, times) {
      final adhan = times['adhan'] ?? '--:--';
      if (adhan.contains(':')) {
        final parts = adhan.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        var time = DateTime(today.year, today.month, today.day, hour, minute);
        if (time.isBefore(now)) time = time.add(const Duration(days: 1));
        if (nextTime == null || time.isBefore(nextTime!)) {
          nextTime = time;
          nextName = name;
        }
      }
    });

    if (nextTime != null) {
      nextPrayerName = nextName;
      nextPrayerCountdown = nextTime!.difference(now);
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
  final timeStr = DateFormat.Hms().format(now);
  final dateStr = DateFormat.yMMMMEEEEd().format(now);
  final hijriStr = _getHijriDate(now);

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
                      const Text(
                        "Our Masjid App",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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
                                  child: widget.announcements.isEmpty
                                      ? Container(
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'No announcements',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 20),
                                          ),
                                        )
                    : CarouselSlider.builder(
                      itemCount: widget.announcements.length,
                      itemBuilder: (context, index, realIndex) {
                                            final item = widget.announcements[index];
                                            return Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(16),
                                                child: Image.network(
                                                  item['imagePath'] ?? '',
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      alignment: Alignment.center,
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            'No Image',
                                                            style: TextStyle(
                                                              color: Colors.grey[600],
                                                              fontSize: 16,
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
                                            autoPlayInterval: const Duration(seconds: 5),
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
                                  const Icon(Icons.access_time, size: 32, color: Color(0xFF2196F3)),
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
                                    style: TextStyle(
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
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(0.18),
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

                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  color: Colors.white,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.prayerTimes.entries.map((entry) {
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
                                  color: nextPrayerName == entry.key ? Colors.white : const Color(0xFF0D47A1),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${entry.value['adhan']}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: nextPrayerName == entry.key ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${entry.value['iqamah']}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: nextPrayerName == entry.key ? Colors.white70 : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
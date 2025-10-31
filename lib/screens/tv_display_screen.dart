import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:wakelock/wakelock.dart';
import 'package:intl/intl.dart';  

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

class _TVDisplayScreenState extends State<TVDisplayScreen> {
  Timer? _timer;
  DateTime now = DateTime.now();
  String nextPrayerName = '';
  Duration nextPrayerCountdown = Duration.zero;
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    _startClock();
    _calculateNextPrayer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    Wakelock.disable();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        now = DateTime.now();
        _calculateNextPrayer();
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
    final timeStr = DateFormat.Hms().format(now);
    final dateStr = DateFormat.yMMMMEEEEd().format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // App Bar with Logo and App Name
          Container(
            height: 80,
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
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: [
                // Masjid Logo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mosque,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                // App Name
                const Text(
                  "Our Masjid App",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // Current Date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🕌 Modern Carousel Section
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 30),
                          child: const Text(
                            "📢 Announcements",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        
                        CarouselSlider.builder(
                          itemCount: widget.announcements.length,
                          itemBuilder: (context, index, realIndex) {
                            final item = widget.announcements[index];
                            final isCenter = index == _carouselIndex;
                            
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              transform: Matrix4.identity()
                                ..scale(isCenter ? 1.0 : 0.9)
                                ..translate(0.0, isCenter ? 0.0 : 20.0),
                              child: Stack(
                                children: [
                                  // Main Card with Gradient
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.4),
                                          blurRadius: 25,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(40.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Title with Icon
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.2),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.campaign_rounded,
                                                  color: Colors.white,
                                                  size: 32,
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                child: Text(
                                                  item['title'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 42,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: 1.1,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 30),
                                          
                                          // Subtitle with decorative line
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              item['subtitle'] ?? '',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 28,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                          
                                          const SizedBox(height: 20),
                                          
                                          // Date Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Announcement ${index + 1} of ${widget.announcements.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Shine Effect
                                  if (isCenter)
                                    Positioned(
                                      top: -50,
                                      left: -50,
                                      child: Container(
                                        width: 100,
                                        height: 100,
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
                                ],
                              ),
                            );
                          },
                          options: CarouselOptions(
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 8),
                            autoPlayCurve: Curves.fastOutSlowIn,
                            enlargeCenterPage: true,
                            viewportFraction: 0.7,
                            height: 500,
                            onPageChanged: (index, reason) {
                              setState(() => _carouselIndex = index);
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Modern Carousel Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            widget.announcements.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: _carouselIndex == index ? 40 : 12,
                              height: 12,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: _carouselIndex == index
                                    ? const LinearGradient(
                                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.grey[300]!,
                                          Colors.grey[400]!,
                                        ],
                                      ),
                                boxShadow: _carouselIndex == index
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.5),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 40),

                  // 🕒 Right section (Clock + Next Prayer)
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey[50]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Current Time
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.access_time_filled_rounded,
                                  color: Color(0xFF2196F3),
                                  size: 40,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2196F3),
                                    fontFamily: 'monospace',
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Next Prayer Section
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_active_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'NEXT PRAYER',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  nextPrayerName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    _formatDuration(nextPrayerCountdown),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🙏 Bottom section (Prayer times)
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: widget.prayerTimes.entries.map((entry) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: nextPrayerName == entry.key
                        ? const LinearGradient(
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.white, Colors.grey[50]!],
                          ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: nextPrayerName == entry.key
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: nextPrayerName == entry.key
                          ? Colors.white
                          : const Color(0xFF2196F3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: nextPrayerName == entry.key
                              ? Colors.white
                              : const Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${entry.value['adhan']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: nextPrayerName == entry.key
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      Text(
                        '${entry.value['iqamah']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: nextPrayerName == entry.key
                              ? Colors.white.withOpacity(0.8)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
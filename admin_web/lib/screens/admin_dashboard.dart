import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admin_web/providers/auth_provider.dart';
import 'package:admin_web/providers/prayer_times_provider.dart';
import 'package:admin_web/providers/announcements_provider.dart';
import 'package:admin_web/screens/prayer_times_screen.dart';
import 'package:admin_web/screens/announcements_screen.dart';
import 'package:admin_web/screens/tv_display_screen.dart';
import 'package:admin_web/screens/settings_screen.dart';
import 'package:admin_web/utils/admin_theme.dart';

// Real-time Dashboard Home
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();
  int _connectedTvCount = 0;
  StreamSubscription<QuerySnapshot>? _tvSubscription;

  @override
  void initState() {
    super.initState();
    // Update time every second for real-time clock
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
    _listenToConnectedTvs();
  }

  void _listenToConnectedTvs() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userId == null) return;
    
    try {
      _tvSubscription = FirebaseFirestore.instance
          .collection('tv_pairs')
          .where('masjidId', isEqualTo: auth.userId)
          .where('claimed', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _connectedTvCount = snapshot.docs.length;
          });
        }
      });
    } catch (e) {
      debugPrint('Error listening to TV displays: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tvSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcements = Provider.of<AnnouncementsProvider>(context);
    final prayerTimes = Provider.of<PrayerTimesProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TV Preview Header - Made smaller
                _buildTVPreviewHeader(auth),
                const SizedBox(height: 16),
                
                // Upcoming Prayer - More compact
                _buildUpcomingPrayerSection(prayerTimes),
                const SizedBox(height: 16),
                
                // Live TV Display Preview - Smaller
                _buildLiveTVPreview(prayerTimes, announcements),
                const SizedBox(height: 16),
                
                // Announcements Grid - More compact
                _buildAnnouncementsGrid(announcements),
                const SizedBox(height: 16),
                
                // System Status Panel - Smaller
                _buildSystemStatus(prayerTimes, announcements),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTVPreviewHeader(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1976D2),
            Color(0xFF1565C0),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tv, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.masjidName.isNotEmpty ? auth.masjidName : 'Dashboard',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _connectedTvCount > 0 
                      ? '$_connectedTvCount TV${_connectedTvCount > 1 ? 's' : ''} connected' 
                      : 'No TVs connected',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _connectedTvCount > 0 
                  ? const Color(0xFF4CAF50).withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _connectedTvCount > 0 
                    ? const Color(0xFF4CAF50)
                    : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 6,
                  color: _connectedTvCount > 0 
                      ? const Color(0xFF4CAF50)
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  _connectedTvCount > 0 ? 'ONLINE' : 'SETUP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPrayerSection(PrayerTimesProvider prayerTimes) {
    final nextPrayer = _getNextPrayer(prayerTimes);
    final timeStr = DateFormat('h:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEE, MMM d').format(_currentTime);
    final hijriDate = _getHijriDate(_currentTime);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Color(0xFF1976D2), size: 16),
              SizedBox(width: 6),
              Text(
                'UPCOMING PRAYER',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Current Time Display - More compact
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT TIME',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dateStr • $hijriDate',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Next Prayer Countdown - More compact
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1976D2),
                        Color(0xFF1565C0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT PRAYER',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextPrayer['name'] ?? 'MAGHRIB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextPrayer['time'] ?? '6:30 PM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'IN',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              nextPrayer['countdown'] ?? '02:45:30',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'RobotoMono',
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
        ],
      ),
    );
  }

  Widget _buildLiveTVPreview(PrayerTimesProvider prayerTimes, AnnouncementsProvider announcements) {
    final nextPrayer = _getNextPrayer(prayerTimes);
    final prayerTimesMap = nextPrayer['prayerTimes'] as Map<String, String>? ?? {};
    final currentPrayer = nextPrayer['currentPrayer'] as String?;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final timeStr = DateFormat('h:mm a').format(_currentTime);
    final activeAnnouncements = announcements.announcements.where((a) => a.active).toList();
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tv, color: Color(0xFF1976D2), size: 16),
              SizedBox(width: 6),
              Text(
                'LIVE TV PREVIEW',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _connectedTvCount > 0 
                      ? Color(0xFF4CAF50).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _connectedTvCount > 0 ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: _connectedTvCount > 0 
                        ? Color(0xFF4CAF50)
                        : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // TV Screen Mockup - Much smaller
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF1976D2), width: 1),
            ),
            child: Stack(
              children: [
                // TV Screen Content
                Positioned.fill(
                  child: Container(
                    margin: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        // TV Screen Header
                        Container(
                          height: 28,
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF1976D2),
                                Color(0xFF1565C0),
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mosque, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  auth.masjidName.isNotEmpty 
                                      ? auth.masjidName 
                                      : 'YOUR MASJID',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // TV Screen Content Area
                        Expanded(
                          child: Row(
                            children: [
                              // Announcement Images
                              Expanded(
                                flex: 7,
                                child: Container(
                                  color: Color(0xFFF5F5F5),
                                  child: Center(
                                    child: activeAnnouncements.isNotEmpty
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.slideshow,
                                                size: 20,
                                                color: Color(0xFF1976D2),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                '${activeAnnouncements.length}',
                                                style: TextStyle(
                                                  color: Color(0xFF1976D2),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                'Announcement${activeAnnouncements.length > 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  color: Color(0xFF1976D2),
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_outlined,
                                                size: 20,
                                                color: Colors.grey.shade400,
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'No Announcements',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              
                              // Prayer Times Sidebar
                              Container(
                                width: 90,
                                color: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'NEXT',
                                        style: TextStyle(
                                          color: Color(0xFF1976D2),
                                          fontSize: 7,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        nextPrayer['name'] ?? 'N/A',
                                        style: TextStyle(
                                          color: Color(0xFF1565C0),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        nextPrayer['countdown'] ?? '--:--:--',
                                        style: TextStyle(
                                          color: Color(0xFF1976D2),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'RobotoMono',
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Container(
                                        height: 1,
                                        color: Colors.grey.shade200,
                                        margin: EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                      SizedBox(height: 4),
                                      // Prayer times list
                                      ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((prayer) {
                                        final isNext = prayer == currentPrayer;
                                        return Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                prayer,
                                                style: TextStyle(
                                                  color: isNext 
                                                      ? Color(0xFF1976D2) 
                                                      : Colors.grey.shade700,
                                                  fontSize: 7,
                                                  fontWeight: isNext 
                                                      ? FontWeight.w700 
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                prayerTimesMap[prayer] ?? '--:--',
                                                style: TextStyle(
                                                  color: isNext 
                                                      ? Color(0xFF1976D2) 
                                                      : Colors.grey.shade600,
                                                  fontSize: 7,
                                                  fontWeight: isNext 
                                                      ? FontWeight.w700 
                                                      : FontWeight.w500,
                                                  fontFamily: 'RobotoMono',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
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
          
          SizedBox(height: 16),
          // TV Controls - Smaller buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(Icons.settings, size: 14),
                label: Text('TV Settings', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF1976D2),
                  side: BorderSide(color: Color(0xFF1976D2)),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(Icons.visibility, size: 14),
                label: Text('Preview', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF4CAF50),
                  side: BorderSide(color: Color(0xFF4CAF50)),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(Icons.refresh, size: 14),
                label: Text('Refresh', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsGrid(AnnouncementsProvider announcements) {
    final activeAnnouncements = announcements.announcements.where((a) => a.active).toList();
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.announcement, color: Color(0xFF1976D2), size: 16),
              SizedBox(width: 6),
              Text(
                'ANNOUNCEMENTS',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${activeAnnouncements.length} active / ${announcements.announcements.length} total',
                  style: TextStyle(
                    color: Color(0xFF1976D2),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          if (announcements.announcements.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200, width: 1),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.announcement_outlined,
                    size: 40,
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No Announcements',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create announcements to display on the TV screen',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: Icon(Icons.add, size: 16),
                    label: Text('Create Announcement', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: announcements.announcements.take(4).map((announcement) {
                  return Container(
                    width: 200,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Image Preview
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 32,
                                  color: Color(0xFF1976D2).withOpacity(0.3),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  announcement.active ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF1976D2),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Content
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                announcement.title,
                                style: TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd').format(announcement.date),
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                ),
                              ),
                              if (announcement.description.isNotEmpty) ...[
                                SizedBox(height: 6),
                                Text(
                                  announcement.description,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
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

  Widget _buildSystemStatus(PrayerTimesProvider prayerTimes, AnnouncementsProvider announcements) {
    final hasPrayerTimes = prayerTimes.prayerSettings != null;
    final activeAnnouncements = announcements.announcements.where((a) => a.active).length;
    final totalAnnouncements = announcements.announcements.length;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, color: Color(0xFF1976D2), size: 16),
              SizedBox(width: 6),
              Text(
                'SYSTEM STATUS',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          Row(
            children: [
              // Status Indicators - More compact
              Expanded(
                child: Column(
                  children: [
                    _buildStatusItem(
                      'TV Display',
                      Icons.tv,
                      _connectedTvCount > 0 ? Color(0xFF4CAF50) : Colors.orange,
                      _connectedTvCount > 0 ? 'Connected' : 'Not Connected',
                    ),
                    SizedBox(height: 8),
                    _buildStatusItem(
                      'Prayer Times',
                      Icons.access_time,
                      hasPrayerTimes ? Color(0xFF4CAF50) : Colors.orange,
                      hasPrayerTimes ? 'Configured' : 'Not Set',
                    ),
                    SizedBox(height: 8),
                    _buildStatusItem(
                      'Announcements',
                      Icons.announcement,
                      activeAnnouncements > 0 ? Color(0xFF4CAF50) : Colors.orange,
                      '$activeAnnouncements Active',
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              
              // Quick Stats - More compact
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUICK STATS',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          _buildQuickStatItem('TVs', '$_connectedTvCount', Icons.tv),
                          SizedBox(width: 8),
                          _buildQuickStatItem('Active', '$activeAnnouncements', Icons.slideshow),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            hasPrayerTimes && _connectedTvCount > 0 
                                ? Icons.check_circle 
                                : Icons.info_outline,
                            color: hasPrayerTimes && _connectedTvCount > 0 
                                ? Color(0xFF4CAF50) 
                                : Colors.orange,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              hasPrayerTimes && _connectedTvCount > 0
                                  ? 'All systems normal'
                                  : 'Setup required',
                              style: TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: Color(0xFF1976D2), size: 16),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: Color(0xFF1976D2),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, IconData icon, Color color, String status) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: color,
            size: 16,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getNextPrayer(PrayerTimesProvider prayerTimes) {
    final settings = prayerTimes.prayerSettings;
    if (settings == null) {
      return {
        'name': 'Loading...',
        'time': '--:--',
        'countdown': '--:--:--',
        'prayerTimes': <String, String>{},
      };
    }

    final now = _currentTime;
    final prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    // Build prayer times map for display
    final prayerTimesMap = <String, String>{};
    for (final name in prayerOrder) {
      final pt = settings.prayerTimes[name];
      if (pt != null) {
        prayerTimesMap[name] = _formatTime24to12(pt.adhan);
      }
    }

    // Find next prayer
    String? nextPrayerName;
    DateTime? nextPrayerTime;

    for (final name in prayerOrder) {
      final pt = settings.prayerTimes[name];
      if (pt == null) continue;

      final prayerDateTime = _parseTimeToToday(pt.adhan);
      if (prayerDateTime != null && prayerDateTime.isAfter(now)) {
        nextPrayerName = name;
        nextPrayerTime = prayerDateTime;
        break;
      }
    }

    // If no prayer found today, next prayer is Fajr tomorrow
    if (nextPrayerName == null) {
      final fajr = settings.prayerTimes['Fajr'];
      if (fajr != null) {
        nextPrayerName = 'Fajr';
        final fajrTime = _parseTimeToToday(fajr.adhan);
        if (fajrTime != null) {
          nextPrayerTime = fajrTime.add(const Duration(days: 1));
        }
      }
    }

    // Calculate countdown
    String countdown = '--:--:--';
    if (nextPrayerTime != null) {
      final diff = nextPrayerTime.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final seconds = diff.inSeconds % 60;
      countdown = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return {
      'name': nextPrayerName?.toUpperCase() ?? 'N/A',
      'time': nextPrayerTime != null ? DateFormat('h:mm a').format(nextPrayerTime) : '--:--',
      'countdown': countdown,
      'prayerTimes': prayerTimesMap,
      'currentPrayer': nextPrayerName,
    };
  }

  DateTime? _parseTimeToToday(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = _currentTime;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (e) {
      debugPrint('Error parsing time: $e');
    }
    return null;
  }

  String _formatTime24to12(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        return '$hour:$minute $period';
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
    }
    return time24h;
  }

  String _getHijriDate(DateTime gregorianDate) {
    // Simplified Hijri date - for production use a proper library
    final Map<int, List<int>> hijriYearLengths = {
      1446: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29],
      1447: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29],
      1448: [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 30],
    };

    final DateTime referenceDate = DateTime(2025, 10, 31);
    const int referenceHijriDay = 9;
    const int referenceHijriMonth = 5;
    const int referenceHijriYear = 1447;

    final int daysDifference = gregorianDate.difference(referenceDate).inDays;

    int hijriDay = referenceHijriDay + daysDifference;
    int hijriMonth = referenceHijriMonth;
    int hijriYear = referenceHijriYear;

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

    final List<String> hijriMonths = [
      'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Shaban',
      'Ramadan', 'Shawwal', 'Dhul Qadah', 'Dhul Hijjah'
    ];

    return '$hijriDay ${hijriMonths[hijriMonth - 1]} $hijriYear AH';
  }
}

// Main Admin Dashboard with sidebar navigation - Also made more compact
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'label': 'Dashboard'},
    {'icon': Icons.access_time, 'label': 'Prayer Times'},
    {'icon': Icons.announcement, 'label': 'Announcements'},
    {'icon': Icons.tv, 'label': 'TV Display'},
    {'icon': Icons.settings, 'label': 'Settings'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: AdminTheme.backgroundCard,
              boxShadow: AdminTheme.shadowLight,
            ),
            child: Column(
              children: [
                // Logo/Header - More compact
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AdminTheme.primaryGradient,
                          borderRadius: AdminTheme.borderRadiusSmall,
                        ),
                        child: const Icon(Icons.mosque, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Masjid App',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AdminTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Menu Items - More compact
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isSelected = _selectedIndex == index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? AdminTheme.primaryBlue.withOpacity(0.1) : null,
                          borderRadius: AdminTheme.borderRadiusSmall,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            item['icon'],
                            color: isSelected ? AdminTheme.primaryBlue : AdminTheme.textMuted,
                            size: 18,
                          ),
                          title: Text(
                            item['label'],
                            style: TextStyle(
                              color: isSelected ? AdminTheme.primaryBlue : AdminTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => setState(() => _selectedIndex = index),
                          shape: RoundedRectangleBorder(
                            borderRadius: AdminTheme.borderRadiusSmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Logout - More compact
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.logout, color: AdminTheme.accentRed, size: 18),
                      title: const Text(
                        'Logout',
                        style: TextStyle(color: AdminTheme.accentRed, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      onTap: () => auth.logout(),
                      shape: RoundedRectangleBorder(
                        borderRadius: AdminTheme.borderRadiusSmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              color: AdminTheme.backgroundSection,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardHome();
      case 1:
        return const PrayerTimesScreen();
      case 2:
        return const AnnouncementsScreen();
      case 3:
        return const TvDisplayScreen();
      case 4:
        return const SettingsScreen();
      default:
        return const DashboardHome();
    }
  }
}
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Our Masjid App',
      theme: ThemeData(
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> masjids = [];
  bool isLoading = false;
  String? userLocation;
  String searchStatus = '';
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  // Search masjids worldwide 
  // Search masjids by name OR location - FIXED VERSION
// Search by MASJID NAME - FIXED VERSION
Future<void> searchMasjids(String query) async {
  if (query.isEmpty) {
    setState(() {
      masjids = [];
      searchStatus = 'Enter a masjid name';
    });
    return;
  }

  setState(() {
    isLoading = true;
    masjids = [];
    searchStatus = 'Searching for "$query"...';
    isSearching = true;
  });

  try {
    // 🔹 Add a User-Agent so Nominatim doesn’t block you
    final response = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=50',
      ),
      headers: {
        'User-Agent': 'MasjidFinderApp/1.0', // <— You can name this anything
      },
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;

      final List<Map<String, dynamic>> foundMasjids = [];

      for (final place in data) {
        final name = place['display_name']?.toString() ?? '';
        final lat = place['lat']?.toString();
        final lon = place['lon']?.toString();

        if (lat != null && lon != null) {
          foundMasjids.add({
            'id': place['place_id']?.toString() ?? 'search_${foundMasjids.length}',
            'name': name.split(',').first.trim(),
            'address': name,
            'phone': 'Contact for details',
            'email': 'Not available',
            'latitude': double.parse(lat),
            'longitude': double.parse(lon),
            'prayerTimes': _generatePrayerTimes(),
            'events': _generateSampleEvents(),
            'announcements': _generateSampleAnnouncements(),
          });
        }
      }

      setState(() {
        masjids = foundMasjids;
        searchStatus = foundMasjids.isEmpty
            ? 'No results found for "$query"'
            : 'Found ${foundMasjids.length} results for "$query"';
      });
    } else {
      setState(() {
        searchStatus = 'Search failed (HTTP ${response.statusCode})';
        masjids = [];
      });
    }
  } catch (e) {
    setState(() {
      searchStatus = 'Search error: $e';
      masjids = [];
    });
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

bool _looksLikeMasjid(String name) { final lowerName = name.toLowerCase(); return lowerName.contains('mosque') || lowerName.contains('masjid') || lowerName.contains('islamic') || lowerName.contains('islam') || lowerName.contains('muslim') || lowerName.contains('مسجد') || lowerName.contains('جامع') || lowerName.contains('jama') || lowerName.contains('musalla'); }
  // Check location permissions
  Future<bool> _checkLocationPermission() async {
    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }
      return status.isGranted;
    } catch (e) {
      return false;
    }
  }
String _getMasjidName(String displayName) { final parts = displayName.split(','); if (parts.isNotEmpty) { return parts[0].trim(); } return 'Masjid'; }
  // Find nearby masjids
  Future<void> findNearbyMasjids() async {
    setState(() {
      isLoading = true;
      masjids = [];
      userLocation = null;
      searchStatus = 'Getting your location...';
      isSearching = false;
      _searchController.clear();
    });

    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        setState(() {
          searchStatus = 'Location permission required';
          isLoading = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      
      setState(() {
        userLocation = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        searchStatus = 'Searching for masjids...';
      });

      final List<Map<String, dynamic>> nearbyMasjids = await _getRealNearbyMasjids(
        position.latitude,
        position.longitude,
      );

      setState(() {
        masjids = nearbyMasjids;
        searchStatus = masjids.isEmpty ? 'No masjids found in your area' : 'Found ${masjids.length} masjids near you';
      });
      
    } catch (e) {
      print('Location error: $e');
      setState(() {
        userLocation = 'Location access failed';
        searchStatus = 'Unable to search for masjids. Please enable location.';
        masjids = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Get nearby masjids
  Future<List<Map<String, dynamic>>> _getRealNearbyMasjids(double lat, double lng) async {
    try {
      List<Map<String, dynamic>> masjids = await _getFromOpenStreetMap(lat, lng);
      return masjids;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFromOpenStreetMap(double lat, double lng) async {
    try {
      const double radius = 50000;
      
      final String query = '''
        [out:json][timeout:25];
        (
          node["amenity"="place_of_worship"](around:$radius,$lat,$lng);
          way["amenity"="place_of_worship"](around:$radius,$lat,$lng);
        );
        out body;
      ''';

      final response = await http.get(
        Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;
        
        final List<Map<String, dynamic>> islamicPlaces = [];
        
        for (final element in elements) {
          final tags = element['tags'] ?? {};
          final name = tags['name']?.toString().trim();
          
          if (name == null || name.isEmpty) continue;
          
          final bool isIslamic = _isIslamicPlace(tags, name);

          if (isIslamic) {
            final masjid = _createMasjidFromElement(element);
            islamicPlaces.add(masjid);
          }
        }
        
        return islamicPlaces;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  bool _isIslamicPlace(Map<String, dynamic> tags, String name) {
    final religion = tags['religion']?.toString().toLowerCase() ?? '';
    final nameLower = name.toLowerCase();
    
    return religion == 'muslim' ||
           nameLower.contains('masjid') ||
           nameLower.contains('mosque') ||
           nameLower.contains('islamic') ||
           nameLower.contains('islam') ||
           nameLower.contains('muslim') ||
           nameLower.contains('مسجد') ||
           nameLower.contains('جامع');
  }

  Map<String, dynamic> _createMasjidFromElement(Map<String, dynamic> element) {
    final tags = element['tags'] ?? {};
    final lat = element['lat'] ?? (element['center']?['lat'] ?? 0.0);
    final lon = element['lon'] ?? (element['center']?['lon'] ?? 0.0);

    String name = tags['name'] ?? 'Local Masjid';
    if (name == 'Local Masjid') {
      if (tags['religion'] == 'muslim') {
        name = 'Islamic Center';
      }
    }

    return {
      'id': element['id'].toString(),
      'name': name,
      'address': _getAddress(tags),
      'phone': tags['phone'] ?? 'Not available',
      'email': tags['email'] ?? 'Not available',
      'latitude': lat,
      'longitude': lon,
      'prayerTimes': _generatePrayerTimes(),
      'events': _generateSampleEvents(),
      'announcements': _generateSampleAnnouncements(),
    };
  }

  String _getAddress(Map<String, dynamic> tags) {
    final street = tags['addr:street'];
    final city = tags['addr:city'];
    final postcode = tags['addr:postcode'];
    final housenumber = tags['addr:housenumber'];
    
    if (street != null && city != null) {
      return '${housenumber ?? ''} $street, $city ${postcode ?? ''}'.trim();
    }
    
    final fullAddress = tags['addr:full'] ?? tags['address'] ?? tags['addr'];
    if (fullAddress != null) return fullAddress.toString();
    
    return 'Location available';
  }

  Map<String, dynamic> _generatePrayerTimes() {
    return {
      'fajr': {'adhan': '04:42', 'iqamah': '05:12'},
      'shurug': {'adhan': '06:15', 'iqamah': '--'},
      'dhuhr': {'adhan': '12:59', 'iqamah': '13:09'},
      'asr': {'adhan': '16:43', 'iqamah': '16:58'},
      'maghrib': {'adhan': '19:44', 'iqamah': '19:54'},
      'isha': {'adhan': '21:12', 'iqamah': '21:22'},
    };
  }

  List<dynamic> _generateSampleEvents() {
    return [
      {
        'title': 'Friday Jummah',
        'description': 'Weekly Friday prayer with khutbah',
        'date': 'Every Friday',
        'time': '13:30'
      },
      {
        'title': 'Daily Prayers',
        'description': 'All five daily prayers held in congregation',
        'date': 'Daily',
        'time': 'As per schedule'
      }
    ];
  }

  List<dynamic> _generateSampleAnnouncements() {
    return [
      {
        'title': 'Welcome',
        'message': 'Visitors and newcomers are always welcome',
        'date': 'Today',
        'important': false
      },
      {
        'title': 'Prayer Times',
        'message': 'Please check board for updated prayer times',
        'date': 'Today',
        'important': true
      }
    ];
  }

  void _showMasjidDetails(Map<String, dynamic> masjid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MasjidDetailScreen(masjid: masjid),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      masjids = [];
      searchStatus = '';
      isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Masjid App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search masjids worldwide...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: searchMasjids,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isLoading ? null : findNearbyMasjids,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(50, 50),
                  ),
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (userLocation != null) 
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  userLocation!,
                  style: const TextStyle(color: Color(0xFF2196F3), fontSize: 12),
                ),
              ),
            
            if (searchStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  searchStatus,
                  style: TextStyle(
                    color: masjids.isEmpty ? Colors.orange : Color(0xFF2196F3),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            if (isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching for masjids...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            
            if (masjids.isEmpty && !isLoading && !isSearching)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mosque, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Find Masjids Worldwide',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Search for any location or use your current location\nto find masjids around the world',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            
            if (masjids.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSearching ? 'Search Results (${masjids.length})' : 'Nearby Masjids (${masjids.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: masjids.length,
                        itemBuilder: (context, index) => MasjidCard(
                          masjid: masjids[index],
                          onTap: () => _showMasjidDetails(masjids[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MasjidCard extends StatelessWidget {
  final Map<String, dynamic> masjid;
  final VoidCallback onTap;

  const MasjidCard({super.key, required this.masjid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.mosque, color: Color(0xFF2196F3), size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      masjid['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      masjid['address'],
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${masjid['events']?.length ?? 0} events • ${masjid['announcements']?.length ?? 0} announcements',
                      style: TextStyle(color: Color(0xFF2196F3), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class MasjidDetailScreen extends StatefulWidget {
  final Map<String, dynamic> masjid;

  const MasjidDetailScreen({super.key, required this.masjid});

  @override
  State<MasjidDetailScreen> createState() => _MasjidDetailScreenState();
}

class _MasjidDetailScreenState extends State<MasjidDetailScreen> {
  String countdownText = '00:00:00';
  String currentPrayerName = 'Fajr';
  Timer? _timer;
  String currentDate = '';
  String currentTime = '';
  String hijriDate = '';

  @override
  void initState() {
    super.initState();
    _updateCurrentDateTime();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCurrentDateTime() {
    final now = DateTime.now();
    
    const List<String> weekdays = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
    ];
    const List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final weekdayStr = weekdays[now.weekday];
    final monthStr = months[now.month - 1];
    currentDate = '$weekdayStr, $monthStr ${now.day}, ${now.year}';
    
    String two(int n) => n.toString().padLeft(2, '0');
    currentTime = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
    
    hijriDate = _getHijriDate(now);
    
    setState(() {});
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

  void _startCountdownTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (Timer timer) {
      if (mounted) {
        setState(() {
          _updateCurrentDateTime();
          _calculateNextPrayer();
        });
      }
    });
  }

  void _calculateNextPrayer() {
    final now = DateTime.now();
    final prayerTimes = widget.masjid['prayerTimes'] as Map<String, dynamic>;
    
    final Map<String, DateTime> prayerTimeMap = {};
    
    prayerTimes.forEach((prayer, times) {
      if (times['adhan'] != '--') {
        final timeParts = times['adhan'].split(':');
        if (timeParts.length == 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          
          DateTime prayerTime = DateTime(now.year, now.month, now.day, hour, minute);
          
          if (prayerTime.isBefore(now)) {
            prayerTime = prayerTime.add(const Duration(days: 1));
          }
          
          prayerTimeMap[prayer] = prayerTime;
        }
      }
    });
    
    DateTime? nextPrayerTime;
    String nextPrayerName = 'Fajr';
    
    prayerTimeMap.forEach((prayer, time) {
      if (nextPrayerTime == null || time.isBefore(nextPrayerTime!)) {
        nextPrayerTime = time;
        nextPrayerName = prayer;
      }
    });
    
    if (nextPrayerTime != null) {
      final difference = nextPrayerTime!.difference(now);
      currentPrayerName = _capitalizeFirstLetter(nextPrayerName);
      countdownText = _formatDuration(difference);
    } else {
      countdownText = '00:00:00';
      currentPrayerName = 'Fajr';
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '00:00:00';
    }
    
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitHours = twoDigits(duration.inHours.remainder(24));
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final prayerTimes = widget.masjid['prayerTimes'] as Map<String, dynamic>;
    final events = widget.masjid['events'] as List<dynamic>? ?? [];
    final announcements = widget.masjid['announcements'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.masjid['name']),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'The Adhan of $currentPrayerName is in',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      countdownText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$currentDate\n$hijriDate',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Current Time: $currentTime',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.masjid['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.masjid['address'],
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    if (widget.masjid['phone'] != null && widget.masjid['phone'] != 'Not available') ...[
                      const SizedBox(height: 8),
                      Text(
                        '📞 ${widget.masjid['phone']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                    if (widget.masjid['email'] != null && widget.masjid['email'] != 'Not available') ...[
                      const SizedBox(height: 4),
                      Text(
                        '📧 ${widget.masjid['email']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Prayer Times',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'PRAYER',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'ADHAN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'IQAMAH',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPrayerRow('Fajr', prayerTimes['fajr'], currentPrayerName),
                    _buildDivider(),
                    _buildPrayerRow('Shurug', prayerTimes['shurug'], currentPrayerName),
                    _buildDivider(),
                    _buildPrayerRow('Dhuhr', prayerTimes['dhuhr'], currentPrayerName),
                    _buildDivider(),
                    _buildPrayerRow('Asr', prayerTimes['asr'], currentPrayerName),
                    _buildDivider(),
                    _buildPrayerRow('Maghrib', prayerTimes['maghrib'], currentPrayerName),
                    _buildDivider(),
                    _buildPrayerRow('Isha', prayerTimes['isha'], currentPrayerName),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Color(0xFF2196F3)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Jummah Prayer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '13:30',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${events.length} events',
                  style: TextStyle(color: Color(0xFF2196F3)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (events.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No upcoming events',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Column(
                children: events.map((event) => _buildEventCard(event)).toList(),
              ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${announcements.length} announcements',
                  style: TextStyle(color: Color(0xFF2196F3)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (announcements.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No announcements',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Column(
                children: announcements.map((announcement) => _buildAnnouncementCard(announcement)).toList(),
              ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Now following ${widget.masjid['name']}'),
                    backgroundColor: const Color(0xFF2196F3),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Follow Masjid'),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(String prayer, Map<String, dynamic> times, String currentPrayer) {
    final isNextPrayer = prayer.toLowerCase() == currentPrayer.toLowerCase();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (isNextPrayer)
                  Icon(Icons.notifications_active, color: Color(0xFF2196F3), size: 16),
                if (isNextPrayer) const SizedBox(width: 4),
                Text(
                  prayer,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isNextPrayer ? Color(0xFF2196F3) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              times['adhan'],
              style: TextStyle(
                color: isNextPrayer ? Color(0xFF2196F3) : Colors.grey,
                fontSize: 16,
                fontWeight: isNextPrayer ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              times['iqamah'],
              style: TextStyle(
                color: isNextPrayer ? Color(0xFF2196F3) : Color(0xFF2196F3),
                fontSize: 16,
                fontWeight: isNextPrayer ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.grey[300],
      height: 1,
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Color(0xFF2196F3)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event['description'],
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Color(0xFF2196F3)),
                const SizedBox(width: 4),
                Text(
                  event['date'],
                  style: TextStyle(fontSize: 14, color: Color(0xFF2196F3)),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Color(0xFF2196F3)),
                const SizedBox(width: 4),
                Text(
                  event['time'],
                  style: TextStyle(fontSize: 14, color: Color(0xFF2196F3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final isImportant = announcement['important'] == true;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isImportant ? Color(0xFFFFEBEE) : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isImportant)
                  Icon(Icons.warning, color: Color(0xFFF44336)),
                if (isImportant) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement['title'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isImportant ? Color(0xFFF44336) : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement['message'],
              style: TextStyle(
                color: isImportant ? Color(0xFFF44336) : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, 
                    size: 14, 
                    color: isImportant ? Color(0xFFF44336) : Color(0xFF2196F3)),
                const SizedBox(width: 4),
                Text(
                  announcement['date'],
                  style: TextStyle(
                    fontSize: 12,
                    color: isImportant ? Color(0xFFF44336) : Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
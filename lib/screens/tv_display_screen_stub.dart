import 'package:flutter/material.dart';

/// Mobile stub for TVDisplayScreen.
/// The real `TVDisplayScreen` is intended for web/TV builds only and may
/// import web-specific packages. This lightweight stub prevents mobile
/// (Android/iOS) builds from pulling web-only dependencies.
class TVDisplayScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Our Masjid App')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'TV mode is only available on web/TV builds.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

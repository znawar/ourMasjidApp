import 'package:flutter/material.dart';
// Conditionally load the real TV screen only on web. On mobile platforms we
// use a small stub to avoid importing web-only packages (which can break
// Android/iOS builds).
import 'screens/tv_display_screen_stub.dart'
  if (dart.library.html) 'screens/tv_display_screen.dart';
import 'screens/mobile_home_screen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Our Masjid App',
      debugShowCheckedModeBanner: false,
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
            // Avoid forcing an infinite minimum width globally. Some
            // buttons live inside Rows (e.g. the Masjid details contact
            // row) and an infinite min width causes a layout crash on
            // constrained platforms. Use a zero width min and specify
            // full-width buttons locally where required.
            minimumSize: const Size(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const ResponsiveLauncher(),
    );
  }
}

class ResponsiveLauncher extends StatelessWidget {
  const ResponsiveLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          // TV Mode
          return TVDisplayScreen(
           announcements: [
            {'imagePath': 'https://i.ibb.co.com/FLKKMksq/Whats-App-Image-2025-10-31-at-9-48-01-PM-1.jpg'},
            {'imagePath': 'https://i.ibb.co.com/CKkgQ3tc/Whats-App-Image-2025-10-31-at-9-48-01-PM.jpg'},
            {'imagePath': 'https://i.ibb.co.com/mrZysvjs/Untitled-design-1.png'},
             ],

            prayerTimes: {
              'Fajr': {'adhan': '05:00', 'iqamah': '05:20'},
              'Dhuhr': {'adhan': '12:45', 'iqamah': '13:00'},
              'Asr': {'adhan': '16:15', 'iqamah': '16:30'},
              'Maghrib': {'adhan': '18:30', 'iqamah': '18:40'},
              'Isha': {'adhan': '19:45', 'iqamah': '20:00'},
            },
          );
        } else {
          // Mobile Mode
          return const HomeScreen();
        }
      },
    );
  }
}
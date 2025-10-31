import 'package:flutter/material.dart';
import 'screens/tv_display_screen.dart';
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
            minimumSize: const Size(double.infinity, 50),
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
              {'title': 'Parenting Workshop', 'subtitle': 'Saturday 5 PM'},
              {'title': 'Kids Quiz Competition', 'subtitle': 'Sunday 10 AM'},
              {'title': 'Hadith', 'subtitle': '“The best among you are those who learn the Qur’an and teach it.”'},
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
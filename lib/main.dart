import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Conditionally load the real TV screen only on web. On mobile platforms we
// use a small stub to avoid importing web-only packages (which can break
// Android/iOS builds).
// The import may be unused at runtime because we no longer auto-select the
// TV display; keep it so the TV code remains available. Silence the
// analyzer about an unused import.
// ignore: unused_import
import 'screens/tv_display_screen_stub.dart'
  if (dart.library.html) 'screens/tv_display_screen.dart';
import 'screens/mobile_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
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
    // Default: show the mobile HomeScreen.
    // Web-only override: allow launching the TV display via URL params.
    // Example:
    //   https://YOUR_APP_URL/?mode=tv&masjidId=YOUR_MASJID_ID
    if (kIsWeb) {
      final params = Uri.base.queryParameters;
      final mode = (params['mode'] ?? '').trim().toLowerCase();
      final tvFlag = (params['tv'] ?? '').trim().toLowerCase();

      final isTv = mode == 'tv' || mode == 'display' || tvFlag == '1' || tvFlag == 'true';
      if (isTv) {
        final masjidId = params['masjidId']?.trim();
        return TVDisplayScreen(masjidId: (masjidId?.isEmpty ?? true) ? null : masjidId);
      }
    }

    return const HomeScreen();
  }
}
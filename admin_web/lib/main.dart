import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import './providers/auth_provider.dart';
import './providers/prayer_times_provider.dart';
import './providers/announcements_provider.dart';
import './screens/login_screen.dart';
import './screens/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('App will run in demo mode without Firebase');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PrayerTimesProvider>(
          create: (_) => PrayerTimesProvider(),
          update: (context, auth, prayerTimes) {
            final provider = prayerTimes ?? PrayerTimesProvider();
            final userId = auth.userId;
            if (userId != null && userId.trim().isNotEmpty) {
              provider.setMasjidId(userId);
            } else {
              provider.setMasjidId('');
            }
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, AnnouncementsProvider>(
          create: (_) => AnnouncementsProvider(),
          update: (context, auth, announcements) {
            final provider = announcements ?? AnnouncementsProvider();
            final userId = auth.userId;
            provider.setMasjidId(userId ?? '');
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Our Masjid App - Admin',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          primaryColor: const Color(0xFF2196F3),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: IconThemeData(color: Color(0xFF2196F3)),
            titleTextStyle: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return auth.isAuthenticated
                ? const AdminDashboard()
                : const LoginScreen();
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

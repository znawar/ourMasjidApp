import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Centralized theme for the admin web application.
/// This ensures consistent styling across all screens.
class AdminTheme {
  AdminTheme._();

  // ==========================================================================
  // COLORS
  // ==========================================================================

  /// Primary brand colors
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color primaryBlueDark = Color(0xFF1565C0);
  static const Color primaryBlueLight = Color(0xFF2196F3);
  static const Color primaryBlueLighter = Color(0xFF42A5F5);
  static const Color primaryNavy = Color(0xFF0D47A1);

  /// Secondary/accent colors
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color accentGreenDark = Color(0xFF2E7D32);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentAmber = Color(0xFFFFA726);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentRedLight = Color(0xFFEF4444);
  static const Color accentPurple = Color(0xFF7B1FA2);
  static const Color accentSkyBlue = Color(0xFF3B82F6);

  /// Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF2C3E50);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF475569);

  /// Background colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundCard = Colors.white;
  static const Color backgroundSection = Color(0xFFF5F7FA);
  static const Color backgroundBlueLight = Color(0xFFE3F2FD);
  static const Color backgroundGreenLight = Color(0xFFE8F5E9);
  static const Color backgroundPurpleLight = Color(0xFFF3E5F5);

  /// Border colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
  static const Color borderBlueLight = Color(0xFFBBDEFB);
  static const Color borderGreenLight = Color(0xFFC8E6C9);
  static const Color borderPurpleLight = Color(0xFFE1BEE7);
  static const Color accentPurpleDark = Color(0xFF6A1B9A);

  // ==========================================================================
  // GRADIENTS
  // ==========================================================================

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueDark],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF5F7FA),
      Color(0xFFE3F2FD),
    ],
  );

  // ==========================================================================
  // TEXT STYLES
  // ==========================================================================

  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textSecondary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textMuted,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textMuted,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textMuted,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: primaryBlue,
    letterSpacing: 0.5,
  );

  // ==========================================================================
  // BORDER RADIUS
  // ==========================================================================

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  static BorderRadius borderRadiusSmall = BorderRadius.circular(radiusSmall);
  static BorderRadius borderRadiusMedium = BorderRadius.circular(radiusMedium);
  static BorderRadius borderRadiusLarge = BorderRadius.circular(radiusLarge);

  // ==========================================================================
  // SHADOWS
  // ==========================================================================

  static List<BoxShadow> shadowLight = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primaryBlue.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 3),
    ),
  ];

  // ==========================================================================
  // CARD DECORATIONS
  // ==========================================================================

  static BoxDecoration cardDecoration = BoxDecoration(
    color: backgroundCard,
    borderRadius: borderRadiusMedium,
    border: Border.all(color: borderLight.withOpacity(0.5)),
    boxShadow: shadowLight,
  );

  static BoxDecoration sectionDecoration = BoxDecoration(
    color: backgroundSection,
    borderRadius: borderRadiusSmall,
  );

  static BoxDecoration primaryCardDecoration = BoxDecoration(
    gradient: primaryGradient,
    borderRadius: borderRadiusMedium,
    boxShadow: primaryShadow,
  );

  // ==========================================================================
  // BUTTON STYLES
  // ==========================================================================

  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryBlue,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusSmall,
    ),
  );

  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: primaryBlue,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusSmall,
    ),
    side: const BorderSide(color: primaryBlue),
  );

  static ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryBlue,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusSmall,
    ),
    side: const BorderSide(color: primaryBlue),
  );

  static ButtonStyle successButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accentGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    shape: RoundedRectangleBorder(
      borderRadius: borderRadiusSmall,
    ),
  );

  // ==========================================================================
  // INPUT DECORATIONS
  // ==========================================================================

  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryBlue) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadiusMedium,
        borderSide: const BorderSide(color: accentRed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ==========================================================================
  // STATUS INDICATORS
  // ==========================================================================

  static Widget statusIndicator({
    required bool isActive,
    String? activeText,
    String? inactiveText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isActive ? accentGreen : accentOrange).withOpacity(0.1),
        borderRadius: borderRadiusSmall,
        border: Border.all(
          color: isActive ? accentGreen : accentOrange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: isActive ? accentGreen : accentOrange,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? (activeText ?? 'ONLINE') : (inactiveText ?? 'OFFLINE'),
            style: TextStyle(
              color: isActive ? accentGreen : accentOrange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION HEADER
  // ==========================================================================

  static Widget sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: primaryBlue, size: 16),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: labelStyle,
        ),
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  // ==========================================================================
  // THEME DATA
  // ==========================================================================

  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: backgroundLight,
        colorScheme: ColorScheme.light(
          primary: primaryBlue,
          secondary: primaryBlueDark,
          surface: backgroundCard,
          error: accentRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          iconTheme: IconThemeData(color: primaryBlue),
          titleTextStyle: TextStyle(
            color: textSecondary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: backgroundCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusMedium,
            side: BorderSide(color: borderLight.withOpacity(0.5)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryButtonStyle,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: outlinedButtonStyle,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: borderRadiusMedium,
            borderSide: BorderSide(color: borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: borderRadiusMedium,
            borderSide: BorderSide(color: borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadiusMedium,
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dividerTheme: DividerThemeData(
          color: borderLight,
          thickness: 1,
        ),
        listTileTheme: ListTileThemeData(
          iconColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusSmall,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: primaryBlueDark,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusMedium,
          ),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusLarge,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: backgroundSection,
          selectedColor: primaryBlue.withOpacity(0.2),
          labelStyle: const TextStyle(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusSmall,
          ),
        ),
      );
}

/// Extension methods for convenient access to theme properties
extension AdminThemeContext on BuildContext {
  /// Quick access to AdminTheme colors
  AdminThemeColors get adminColors => AdminThemeColors();
}

class AdminThemeColors {
  Color get primary => AdminTheme.primaryBlue;
  Color get primaryDark => AdminTheme.primaryBlueDark;
  Color get primaryLight => AdminTheme.primaryBlueLight;
  Color get success => AdminTheme.accentGreen;
  Color get warning => AdminTheme.accentOrange;
  Color get error => AdminTheme.accentRed;
  Color get textPrimary => AdminTheme.textPrimary;
  Color get textSecondary => AdminTheme.textSecondary;
  Color get textMuted => AdminTheme.textMuted;
  Color get background => AdminTheme.backgroundLight;
  Color get card => AdminTheme.backgroundCard;
  Color get section => AdminTheme.backgroundSection;
}

/// Reusable page header widget for consistent styling across all screens
class PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AdminTheme.primaryBlue, AdminTheme.primaryBlueLight],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.primaryBlueDark,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: AdminTheme.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (trailing != null) ...[
                  trailing!
                ] else
                  const SizedBox.shrink(),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AdminTheme.primaryBlue, AdminTheme.primaryBlueLight],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.primaryBlueDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing! else const SizedBox.shrink(),
              ],
            ),
    );
  }
}

/// A scaffold that shows a persistent sidebar on wide screens and a
/// Drawer-based sidebar on narrow screens. Use this for admin pages that
/// need a sidebar + content layout that adapts to screen width.
class ResponsiveScaffold extends StatelessWidget {
  final Widget sidebar;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final double breakpoint;

  const ResponsiveScaffold({
    super.key,
    required this.sidebar,
    required this.body,
    this.appBar,
    this.breakpoint = 980,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= breakpoint;

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            Container(
              width: 300,
              color: AdminTheme.backgroundSection,
              child: SafeArea(child: sidebar),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    // Narrow: show sidebar as Drawer and keep body full width
    return Scaffold(
      appBar: appBar ?? AppBar(title: const SizedBox.shrink()),
      drawer: Drawer(child: SafeArea(child: sidebar)),
      body: body,
    );
  }
}

/// Small clock widget that shows the masjid-local current time (if available)
/// by reading the `PrayerTimesProvider`'s saved location.
class MasjidClock extends StatefulWidget {
  const MasjidClock({super.key});

  @override
  State<MasjidClock> createState() => _MasjidClockState();
}

class _MasjidClockState extends State<MasjidClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Ensure timezone database is initialized for TZDateTime usage
    try {
      tz_data.initializeTimeZones();
    } catch (_) {}

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      // Attempt to get masjid-local time via saved timezone id; fall back to offset
      DateTime computed;
      try {
        final provider = Provider.of(context);
        final loc = provider.prayerSettings?.location.toMap();

        // Extract timezone id if available
        String? tzName;
        try {
          final candidate = loc?['timezone'] ?? loc?['timezoneId'] ?? loc?['timeZone'] ?? loc?['timeZoneId'];
          if (candidate is String && candidate.trim().isNotEmpty && candidate.trim().toLowerCase() != 'auto') {
            tzName = candidate.trim();
          }
        } catch (_) {}

        if (tzName != null) {
          try {
            final location = tz.getLocation(tzName);
            computed = tz.TZDateTime.now(location).toLocal();
          } catch (e) {
            // If the tzName is not a valid IANA id, fall back to offset computation
            computed = DateTime.now().toUtc().add(_offsetFromLocationDuration(loc));
          }
        } else {
          computed = DateTime.now().toUtc().add(_offsetFromLocationDuration(loc));
        }
      } catch (_) {
        computed = DateTime.now();
      }

      _now = computed;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _offsetFromLocationDuration(dynamic loc) {
    try {
      if (loc == null) return Duration.zero;
      // If explicit numeric timezone offset is provided like +9 or +9:30
      final tzField = loc['timezone'] ?? (loc['timezoneId'] ?? loc['timeZone'] ?? '');
      if (tzField is String && tzField.trim().isNotEmpty && tzField.trim().toLowerCase() != 'auto') {
        final s = tzField.trim();
        // Match formats like +9, -5, +9:30
        final match = RegExp(r'([+-]?\d{1,2})(?::(\d{1,2}))?').firstMatch(s);
        if (match != null) {
          final h = int.tryParse(match.group(1)!) ?? 0;
          final m = match.group(2) != null ? int.tryParse(match.group(2)!) ?? 0 : 0;
          final total = h * 60 + (h >= 0 ? m : -m);
          return Duration(minutes: total);
        }
        // If it's an IANA-like id, we will not reach here because caller prefers tz.getLocation.
      }

      final city = (loc['city'] ?? '').toString().toLowerCase();
      if (city.isNotEmpty && (city.contains('adelaide') || city.contains('sa'))) {
        return const Duration(hours: 9, minutes: 30);
      }

      dynamic lon = loc['longitude'] ?? loc['lng'] ?? loc['lon'];
      double? longitude;
      if (lon is num) longitude = lon.toDouble();
      if (lon is String) longitude = double.tryParse(lon);
      if (longitude != null) {
        // Compute offset in minutes using longitude/15 hours. Keep fractional offsets.
        final double hours = longitude / 15.0;
        final int totalMinutes = (hours * 60).round();
        final int clamped = totalMinutes.clamp(-12 * 60, 14 * 60);
        return Duration(minutes: clamped);
      }
    } catch (_) {}
    return Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    // Read prayer settings from provider
    dynamic loc;
    try {
      final provider = Provider.of(context);
      loc = provider.prayerSettings?.location.toMap();
    } catch (_) {
      loc = null;
    }

    final offset = _offsetFromLocation(loc);
    final utc = DateTime.now().toUtc();
    final masjidLocal = utc.add(offset);
    final timeStr = DateFormat.Hms().format(masjidLocal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 18, color: AdminTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.primaryBlue),
          ),
        ],
      ),
    );
  }

  // Added missing method to fix the error
  Duration _offsetFromLocation(dynamic loc) {
    return _offsetFromLocationDuration(loc);
  }
}

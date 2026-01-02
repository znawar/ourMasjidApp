import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_times_provider.dart';

// We'll use a simple embedded TV display widget
import 'embedded_tv_display.dart';

class TVConnectionScreen extends StatefulWidget {
  const TVConnectionScreen({super.key});

  @override
  State<TVConnectionScreen> createState() => _TVConnectionScreenState();
}

class _TVConnectionScreenState extends State<TVConnectionScreen> {
  String? _pairingCode;
  bool _loading = true;
  DateTime? _expiresAt;
  Timer? _timer;
  StreamSubscription? _pairingSub;
  static const Duration _pairingExpiry = Duration(minutes: 10);
  static const String _tvPairingCodeStorageKey = 'tvPairingCode';
  static const String _tvMasjidIdStorageKey = 'tvMasjidId';

  @override
  void initState() {
    super.initState();
    _init();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pairingSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Check if already paired
    final prefs = await SharedPreferences.getInstance();
    final savedMasjidId = (prefs.getString(_tvMasjidIdStorageKey) ?? '').trim();
    
    if (savedMasjidId.isNotEmpty && mounted) {
      // Already paired, go to TV display
      _goToTVDisplay(savedMasjidId);
      return;
    }
    
    // Check for existing code
    final savedCode = (prefs.getString(_tvPairingCodeStorageKey) ?? '').trim();
    if (savedCode.length == 6) {
      _pairingCode = savedCode;
      try {
        final p = Provider.of<PrayerTimesProvider>(context, listen: false);
        _expiresAt = p.masjidNow.add(_pairingExpiry);
      } catch (_) {
        _expiresAt = DateTime.now().add(_pairingExpiry);
      }
      _listenForClaim(savedCode);
      setState(() => _loading = false);
      return;
    }
    
    await _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() => _loading = true);
    
    final code = _createPairingCode();
    final prefs = await SharedPreferences.getInstance();
    
    try {
      await FirebaseFirestore.instance.collection('tv_pairs').doc(code).set({
        'code': code,
        'claimed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresInMinutes': _pairingExpiry.inMinutes,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating pairing doc: $e');
    }

    await prefs.setString(_tvPairingCodeStorageKey, code);
    
    if (!mounted) return;
    setState(() {
      _pairingCode = code;
      try {
        final p = Provider.of<PrayerTimesProvider>(context, listen: false);
        _expiresAt = p.masjidNow.add(_pairingExpiry);
      } catch (_) {
        _expiresAt = DateTime.now().add(_pairingExpiry);
      }
      _loading = false;
    });
    
    _listenForClaim(code);
  }

  String _createPairingCode() {
    final n = Random().nextInt(1000000);
    return n.toString().padLeft(6, '0');
  }

  void _listenForClaim(String code) {
    _pairingSub?.cancel();
    _pairingSub = FirebaseFirestore.instance
        .collection('tv_pairs')
        .doc(code)
        .snapshots()
        .listen((doc) async {
      final data = doc.data();
      if (data == null) return;
      
      final masjidId = (data['masjidId'] ?? '').toString().trim();
      if (masjidId.isEmpty) return;
      
      // Code was claimed! Save masjidId and keep pairing code so the TV
      // can detect when an admin removes the pairing and disconnect.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tvMasjidIdStorageKey, masjidId);
      await prefs.setString(_tvPairingCodeStorageKey, code);
      
      if (mounted) {
        _goToTVDisplay(masjidId);
      }
    });
  }

  void _goToTVDisplay(String masjidId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TVDisplayScreen(masjidId: masjidId),
      ),
    );
  }

  Future<void> _newCode() async {
    _pairingSub?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tvPairingCodeStorageKey);
    await _generateCode();
  }

  @override
  Widget build(BuildContext context) {
    DateTime now;
    try {
      final p = Provider.of<PrayerTimesProvider>(context, listen: false);
      now = p.masjidNow;
    } catch (_) {
      now = DateTime.now();
    }
    final remaining = _expiresAt?.difference(now);
    final minutesLeft = remaining == null
        ? null
        : (remaining.inSeconds <= 0 ? 0 : (remaining.inSeconds / 60).ceil());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tv,
                                size: 64, color: Color(0xFF1976D2)),
                            const SizedBox(height: 16),
                            const Text(
                              'Connect this TV',
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter this code in Admin Dashboard → TV Display Settings',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFF1976D2), width: 3),
                              ),
                              child: Text(
                                _pairingCode ?? '------',
                                style: const TextStyle(
                                  fontSize: 64,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (minutesLeft != null)
                              Text(
                                'Expires in ~$minutesLeft min',
                                style: TextStyle(
                                    color: Colors.grey[700], fontSize: 14),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Waiting for connection...',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: _newCode,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Generate New Code'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

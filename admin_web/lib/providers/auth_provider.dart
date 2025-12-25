import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String _masjidName = '';
  String? _userId;
  bool _useFirebase = true;

  bool get isAuthenticated => _isAuthenticated;
  String get masjidName => _masjidName;
  String? get userId => _userId;

  AuthProvider() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Check if Firebase Auth is configured
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _loadFromFirebaseUser(user);
      } else {
        // Fallback to persisted prefs to avoid blank splash
        final prefs = await SharedPreferences.getInstance();
        _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
        _masjidName = prefs.getString('masjidName') ?? '';
        _userId = prefs.getString('userId');
        notifyListeners();
      }

      // Listen for auth changes to keep state in sync
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user == null) {
          await _clearState();
        } else {
          await _loadFromFirebaseUser(user);
        }
      });
    } catch (e) {
      print('Firebase Auth not configured, using demo mode: $e');
      _useFirebase = false;
      // Restore from prefs in demo mode
      final prefs = await SharedPreferences.getInstance();
      _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;
      _masjidName = prefs.getString('masjidName') ?? '';
      _userId = prefs.getString('userId');
      notifyListeners();
    }
  }

  Future<void> _loadFromFirebaseUser(User user) async {
    _userId = user.uid;
    _isAuthenticated = true;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('masjids')
          .doc(user.uid)
          .get();
      _masjidName = doc.data()?['masjidName'] ?? _masjidName;
    } catch (e) {
      print('Could not load from Firestore: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);
    await prefs.setString('userId', user.uid);
    await prefs.setString('masjidName', _masjidName);

    notifyListeners();
  }

  Future<bool> signup(String email, String password, String masjidName) async {
    try {
      if (_useFirebase) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final uid = credential.user?.uid;
        if (uid == null) throw Exception('Unable to create user');

        // Store both `name` and `masjidName` for compatibility with the
        // mobile app (which historically queried `name`).
        await FirebaseFirestore.instance.collection('masjids').doc(uid).set({
          'masjidName': masjidName,
          'name': masjidName,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _loadFromFirebaseUser(credential.user!);
      } else {
        // Demo mode - use local storage only
        _userId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
        _masjidName = masjidName;
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userId', _userId!);
        await prefs.setString('masjidName', masjidName);

        notifyListeners();
      }
      return true;
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<bool> login(String email, String password, String masjidName) async {
    try {
      if (_useFirebase) {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        final user = credential.user;
        if (user == null) {
          throw Exception('Authentication failed');
        }

        // Load the masjid data from Firestore to verify
        final doc = await FirebaseFirestore.instance
            .collection('masjids')
            .doc(user.uid)
            .get();
        
        final storedMasjidName = (doc.data()?['masjidName'] ?? doc.data()?['name'] ?? '').toString().trim();
        final providedMasjidName = masjidName.trim();
        
        // If masjid name was provided, verify it matches the stored name
        if (providedMasjidName.isNotEmpty && storedMasjidName.isNotEmpty) {
          // Case-insensitive comparison
          if (storedMasjidName.toLowerCase() != providedMasjidName.toLowerCase()) {
            // Sign out the user since credentials don't match the masjid
            await FirebaseAuth.instance.signOut();
            throw Exception('Masjid name does not match the account credentials. Please check your masjid name.');
          }
        }

        // Credentials are valid and masjid name matches (or wasn't provided)
        await _loadFromFirebaseUser(user);
      } else {
        // Demo mode - use local storage only
        _userId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
        _masjidName = masjidName;
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isAuthenticated', true);
        await prefs.setString('userId', _userId!);
        await prefs.setString('masjidName', masjidName);

        notifyListeners();
      }
      return true;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (_useFirebase) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print('Error signing out: $e');
    }
    await _clearState();
  }

  Future<void> _clearState() async {
    _isAuthenticated = false;
    _masjidName = '';
    _userId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('masjidName');
    await prefs.remove('userId');

    notifyListeners();
  }
}
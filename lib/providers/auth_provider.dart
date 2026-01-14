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
  String? get email => FirebaseAuth.instance.currentUser?.email;

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

  /// Change the signed‑in user's password.
  ///
  /// This uses Firebase Auth and will re‑authenticate the user with
  /// their current password before applying the new one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_useFirebase) {
      throw Exception('Password change is only available with Firebase login.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user. Please sign in again.');
    }

    final currentEmail = user.email;
    if (currentEmail == null || currentEmail.trim().isEmpty) {
      throw Exception('Current email not available for re‑authentication.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );

      // Re‑authenticate then update password.
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  /// Update the signed‑in user's login email address and keep the
  /// Firestore masjid document in sync.
  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final trimmedEmail = newEmail.trim();
    if (trimmedEmail.isEmpty) {
      throw Exception('Email cannot be empty');
    }

    if (!_useFirebase) {
      throw Exception('Email change is only available with Firebase login.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user. Please sign in again.');
    }

    final currentEmail = user.email;
    if (currentEmail == null || currentEmail.trim().isEmpty) {
      throw Exception('Current email not available for re‑authentication.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: currentPassword,
      );

      // Re‑authenticate and then update the auth email.
      await user.reauthenticateWithCredential(credential);
      await user.updateEmail(trimmedEmail);

      // Keep the masjid document's email field in sync.
      if (_userId != null && _userId!.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('masjids')
            .doc(_userId)
            .set({
          'email': trimmedEmail,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  /// Update basic masjid information in Firestore and local cache.
  ///
  /// This is used by the Settings page to persist changes to the
  /// masjid name and contact details.
  Future<void> updateMasjidInfo({
    required String masjidName,
    String? address,
    String? phone,
    String? email,
  }) async {
    final trimmedName = masjidName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Masjid name cannot be empty');
    }

    _masjidName = trimmedName;

    try {
      if (_useFirebase && _userId != null && _userId!.trim().isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('masjids')
            .doc(_userId)
            .set({
          // Keep both fields in sync for compatibility with the
          // older mobile app which reads `name`.
          'masjidName': trimmedName,
          'name': trimmedName,
          if (address != null) 'address': address.trim(),
          if (phone != null) ...{
            'phone': phone.trim(),
            'phoneNumber': phone.trim(),
          },
          if (email != null) 'email': email.trim(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Failed to update masjid info: $e');
      rethrow;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('masjidName', _masjidName);
    } catch (e) {
      print('Failed to persist masjid name locally: $e');
    }

    notifyListeners();
  }
}
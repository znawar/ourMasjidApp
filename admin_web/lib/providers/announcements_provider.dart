import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:admin_web/utils/announcement_uploader.dart';

/// Simple data model for a single announcement.
///
/// This is stored in Firestore under the `announcements` collection and is
/// also used by the admin UI and TV display.
class Announcement {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime date;
  final bool active;
  final String? masjidId;
  final DateTime? expiresAt; // null means permanent (no expiration)

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.date,
    this.active = true,
    this.masjidId,
    this.expiresAt,
  });

  /// Returns true if the announcement has expired
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Returns true if the announcement is permanent (no expiration)
  bool get isPermanent => expiresAt == null;

  /// Serializes this object into the Firestore/JSON structure used by the
  /// admin panel and TV display.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      // TV reads imagePath (preferred) or image.
      'imagePath': imageUrl,
      'image': imageUrl,
      'date': Timestamp.fromDate(date),
      'active': active,
      if (masjidId != null) 'masjidId': masjidId,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  /// Creates an [Announcement] from a plain JSON/Map structure.
  static Announcement fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['date'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else {
      parsedDate =
          DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    }

    // Parse expiresAt field
    DateTime? parsedExpiresAt;
    final rawExpiresAt = json['expiresAt'];
    if (rawExpiresAt is Timestamp) {
      parsedExpiresAt = rawExpiresAt.toDate();
    } else if (rawExpiresAt != null) {
      parsedExpiresAt = DateTime.tryParse(rawExpiresAt.toString());
    }

    return Announcement(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['imagePath'] ?? json['image'] ?? json['imageUrl'] ?? '')
          .toString(),
      date: parsedDate,
      active: json['active'] == true,
      masjidId: (json['masjidId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['masjidId'] ?? '').toString().trim(),
      expiresAt: parsedExpiresAt,
    );
  }

    /// Creates an [Announcement] from a Firestore document snapshot.
    static Announcement fromFirestoreDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Announcement.fromJson(<String, dynamic>{...data, 'id': doc.id});
  }
}

/// Provider that manages the list of announcements for the current masjid
/// and exposes helper methods for CRUD operations.
class AnnouncementsProvider with ChangeNotifier {
  final List<Announcement> _announcements = [];
  String? _uploadedImageUrl;
  bool _isUploading = false;

  FirebaseFirestore? _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _masjidId;

  List<Announcement> get announcements => _announcements;
  String? get uploadedImageUrl => _uploadedImageUrl;
  bool get isUploading => _isUploading;

  AnnouncementsProvider() {
    try {
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      _firestore = null;
      debugPrint('Firebase not available in this context: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Called when the signed‑in masjid changes. Sets up a listener on the
  /// `announcements` collection for that masjid.
  void setMasjidId(String masjidId) {
    final trimmed = masjidId.trim();
    if (trimmed.isEmpty) {
      _masjidId = null;
      _subscription?.cancel();
      _announcements.clear();
      notifyListeners();
      return;
    }

    if (_masjidId == trimmed) return;
    _masjidId = trimmed;
    _startListening();
  }

  /// Begins listening to Firestore for changes to this masjid's
  /// announcements. Also performs automatic cleanup of expired items.
  void _startListening() {
    final firestore = _firestore;
    final masjidId = _masjidId;
    if (firestore == null || masjidId == null || masjidId.trim().isEmpty) {
      return;
    }

    _subscription?.cancel();
    _subscription = firestore
        .collection('announcements')
        .where('masjidId', isEqualTo: masjidId)
        .snapshots()
        .listen((snapshot) async {
      // Capture "now" once so all announcements in this snapshot use the
      // same reference point when checking for expiration.
      final now = DateTime.now();

      // Split documents into active/non-expired and expired
      final activeItems = <Announcement>[];
      final expiredIds = <String>[];

      // Split incoming docs into active and expired groups.
      for (final doc in snapshot.docs) {
        final ann = Announcement.fromFirestoreDoc(doc);

        // If it has an expiresAt in the past, mark for deletion and
        // do not include it in the in-memory list so TVs don't show it.
        if (ann.expiresAt != null && now.isAfter(ann.expiresAt!)) {
          expiredIds.add(ann.id);
          continue;
        }

        activeItems.add(ann);
      }

      // Sort with newest first so the most recent announcements appear at
      // the top of the list.
      activeItems.sort((a, b) => b.date.compareTo(a.date));
      _announcements
        ..clear()
        ..addAll(activeItems);
      notifyListeners();

      // Best-effort cleanup of expired docs in the background.
      // This keeps the collection tidy and ensures they never
      // reappear if other clients don't filter correctly.
      for (final id in expiredIds) {
        try {
          await firestore.collection('announcements').doc(id).delete();
        } catch (e) {
          debugPrint('Failed to delete expired announcement $id: $e');
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to announcements: $e');
    });
  }

  /// Opens a platform‑specific picker and uploads the image to ImgBB.
  ///
  /// The resulting public URL is stored in [_uploadedImageUrl] so the
  /// announcement form can attach it when saving.
  Future<void> uploadImage() async {
    _isUploading = true;
    notifyListeners();

    try {
      // Delegate to platform-specific uploader. On web this will open
      // a file picker and upload to ImgBB. On non-web platforms it
      // safely returns null so the app can still run.
      final url = await uploadAnnouncementImage();
      if (url != null && url.isNotEmpty) {
        _uploadedImageUrl = url;
      }
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /// Creates a new announcement document in Firestore for the current
  /// masjid. If [expiresAt] is provided, the announcement will be
  /// auto‑deleted by [_startListening] once it expires.
  Future<void> addAnnouncement(String title, String description, {DateTime? expiresAt}) async {
    final firestore = _firestore;
    final masjidId = _masjidId;
    if (firestore == null || masjidId == null || masjidId.trim().isEmpty) {
      throw Exception('Not signed in (missing masjid id)');
    }

    final docRef = firestore.collection('announcements').doc();
    final announcement = Announcement(
      id: docRef.id,
      title: title.trim(),
      description: description.trim(),
      imageUrl: _uploadedImageUrl ?? '', // Image is now optional
      date: DateTime.now(),
      active: true,
      masjidId: masjidId,
      expiresAt: expiresAt,
    );

    await docRef.set({
      ...announcement.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _uploadedImageUrl = null;
    notifyListeners();
  }

  /// Permanently deletes the announcement with the given [id].
  Future<void> deleteAnnouncement(String id) async {
    final firestore = _firestore;
    if (firestore != null) {
      await firestore.collection('announcements').doc(id).delete();
    }
  }

  /// Toggles the `active` flag for the announcement. Inactive
  /// announcements remain in Firestore but do not show on the TV.
  Future<void> toggleAnnouncement(String id) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final existing = _announcements.where((a) => a.id == id).toList();
    final currentActive = existing.isNotEmpty ? existing.first.active : false;

    await firestore.collection('announcements').doc(id).set({
      'active': !currentActive,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Clears the in‑memory uploaded image URL (used when the admin
  /// wants to choose a different image before saving).
  void clearUploadedImage() {
    _uploadedImageUrl = null;
    notifyListeners();
  }
}

import 'dart:async';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Announcement {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime date;
  final bool active;
  final String? masjidId;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.date,
    this.active = true,
    this.masjidId,
  });

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
    };
  }

  static Announcement fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['date'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else {
      parsedDate =
          DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
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
    );
  }

  static Announcement fromFirestoreDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Announcement.fromJson(<String, dynamic>{...data, 'id': doc.id});
  }
}

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
        .listen((snapshot) {
      final items = snapshot.docs.map(Announcement.fromFirestoreDoc).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      _announcements
        ..clear()
        ..addAll(items);
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to announcements: $e');
    });
  }

  Future<void> uploadImage() async {
    _isUploading = true;
    notifyListeners();

    try {
      // Create a file input element
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();

      await input.onChange.first;

      if (input.files!.isNotEmpty) {
        final file = input.files![0];
        final reader = html.FileReader();
        reader.readAsDataUrl(file);

        await reader.onLoad.first;

        _uploadedImageUrl = reader.result as String?;
      }
    } catch (e) {
      print('Error uploading image: $e');
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> addAnnouncement(String title, String description) async {
    if (_uploadedImageUrl == null) {
      throw Exception('Please upload an image first');
    }

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
      imageUrl: _uploadedImageUrl!,
      date: DateTime.now(),
      active: true,
      masjidId: masjidId,
    );

    await docRef.set({
      ...announcement.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _uploadedImageUrl = null;
    notifyListeners();
  }

  Future<void> deleteAnnouncement(String id) async {
    final firestore = _firestore;
    if (firestore != null) {
      await firestore.collection('announcements').doc(id).delete();
    }
  }

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

  void clearUploadedImage() {
    _uploadedImageUrl = null;
    notifyListeners();
  }
}

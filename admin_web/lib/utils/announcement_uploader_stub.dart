import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// Mobile/desktop implementation of image upload for announcements.
//
// This file is used on non‑web platforms via conditional imports in
// `announcement_uploader.dart`. The logic mirrors the web uploader but
// uses `image_picker` instead of the browser's file dialog.
//
// The flow is:
//   1. Open the platform gallery picker.
//   2. Read the selected file as bytes and encode to base64.
//   3. Upload the data to ImgBB and return the hosted URL.
/// Non-web implementation for picking an announcement image and uploading it
/// to ImgBB. This is used on Android/iOS/desktop so that the admin app can
/// run on phones as well.
///
/// Returns the public image URL on success, or null on cancel/failure.
Future<String?> uploadAnnouncementImage() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return null; // user cancelled
    }

    final bytes = await picked.readAsBytes();
    final base64Data = base64Encode(bytes);

    // ImgBB API key – same key used on web implementation.
    const String imgbbApiKey = '3c10d4bc4f9af5a906d48428e40d1611';

    final response = await http.post(
      Uri.parse('https://api.imgbb.com/1/upload'),
      body: {
        'key': imgbbApiKey,
        'image': base64Data,
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['success'] == true) {
        return jsonResponse['data']['url'] as String?;
      } else {
        debugPrint('ImgBB upload failed (mobile): ${jsonResponse['error']['message']}');
        return null;
      }
    } else {
      debugPrint('ImgBB upload failed (mobile) with status: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('Error uploading announcement image (mobile): $e');
    return null;
  }
}

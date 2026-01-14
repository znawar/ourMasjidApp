import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Web implementation of the announcement image uploader using ImgBB.
/// Returns the public image URL on success, or null on failure/cancel.
Future<String?> uploadAnnouncementImage() async {
  // ImgBB API key – same as used previously in AnnouncementsProvider.
  const String imgbbApiKey = '3c10d4bc4f9af5a906d48428e40d1611';

  try {
    // Create a file input element
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    await input.onChange.first;

    if (input.files == null || input.files!.isEmpty) {
      return null; // user cancelled
    }

    final file = input.files![0];

    // Read file as base64
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    final dataUrl = reader.result as String;
    // Extract base64 data (remove "data:image/xxx;base64," prefix)
    final base64Data = dataUrl.split(',').last;

    // Upload to ImgBB
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
        debugPrint('ImgBB upload failed: ${jsonResponse['error']['message']}');
        return null;
      }
    } else {
      debugPrint('ImgBB upload failed with status: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    debugPrint('Error uploading announcement image (web): $e');
    return null;
  }
}

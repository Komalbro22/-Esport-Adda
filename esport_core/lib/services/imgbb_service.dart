import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'image_optimizer.dart';

class ImgBBService {
  static const String _apiKey = 'b40febb06056bca6bfdae97dde6b481c';
  static const String _uploadUrl = 'https://api.imgbb.com/1/upload';

  /// Uploads an image to ImgBB and returns the direct image URL.
  static Future<String?> uploadImage(XFile image) async {
    try {
      // Compress image before upload
      final File originalFile = File(image.path);
      final File compressedFile = await ImageOptimizer.compressImage(originalFile);
      
      final bytes = await compressedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final response = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'key': _apiKey,
          'image': base64Image,
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['url'];
        }
      }
    } catch (e) {
      // Log error or handle as needed
      debugPrint('ImgBB Upload Error: $e');
    }
    return null;
  }
}

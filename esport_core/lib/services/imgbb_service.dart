import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImgBBService {
  static const String _apiKey = 'b40febb06056bca6bfdae97dde6b481c';
  static const String _uploadUrl = 'https://api.imgbb.com/1/upload';

  /// Uploads an image to ImgBB and returns the direct image URL.
  static Future<String?> uploadImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
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
      print('ImgBB Upload Error: $e');
    }
    return null;
  }
}

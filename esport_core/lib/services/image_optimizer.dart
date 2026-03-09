import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageOptimizer {
  /// Compresses the given [file] if it's an image.
  /// Standardizes resolution to [maxWidth] and reduces quality to [quality].
  static Future<File> compressImage(File file, {int quality = 80, int maxWidth = 1280}) async {
    final filePath = file.absolute.path;
    
    // Check if it's already a small file or not an image
    if (await file.length() < 200 * 1024) { // Less than 200KB
       return file;
    }

    final outPath = p.join(
      (await getTemporaryDirectory()).path,
      'compressed_${p.basename(filePath)}',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: quality,
      minWidth: maxWidth,
      format: CompressFormat.jpeg,
    );

    if (result == null) return file;
    
    return File(result.path);
  }
}

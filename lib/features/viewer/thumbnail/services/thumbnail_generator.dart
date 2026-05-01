import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ThumbnailGenerator {
  /// Quality used for compression — adjusted by PerfController
  static int quality = 70;

  static void setQuality(int q) {
    quality = q.clamp(40, 90);
  }

  /// Generate thumbnail bytes for an image file
  static Future<Uint8List?> generateImage(String path) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 200,
        minHeight: 200,
        quality: quality,
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Placeholder — add video_thumbnail package later
  static Future<Uint8List?> generateVideo(String path) async {
    return null;
  }

  /// Fallback when no specific generator is available
  static Future<Uint8List?> generateFallback() async {
    return null;
  }
}

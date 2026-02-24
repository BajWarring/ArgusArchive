import 'package:flutter/services.dart';

class VideoThumbnailService {
  static const MethodChannel _channel = MethodChannel('com.app.argusarchive/media_utils');
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> getThumbnail(String path) async {
    if (_cache.containsKey(path)) return _cache[path];
    try {
      final Uint8List? bytes = await _channel.invokeMethod('getVideoThumbnail', {'path': path});
      if (bytes != null) {
        _cache[path] = bytes;
        return bytes;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

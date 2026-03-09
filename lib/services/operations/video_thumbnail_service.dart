import 'package:flutter/services.dart';

class VideoThumbnailService {
  static const MethodChannel _channel = MethodChannel('com.app.argusarchive/media_utils');
  
  static final Map<String, Uint8List> _videoCache = {};
  static final Map<String, Uint8List> _audioCache = {};

  static Future<Uint8List?> getThumbnail(String path) async {
    if (_videoCache.containsKey(path)) return _videoCache[path];
    try {
      final Uint8List? bytes = await _channel.invokeMethod('getVideoThumbnail', {'path': path});
      if (bytes != null) {
        _videoCache[path] = bytes;
        return bytes;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static Future<Uint8List?> getAudioThumbnail(String path) async {
    if (_audioCache.containsKey(path)) return _audioCache[path];
    try {
      final Uint8List? bytes = await _channel.invokeMethod('getAudioThumbnail', {'path': path});
      if (bytes != null) {
        _audioCache[path] = bytes;
        return bytes;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

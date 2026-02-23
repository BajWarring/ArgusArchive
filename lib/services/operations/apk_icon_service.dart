import 'package:flutter/services.dart';
import 'dart:typed_data';

class ApkIconService {
  static const MethodChannel _channel = MethodChannel('com.app.argusarchive/apk_icon');
  
  // Memory cache prevents the app from constantly asking Android for the same icon
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> getApkIcon(String path) async {
    if (_cache.containsKey(path)) return _cache[path];
    
    try {
      final Uint8List? iconBytes = await _channel.invokeMethod('getApkIcon', {'path': path});
      if (iconBytes != null) {
        _cache[path] = iconBytes;
        return iconBytes;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}

import 'package:flutter/services.dart';

class ShortcutService {
  static const _channel = MethodChannel('com.app.argusarchive/shortcuts');

  static Future<bool> createVideoPlayerShortcut() async {
    try {
      return await _channel.invokeMethod('createVideoPlayerShortcut') ?? false;
    } catch (e) { 
      return false; 
    }
  }
}

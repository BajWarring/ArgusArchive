import 'package:flutter/services.dart';

class ShortcutService {
  static const _channel = MethodChannel('com.app.argusarchive/shortcuts');

  /// Requests the OS to pin the Video Player shortcut to the home screen
  static Future<bool> createVideoPlayerShortcut() async {
    try {
      return await _channel.invokeMethod('createVideoPlayerShortcut') ?? false;
    } catch (e) { 
      return false; 
    }
  }

  /// Gets the Intent route that launched the app
  static Future<String?> getInitialRoute() async {
    try {
      return await _channel.invokeMethod('getInitialRoute');
    } catch (e) {
      return null;
    }
  }

  /// Sets up a live listener for intents fired while app is in background
  static void listenToRouteChanges(void Function(String) onRouteChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRouteChanged') {
        onRouteChanged(call.arguments as String);
      }
    });
  }
}

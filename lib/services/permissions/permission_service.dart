import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Checks if the app currently has the required storage permissions.
  static Future<bool> hasStoragePermission() async {
    final plugin = DeviceInfoPlugin();
    final androidInfo = await plugin.androidInfo;

    if (androidInfo.version.sdkInt >= 30) {
      // Android 11+ (API 30+) requires MANAGE_EXTERNAL_STORAGE
      return await Permission.manageExternalStorage.isGranted;
    } else {
      // Android 10 and below requires standard STORAGE permission
      return await Permission.storage.isGranted;
    }
  }

  /// Requests the correct storage permission based on the Android version.
  static Future<bool> requestStoragePermission() async {
    final plugin = DeviceInfoPlugin();
    final androidInfo = await plugin.androidInfo;

    if (androidInfo.version.sdkInt >= 30) {
      // This will open the Android system settings page for "All files access"
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      // This will show the standard Android pop-up dialog
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }
  
  /// Helper to send users to app settings if they permanently denied permission
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

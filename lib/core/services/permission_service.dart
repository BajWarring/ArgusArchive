import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestStorage() async {
    // Android 13+ uses granular media permissions
    if (await Permission.manageExternalStorage.isGranted) return true;

    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    // Fallback for older Android
    final fallback = await Permission.storage.request();
    return fallback.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    return await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;
  }
}

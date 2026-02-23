import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/permissions/permission_service.dart';

/// Exposes the current state of the storage permission (true if granted, false if not).
final storagePermissionProvider = StateNotifierProvider<StoragePermissionNotifier, bool>((ref) {
  return StoragePermissionNotifier();
});

class StoragePermissionNotifier extends StateNotifier<bool> {
  StoragePermissionNotifier() : super(false) {
    checkPermission();
  }

  Future<void> checkPermission() async {
    final isGranted = await PermissionService.hasStoragePermission();
    state = isGranted;
  }

  Future<bool> requestPermission() async {
    final isGranted = await PermissionService.requestStoragePermission();
    state = isGranted;
    return isGranted;
  }
}

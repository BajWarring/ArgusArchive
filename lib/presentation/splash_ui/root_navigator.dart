import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permission_provider.dart';
import '../debug_ui/file_browser_debug.dart'; // We will swap this for the Production UI later
import 'permission_screen.dart';

class RootNavigator extends ConsumerWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current permission state
    final hasPermission = ref.watch(storagePermissionProvider);

    // If permission is granted, go to the file browser. Otherwise, show the permission screen.
    if (hasPermission) {
      return const FileBrowserDebug();
    } else {
      return const PermissionScreen();
    }
  }
}

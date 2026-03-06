import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permission_provider.dart';
import '../debug_ui/file_browser_debug.dart';
import 'permission_screen.dart';

class RootNavigator extends ConsumerWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(storagePermissionProvider);

    if (!hasPermission) {
      return const PermissionScreen();
    }

    // Back to the original, reliable debug UI!
    return const FileBrowserDebug();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permission_provider.dart';
import '../debug_ui/providers.dart'; // FIXED IMPORT PATH
import '../debug_ui/file_browser_debug.dart';
import '../main_ui/main_screen.dart';
import 'permission_screen.dart';

class RootNavigator extends ConsumerWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(storagePermissionProvider);
    final useDebugUi = ref.watch(useDebugUiProvider);

    if (!hasPermission) {
      return const PermissionScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          useDebugUi ? const FileBrowserDebug() : const MainScreen(),

          Positioned(
            bottom: 100,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton.extended(
                heroTag: 'ui_toggle_btn',
                backgroundColor: useDebugUi ? Colors.teal : Colors.redAccent,
                onPressed: () {
                  ref.read(useDebugUiProvider.notifier).state = !useDebugUi;
                },
                icon: const Icon(Icons.developer_mode, color: Colors.white),
                label: Text(
                  useDebugUi ? 'Switch to New UI' : 'Switch to Debug UI',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

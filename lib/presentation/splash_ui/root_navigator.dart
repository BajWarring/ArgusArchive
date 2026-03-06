import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/permission_provider.dart';
import '../main_ui/main_screen.dart';
import 'permission_screen.dart';

class RootNavigator extends ConsumerWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(storagePermissionProvider);

    if (!hasPermission) {
      return const PermissionScreen();
    }

    // Loads ONLY the new UI. No toggle button, no messy stack.
    return const MainScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class SelectionMenuDebug extends ConsumerWidget {
  final Function(String) onActionSelected;

  const SelectionMenuDebug({
    super.key,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncContents = ref.watch(directoryContentsProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.checklist),
          tooltip: 'Selection Options',
                    onSelected: (val) {
            final allFiles = asyncContents.value?.where((e) => e.path != '..').map((e) => e.path).toSet() ?? {};
            if (val == 'all') {
              ref.read(selectedFilesProvider.notifier).state = allFiles;
            } else if (val == 'none') {
              ref.read(selectedFilesProvider.notifier).state = {};
            } else if (val == 'invert') {
              final current = ref.read(selectedFilesProvider);
              ref.read(selectedFilesProvider.notifier).state = allFiles.difference(current);
            }
          },

          itemBuilder: (_) => [
            const PopupMenuItem(value: 'all', child: Text('Select All')),
            const PopupMenuItem(value: 'none', child: Text('Deselect All')),
            const PopupMenuItem(value: 'invert', child: Text('Invert Selection')),
          ],
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: onActionSelected,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy), SizedBox(width: 8), Text('Copy')])),
            const PopupMenuItem(value: 'cut', child: Row(children: [Icon(Icons.cut), SizedBox(width: 8), Text('Cut')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'compress', child: Row(children: [Icon(Icons.folder_zip), SizedBox(width: 8), Text('Compress')])),
            const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share), SizedBox(width: 8), Text('Share')])),
            const PopupMenuItem(value: 'details', child: Row(children: [Icon(Icons.info_outline), SizedBox(width: 8), Text('Details')])),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../operations/providers/file_ops_provider.dart';
import '../providers/explorer_provider.dart';
import '../../../data/models/file_model.dart';

class FileActionsSheet extends ConsumerWidget {
  final FileModel file;
  const FileActionsSheet({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ops = ref.read(fileOpsProvider);

    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.redAccent),
          title: const Text('Delete'),
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete'),
                content: Text('Delete "${file.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ops.delete(file.path);
              if (context.mounted) {
                Navigator.pop(context);
                ref.read(explorerProvider.notifier).loadFiles();
              }
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copy to Downloads'),
          onTap: () async {
            final dest = '/storage/emulated/0/Download/${file.name}';
            await ops.copy(sourcePath: file.path, destinationPath: dest);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.drive_file_move),
          title: const Text('Move to Downloads'),
          onTap: () async {
            final dest = '/storage/emulated/0/Download/${file.name}';
            await ops.move(sourcePath: file.path, destinationPath: dest);
            if (context.mounted) {
              Navigator.pop(context);
              ref.read(explorerProvider.notifier).loadFiles();
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Rename'),
          onTap: () async {
            final controller =
                TextEditingController(text: file.name);
            final newName = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Rename'),
                content: TextField(controller: controller),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Rename'),
                  ),
                ],
              ),
            );
            if (newName != null && newName.isNotEmpty) {
              final parent =
                  file.path.substring(0, file.path.lastIndexOf('/'));
              await ops.rename(file.path, '$parent/$newName');
              if (context.mounted) {
                Navigator.pop(context);
                ref.read(explorerProvider.notifier).loadFiles();
              }
            }
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../ui_theme.dart';
import '../../../core/enums/file_type.dart';
import '../../debug_ui/providers.dart';

class BrowserView extends ConsumerWidget {
  final String currentPath;
  final Function(String) onFolderEnter;

  const BrowserView({super.key, required this.currentPath, required this.onFolderEnter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REAL DATA: Fetch actual directory contents
    final asyncFiles = ref.watch(directoryContentsProvider(currentPath));

    return asyncFiles.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ArgusColors.primary)),
      error: (err, stack) => Center(child: Text('Error loading files: $err', style: const TextStyle(color: Colors.red))),
      data: (files) {
        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('Folder is empty', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            )
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final isFolder = file.isDirectory;
            
            // Dynamic Icon based on real FileType
            IconData icon;
            Color iconColor;
            if (isFolder) { icon = Icons.folder; iconColor = ArgusColors.primary; }
            else if (file.type == FileType.video) { icon = Icons.movie; iconColor = Colors.purple; }
            else if (file.type == FileType.image) { icon = Icons.image; iconColor = Colors.blue; }
            else if (file.type == FileType.archive) { icon = Icons.folder_zip; iconColor = Colors.orange; }
            else if (file.path.toLowerCase().endsWith('.apk')) { icon = Icons.android; iconColor = Colors.green; }
            else { icon = Icons.insert_drive_file; iconColor = Colors.grey; }

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (isFolder) {
                  onFolderEnter(file.path);
                } else {
                   // REAL DATA: Trigger your actual File Handlers!
                   final handlers = ref.read(fileHandlerRegistryProvider);
                   final adapter = ref.read(storageAdapterProvider);
                   bool handled = false;
                   for (var handler in handlers) {
                     if (handler.canHandle(file)) {
                       await handler.open(context, file, adapter);
                       handled = true;
                       break;
                     }
                   }
                   if (!handled && context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app found to open this file.')));
                   }
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.1),
                      child: Icon(icon, color: iconColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.basename(file.path), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            isFolder ? 'Folder' : '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB • ${file.modifiedAt.day}/${file.modifiedAt.month}/${file.modifiedAt.year}', 
                            style: const TextStyle(fontSize: 12, color: Colors.grey)
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onPressed: () { /* Show bottom sheet here */ }
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
}

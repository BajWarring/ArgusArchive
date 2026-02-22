import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';
import 'providers.dart';

/// Minimal UI to verify the StorageAdapter reads correctly.
class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final contentsAsyncValue = ref.watch(directoryContentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug File Browser'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              currentPath,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          // Handle back navigation for directories
          if (currentPath.split('/').length > 2) { // Extremely basic root check
             final parent = PathUtils.join(currentPath, '..');
             ref.read(currentPathProvider.notifier).state = parent;
             return false;
          }
          return true;
        },
        child: contentsAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
          ),
          data: (files) {
            if (files.isEmpty) {
              return const Center(child: Text('Empty Directory'));
            }

            // Sort directories first, then alphabetically
            files.sort((a, b) {
              if (a.isDirectory && !b.isDirectory) return -1;
              if (!a.isDirectory && b.isDirectory) return 1;
              return a.path.compareTo(b.path);
            });

            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                
                return ListTile(
                  leading: Icon(
                    file.isDirectory ? Icons.folder : _getIconForType(file.type),
                    color: file.isDirectory ? Colors.amber : Colors.blueGrey,
                  ),
                  title: Text(PathUtils.getName(file.path)),
                  subtitle: Text(
                    file.isDirectory ? 'Folder' : '${(file.size / 1024).toStringAsFixed(2)} KB',
                  ),
                  onTap: () {
                    if (file.isDirectory) {
                      // Navigate into folder by updating the provider state
                      ref.read(currentPathProvider.notifier).state = file.path;
                    } else {
                      // Stub: File handlers will take over here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tapped file: ${PathUtils.getName(file.path)}')),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _getIconForType(FileType type) {
    switch (type) {
      case FileType.image: return Icons.image;
      case FileType.video: return Icons.movie;
      case FileType.audio: return Icons.audiotrack;
      case FileType.document: return Icons.description;
      case FileType.archive: return Icons.archive;
      default: return Icons.insert_drive_file;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../adapters/virtual/zip_archive_adapter.dart';
import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';
import 'providers.dart';
import 'search_debug.dart';

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final contentsAsyncValue = ref.watch(directoryContentsProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);
    final registry = ref.watch(fileHandlerRegistryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug File Browser'),
        actions: [
          // Button to start background indexing for the current directory
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Build Search Index',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Indexing started in background...')),
              );
              try {
                final indexer = await ref.read(indexServiceProvider.future);
                // Start crawling from the current directory
                await indexer.start(rootPath: currentPath, rebuild: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Indexing complete!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Indexing failed: $e')),
                  );
                }
              }
            },
          ),
          // Button to open the Search UI
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Files',
            onPressed: () {
              // Reset the query before opening
              ref.read(searchQueryProvider.notifier).state = '';
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SearchDebugScreen()),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              currentAdapter is ZipArchiveAdapter 
                  ? 'ZIP: ${PathUtils.getName(currentAdapter.zipFilePath)} -> $currentPath'
                  : currentPath,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (currentAdapter is ZipArchiveAdapter) {
            if (currentPath == '/' || currentPath.isEmpty) {
              final parentPath = ref.read(realParentPathProvider);
              if (parentPath != null) {
                ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
                ref.read(currentPathProvider.notifier).state = parentPath;
                ref.read(realParentPathProvider.notifier).state = null;
                return false;
              }
            } else {
              final parent = PathUtils.join(currentPath, '..');
              ref.read(currentPathProvider.notifier).state = parent == '.' ? '/' : parent;
              return false;
            }
          } else {
            if (currentPath.split('/').length > 2) {
               final parent = PathUtils.join(currentPath, '..');
               ref.read(currentPathProvider.notifier).state = parent;
               return false;
            }
          }
          return true;
        },
        child: contentsAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error: $err\n\n(Did you grant storage permissions?)', 
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (files) {
            if (files.isEmpty) {
              return const Center(child: Text('Empty Directory'));
            }

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
                      ref.read(currentPathProvider.notifier).state = file.path;
                    } 
                    else if (file.path.toLowerCase().endsWith('.zip') && currentAdapter is! ZipArchiveAdapter) {
                      ref.read(realParentPathProvider.notifier).state = currentPath;
                      ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(zipFilePath: file.path);
                      ref.read(currentPathProvider.notifier).state = '/'; 
                    } 
                    else {
                      final handler = registry.handlerFor(file);
                      
                      if (handler != null) {
                        handler.open(context, file, currentAdapter);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('No handler found for: ${PathUtils.getName(file.path)}')),
                        );
                      }
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

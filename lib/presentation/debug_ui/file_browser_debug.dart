import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../adapters/virtual/zip_archive_adapter.dart';
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../core/utils/path_utils.dart';
import '../../services/transfer/transfer_task.dart';
import 'providers.dart';
import 'search_debug.dart';
import 'transfer_debug.dart';

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({super.key});

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
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Background Tasks',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TransferDebugScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Build Search Index',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Indexing started in background...')),
              );
              try {
                final indexer = await ref.read(indexServiceProvider.future);
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
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Files',
            onPressed: () {
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
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          
          if (currentAdapter is ZipArchiveAdapter) {
            if (currentPath == '/' || currentPath.isEmpty) {
              final parentPath = ref.read(realParentPathProvider);
              if (parentPath != null) {
                ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
                ref.read(currentPathProvider.notifier).state = parentPath;
                ref.read(realParentPathProvider.notifier).state = null;
              } else {
                Navigator.of(context).pop();
              }
            } else {
              final parent = PathUtils.join(currentPath, '..');
              ref.read(currentPathProvider.notifier).state = parent == '.' ? '/' : parent;
            }
          } else {
            if (currentPath.split('/').length > 2) {
               final parent = PathUtils.join(currentPath, '..');
               ref.read(currentPathProvider.notifier).state = parent;
            } else {
               Navigator.of(context).pop();
            }
          }
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
            if (files.isEmpty) return const Center(child: Text('Empty Directory'));

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
                  onLongPress: () {
                    _showFileOperationsMenu(context, ref, file);
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

  void _showFileOperationsMenu(BuildContext context, WidgetRef ref, FileEntry file) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enqueueTask(ref, file, TransferOperation.copy, '${file.path}_copy');
                },
              ),
              ListTile(
                leading: const Icon(Icons.compress, color: Colors.orange),
                title: const Text('Compress to ZIP'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enqueueTask(ref, file, TransferOperation.compress, '${file.path}.zip');
                },
              ),
              if (file.path.toLowerCase().endsWith('.zip'))
                ListTile(
                  leading: const Icon(Icons.folder_zip, color: Colors.green),
                  title: const Text('Extract ZIP'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final destPath = file.path.substring(0, file.path.length - 4);
                    _enqueueTask(ref, file, TransferOperation.extract, destPath);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete File'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enqueueTask(ref, file, TransferOperation.delete, '');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _enqueueTask(WidgetRef ref, FileEntry file, TransferOperation operation, String destPath) {
    final queue = ref.read(transferQueueProvider);
    final currentAdapter = ref.read(storageAdapterProvider);
    
    if (currentAdapter is ZipArchiveAdapter) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        const SnackBar(content: Text('Operations inside virtual ZIPs are not supported yet.')),
      );
      return;
    }

    final task = TransferTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      sourcePath: file.path,
      destPath: destPath,
      totalBytes: file.size,
      operation: operation,
    );

    queue.enqueue(task, currentAdapter, currentAdapter);

    ScaffoldMessenger.of(ref.context).showSnackBar(
      SnackBar(content: Text('${operation.name.toUpperCase()} queued. Check Background Tasks.')),
    );
  }
}

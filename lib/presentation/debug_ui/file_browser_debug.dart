import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// Make sure these imports map correctly to your project structure!
import 'providers.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../services/storage/storage_volumes_service.dart';
import '../../services/operations/archive_service.dart';

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);
    final asyncContents = ref.watch(directoryContentsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // Custom back button navigation logic
        if (currentAdapter is! LocalStorageAdapter) {
          final parentPath = ref.read(realParentPathProvider);
          if (parentPath != null) {
            ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
            ref.read(currentPathProvider.notifier).state = parentPath;
            ref.read(realParentPathProvider.notifier).state = null;
          } else {
            Navigator.of(context).pop();
          }
        } else {
          if (currentPath == '/storage/emulated/0' || currentPath == '/') {
             // Let Android OS handle backing out of the app
             Navigator.of(context).pop();
          } else {
             final parent = p.dirname(currentPath);
             ref.read(currentPathProvider.notifier).state = parent;
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.basename(currentPath).isEmpty ? "Root" : p.basename(currentPath)),
          actions: [
            // Drive Picker Icon
            IconButton(
              icon: const Icon(Icons.sd_card),
              tooltip: 'Storage Volumes',
              onPressed: () async {
                final roots = await StorageVolumesService.getStorageRoots();
                if (context.mounted) {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: roots.map((rootPath) {
                            final isInternal = rootPath == '/storage/emulated/0';
                            return ListTile(
                              leading: Icon(
                                isInternal ? Icons.phone_android : Icons.sd_storage,
                                color: isInternal ? Colors.teal : Colors.amber,
                              ),
                              title: Text(isInternal ? 'Internal Storage' : 'SD Card / USB'),
                              subtitle: Text(rootPath, style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
                                ref.read(currentPathProvider.notifier).state = rootPath;
                                Navigator.pop(ctx);
                              },
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
        body: asyncContents.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          data: (files) {
            if (files.isEmpty) {
              return const Center(child: Text("Empty directory"));
            }

            // 1. Logic to show the "Go Back" folder at the top
            final canGoBack = currentPath != '/storage/emulated/0' && currentPath != '/';
            final itemCount = canGoBack ? files.length + 1 : files.length;

            return ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                
                // ==========================================
                // RENDER "GO BACK" FOLDER
                // ==========================================
                if (canGoBack && index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.drive_folder_upload, color: Colors.blueGrey, size: 40),
                    title: const Text('..'),
                    subtitle: const Text('Go back'),
                    onTap: () {
                      final parent = p.dirname(currentPath);
                      ref.read(currentPathProvider.notifier).state = parent;
                    },
                  );
                }

                // ==========================================
                // RENDER FILES & FOLDERS
                // ==========================================
                final fileIndex = canGoBack ? index - 1 : index;
                final file = files[fileIndex];
                final isDirectory = file.isDirectory;

                return ListTile(
                  leading: Icon(
                    isDirectory ? Icons.folder : Icons.insert_drive_file,
                    color: isDirectory ? Colors.amber : Colors.tealAccent,
                    size: 40,
                  ),
                  title: Text(file.name),
                  
                  // Dynamic Info Subtitle
                  subtitle: isDirectory
                      ? FutureBuilder<int>(
                          // Quick background check of folder contents
                          future: currentAdapter is LocalStorageAdapter 
                              ? Directory(file.path).list().length 
                              : Future.value(0), // Skip counting if inside a virtual ZIP
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text('${snapshot.data} items');
                            }
                            return const Text('Counting...');
                          },
                        )
                      : Text('${(file.size / 1024).toStringAsFixed(2)} KB'),

                  onTap: () async {
                    if (isDirectory) {
                      ref.read(currentPathProvider.notifier).state = file.path;
                    } else {
                      
                      // Check if it's an archive. 
                      // If we are on Local Storage, we use the Magic Number reader!
                      bool isArchive = false;
                      if (currentAdapter is LocalStorageAdapter) {
                         isArchive = await ArchiveService.isArchiveFile(file.path);
                      } else {
                         // Fallback inside virtual zips
                         final ext = p.extension(file.path).toLowerCase();
                         isArchive = (ext == '.zip' || ext == '.apk');
                      }

                      if (isArchive) {
                         // (Note: Requires your ZipArchiveAdapter to be imported and active)
                         // ref.read(realParentPathProvider.notifier).state = currentPath;
                         // ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(file.path);
                         // ref.read(currentPathProvider.notifier).state = '/';
                         
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Archive viewing logic triggered!'))
                         );
                      } else {
                         ref.read(fileHandlerRegistryProvider).handle(context, file);
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
}

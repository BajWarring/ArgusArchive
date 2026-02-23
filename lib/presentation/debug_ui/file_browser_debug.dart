import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'providers.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../services/storage/storage_volumes_service.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);
    final asyncContents = ref.watch(directoryContentsProvider);
    final clipboard = ref.watch(clipboardProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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

        // ==========================================
        // DYNAMIC FLOATING ACTION BUTTON
        // ==========================================
        floatingActionButton: clipboard.action != ClipboardAction.none && clipboard.paths.isNotEmpty
            ? FloatingActionButton.extended(
                backgroundColor: clipboard.action == ClipboardAction.extract ? Colors.orange : Colors.teal,
                onPressed: () => _handleFabAction(context, ref, currentPath),
                icon: Icon(
                  clipboard.action == ClipboardAction.extract ? Icons.unarchive : 
                  clipboard.action == ClipboardAction.cut ? Icons.move_to_inbox : Icons.paste, 
                  color: Colors.white
                ),
                label: Text(
                  clipboard.action == ClipboardAction.extract ? 'Extract Here' :
                  clipboard.action == ClipboardAction.cut ? 'Move Here (${clipboard.paths.length})' : 'Paste Here (${clipboard.paths.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,

        body: asyncContents.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          data: (files) {
            if (files.isEmpty) return const Center(child: Text("Empty directory"));

            final canGoBack = currentPath != '/storage/emulated/0' && currentPath != '/';
            final itemCount = canGoBack ? files.length + 1 : files.length;

            return ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
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
                  subtitle: isDirectory
                      ? FutureBuilder<int>(
                          future: currentAdapter is LocalStorageAdapter
                              ? Directory(file.path).list().length
                              : Future.value(0),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) return Text('${snapshot.data} items');
                            return const Text('Counting...');
                          },
                        )
                      : Text('${(file.size / 1024).toStringAsFixed(2)} KB'),

                  // ==========================================
                  // TAP (CLICK) HANDLER
                  // ==========================================
                  onTap: () async {
                    if (isDirectory) {
                      ref.read(currentPathProvider.notifier).state = file.path;
                    } else {
                      bool isArchive = false;
                      if (currentAdapter is LocalStorageAdapter) {
                        isArchive = await ArchiveService.isArchiveFile(file.path);
                      } else {
                        final ext = p.extension(file.path).toLowerCase();
                        isArchive = (ext == '.zip' || ext == '.apk');
                      }

                      final isApk = p.extension(file.path).toLowerCase() == '.apk';

                      if (isArchive && context.mounted) {
                        _showArchiveTapMenu(context, ref, file.path, isApk: isApk);
                      } else if (context.mounted) {
                        ref.read(fileHandlerRegistryProvider).handle(context, file);
                      }
                    }
                  },

                  // ==========================================
                  // HOLD (LONG PRESS) HANDLER
                  // ==========================================
                  onLongPress: () async {
                    bool isArchive = false;
                    if (!isDirectory && currentAdapter is LocalStorageAdapter) {
                      isArchive = await ArchiveService.isArchiveFile(file.path);
                    }
                    final isApk = p.extension(file.path).toLowerCase() == '.apk';
                    
                    if (context.mounted) {
                      _showLongPressMenu(context, ref, file.path, isDirectory, isArchive, isApk);
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

  // ==========================================
  // ARCHIVE & APK TAP MENU
  // ==========================================
  void _showArchiveTapMenu(BuildContext context, WidgetRef ref, String filePath, {required bool isApk}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isApk)
              ListTile(
                leading: const Icon(Icons.android, color: Colors.green),
                title: const Text('Install APK'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Delegate to your file handler to open Android Package Installer
                  ref.read(fileHandlerRegistryProvider).handle(context, FileEntry(path: filePath, name: p.basename(filePath), size: 0, lastModified: DateTime.now(), isDirectory: false));
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Contents'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(realParentPathProvider.notifier).state = ref.read(currentPathProvider);
                // ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(filePath);
                // ref.read(currentPathProvider.notifier).state = '/';
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viewing Archive...')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.unarchive, color: Colors.orange),
              title: const Text('Extract Here'),
              onTap: () async {
                Navigator.pop(ctx);
                final dest = p.dirname(filePath);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting...')));
                await ArchiveService.extractZip(filePath, dest);
                ref.invalidate(directoryContentsProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move, color: Colors.teal),
              title: const Text('Extract To...'),
              subtitle: const Text('Choose a different folder'),
              onTap: () {
                Navigator.pop(ctx);
                // Trigger the new Extract Navigation Workflow
                ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navigate to destination and tap Extract Here')));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DYNAMIC LONG PRESS MENU
  // ==========================================
  void _showLongPressMenu(BuildContext context, WidgetRef ref, String filePath, bool isDirectory, bool isArchive, bool isApk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(p.basename(filePath), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              
              if (isApk)
                ListTile(
                  leading: const Icon(Icons.android, color: Colors.green),
                  title: const Text('Install'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(fileHandlerRegistryProvider).handle(context, FileEntry(path: filePath, name: p.basename(filePath), size: 0, lastModified: DateTime.now(), isDirectory: false));
                  },
                ),

              if (isArchive) ...[
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.blue),
                  title: const Text('View Contents'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(realParentPathProvider.notifier).state = ref.read(currentPathProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viewing Archive...')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.unarchive, color: Colors.orange),
                  title: const Text('Extract Here'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ArchiveService.extractZip(filePath, p.dirname(filePath));
                    ref.invalidate(directoryContentsProvider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_move, color: Colors.teal),
                  title: const Text('Extract To...'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract);
                  },
                ),
              ],

              if (!isDirectory)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(fileHandlerRegistryProvider).handle(context, FileEntry(path: filePath, name: p.basename(filePath), size: 0, lastModified: DateTime.now(), isDirectory: false));
                  },
                ),

              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.copy);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_cut),
                title: const Text('Cut'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.cut);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_zip, color: Colors.teal),
                title: const Text('Compress to ZIP'),
                onTap: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...')));
                  final zipDest = p.join(p.dirname(filePath), '${p.basename(filePath)}.zip');
                  await ArchiveService.compressEntity(filePath, zipDest);
                  ref.invalidate(directoryContentsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context, ref, filePath);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DELETE CONFIRMATION DIALOG
  // ==========================================
  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to permanently delete "${p.basename(filePath)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FileOperationsService.deleteEntity(filePath);
              ref.invalidate(directoryContentsProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UNIVERSAL FAB HANDLER (Paste, Move, Extract)
  // ==========================================
  Future<void> _handleFabAction(BuildContext context, WidgetRef ref, String destDir) async {
    final clipboard = ref.read(clipboardProvider);
    
    // 1. Handle Extract Action
    if (clipboard.action == ClipboardAction.extract) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting...')));
      await ArchiveService.extractZip(clipboard.paths.first, destDir);
      ref.read(clipboardProvider.notifier).state = ClipboardState(); // Clear memory
      ref.invalidate(directoryContentsProvider);
      return;
    }

    // 2. Handle Copy / Cut Actions
    for (String sourcePath in clipboard.paths) {
      bool success;
      if (clipboard.action == ClipboardAction.copy) {
        success = await FileOperationsService.copyEntity(sourcePath, destDir, autoRename: false);
      } else {
        success = await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
      }

      if (!success && context.mounted) {
        final action = await _showCollisionDialog(context, sourcePath);
        if (action == 'replace') {
          final targetPath = p.join(destDir, p.basename(sourcePath));
          await FileOperationsService.deleteEntity(targetPath);
          if (clipboard.action == ClipboardAction.copy) {
            await FileOperationsService.copyEntity(sourcePath, destDir, autoRename: false);
          } else {
            await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
          }
        } else if (action == 'rename') {
          if (clipboard.action == ClipboardAction.copy) {
            await FileOperationsService.copyEntity(sourcePath, destDir, autoRename: true);
          } else {
            await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: true);
          }
        }
      }
    }

    if (clipboard.action == ClipboardAction.cut) {
      ref.read(clipboardProvider.notifier).state = ClipboardState();
    }
    
    ref.invalidate(directoryContentsProvider);
  }

  // ==========================================
  // COLLISION DIALOG
  // ==========================================
  Future<String?> _showCollisionDialog(BuildContext context, String sourcePath) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('File Already Exists'),
        content: Text('A file named "${p.basename(sourcePath)}" already exists in this location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'rename'), child: const Text('Keep Both')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'), 
            child: const Text('Replace', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}

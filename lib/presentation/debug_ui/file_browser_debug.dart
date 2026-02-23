import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'providers.dart';
import 'search_debug.dart'; // Added for Search routing
import '../../adapters/local/local_storage_adapter.dart';
import '../../adapters/virtual/zip_archive_adapter.dart'; // IMPORTED THE ZIP ADAPTER!
import '../../services/storage/storage_volumes_service.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';
import '../../core/models/file_entry.dart';

// Local provider to handle sorting states
enum FileSortType { name, size, date }
final fileSortProvider = StateProvider<FileSortType>((ref) => FileSortType.name);

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);
    final asyncContents = ref.watch(directoryContentsProvider);
    
    final clipboard = ref.watch(clipboardProvider);
    final selectedFiles = ref.watch(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If in Selection Mode, back button clears selection
        if (isSelectionMode) {
          ref.read(selectedFilesProvider.notifier).state = {};
          return;
        }

        // 2. Virtual Archive Navigation
        if (currentAdapter is! LocalStorageAdapter) {
          final parentPath = ref.read(realParentPathProvider);
          if (parentPath != null) {
            ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
            ref.read(currentPathProvider.notifier).state = parentPath;
            ref.read(realParentPathProvider.notifier).state = null;
          } else {
            Navigator.of(context).pop();
          }
        } 
        // 3. Normal File Navigation
        else {
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
          // Change title if in selection mode
          title: Text(isSelectionMode 
              ? "${selectedFiles.length} Selected" 
              : p.basename(currentPath).isEmpty ? "Root" : p.basename(currentPath)),
          
          leading: isSelectionMode 
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(selectedFilesProvider.notifier).state = {},
                )
              : null, // Default back button behavior

          actions: [
            if (!isSelectionMode) ...[
              // SEARCH ICON
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchDebugScreen())),
              ),
              // VOLUME PICKER
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
                                title: Text(isInternal ? 'Internal Storage' : 'SD Card'),
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
              // 3-DOT MENU (Sorting & Indexing)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'sort_name') {
                    ref.read(fileSortProvider.notifier).state = FileSortType.name;
                  } else if (value == 'sort_size') {
                    ref.read(fileSortProvider.notifier).state = FileSortType.size;
                  } else if (value == 'sort_date') {
                    ref.read(fileSortProvider.notifier).state = FileSortType.date;
                  } else if (value == 'index') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning storage to build Search Index...')));
                    final indexer = await ref.read(indexServiceProvider.future);
                    // Starts background scan
                    await indexer.start(rootPath: '/storage/emulated/0', rebuild: true);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indexing started in background!')));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'sort_name', child: Text('Sort by Name')),
                  const PopupMenuItem(value: 'sort_size', child: Text('Sort by Size')),
                  const PopupMenuItem(value: 'sort_date', child: Text('Sort by Date')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'index', child: Text('Rebuild Search Index')),
                ],
              ),
            ]
          ],
        ),

        // ==========================================
        // FLOATING ACTION BUTTON (Paste / Extract)
        // ==========================================
        floatingActionButton: clipboard.action != ClipboardAction.none && clipboard.paths.isNotEmpty && !isSelectionMode
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

            // ==========================================
            // SMART SORTING (Folders First, then by chosen type)
            // ==========================================
            final sortType = ref.watch(fileSortProvider);
            final sortedFiles = List<FileEntry>.from(files);
            
            sortedFiles.sort((a, b) {
              if (a.isDirectory && !b.isDirectory) return -1;
              if (!a.isDirectory && b.isDirectory) return 1;
              
              if (sortType == FileSortType.size) return b.size.compareTo(a.size);
              if (sortType == FileSortType.date) return b.modifiedAt.compareTo(a.modifiedAt);
              
              return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
            });

            final canGoBack = currentPath != '/storage/emulated/0' && currentPath != '/';
            final itemCount = canGoBack ? sortedFiles.length + 1 : sortedFiles.length;

            return ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (canGoBack && index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.drive_folder_upload, color: Colors.blueGrey, size: 40),
                    title: const Text('..'),
                    subtitle: const Text('Go back'),
                    onTap: () {
                      if (isSelectionMode) return;
                      final parent = p.dirname(currentPath);
                      ref.read(currentPathProvider.notifier).state = parent;
                    },
                  );
                }

                final fileIndex = canGoBack ? index - 1 : index;
                final file = sortedFiles[fileIndex];
                final isDirectory = file.isDirectory;
                final isSelected = selectedFiles.contains(file.path);

                return ListTile(
                  // Selection Darkening
                  tileColor: isSelected ? Colors.teal.withValues(alpha: 0.2) : null,
                  leading: Stack(
                    children: [
                      Icon(
                        isDirectory ? Icons.folder : Icons.insert_drive_file,
                        color: isDirectory ? Colors.amber : Colors.tealAccent,
                        size: 40,
                      ),
                      if (isSelected)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(Icons.check_circle, color: Colors.teal, size: 20),
                        )
                    ],
                  ),
                  title: Text(p.basename(file.path)),
                  subtitle: isDirectory
                      ? FutureBuilder<int>(
                          future: currentAdapter is LocalStorageAdapter
                              ? Directory(file.path).list().length
                              : Future.value(0),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) return Text('${snapshot.data} items');
                            return const Text('...');
                          },
                        )
                      : Text('${(file.size / 1024).toStringAsFixed(2)} KB'),

                  // ==========================================
                  // TAP (CLICK) HANDLER
                  // ==========================================
                  onTap: () async {
                    // SELECTION MODE OVERRIDE
                    if (isSelectionMode) {
                      final set = Set<String>.from(selectedFiles);
                      if (set.contains(file.path)) {
                        set.remove(file.path);
                      } else {
                        set.add(file.path);
                      }
                      ref.read(selectedFilesProvider.notifier).state = set;
                      return;
                    }

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
                        _showArchiveTapMenu(context, ref, file, isApk: isApk);
                      } else if (context.mounted) {
                        final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                        if (handler != null) {
                          handler.open(context, file, currentAdapter);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app found to open this file.')));
                        }
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
                      _showLongPressMenu(context, ref, file, isArchive, isApk);
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
  void _showArchiveTapMenu(BuildContext context, WidgetRef ref, FileEntry file, {required bool isApk}) {
    final filePath = file.path;
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
                  final adapter = ref.read(storageAdapterProvider);
                  final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                  if (handler != null) handler.open(context, file, adapter);
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('View Contents'),
              onTap: () {
                Navigator.pop(ctx);
                // UNCOMMENTED & FIXED! Opens virtual zip viewer
                ref.read(realParentPathProvider.notifier).state = ref.read(currentPathProvider);
                ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(zipFilePath: filePath);
                ref.read(currentPathProvider.notifier).state = '/';
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
  // DYNAMIC LONG PRESS MENU (Multi-Select Enabled)
  // ==========================================
  void _showLongPressMenu(BuildContext context, WidgetRef ref, FileEntry file, bool isArchive, bool isApk) {
    final filePath = file.path;
    final isDirectory = file.isDirectory;
    final selectedFiles = ref.read(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;

    // If we are in selection mode, actions apply to ALL selected files.
    final targetPaths = isSelectionMode && selectedFiles.contains(filePath) 
        ? selectedFiles.toList() 
        : [filePath];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              // RADIO BUTTON FOR MULTI-SELECT INITIALIZATION
              ListTile(
                tileColor: Colors.blueGrey.withValues(alpha: 0.2),
                leading: const Icon(Icons.radio_button_checked, color: Colors.teal),
                title: Text(isSelectionMode ? '${targetPaths.length} Items Selected' : 'Select File'),
                subtitle: Text(p.basename(filePath), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  // Start Selection Mode
                  final set = Set<String>.from(selectedFiles);
                  set.add(filePath);
                  ref.read(selectedFilesProvider.notifier).state = set;
                },
              ),
              const Divider(height: 1),
              
              if (isApk && !isSelectionMode)
                ListTile(
                  leading: const Icon(Icons.android, color: Colors.green),
                  title: const Text('Install'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final adapter = ref.read(storageAdapterProvider);
                    final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                    if (handler != null) handler.open(context, file, adapter);
                  },
                ),

              if (isArchive && !isSelectionMode) ...[
                ListTile(
                  leading: const Icon(Icons.visibility, color: Colors.blue),
                  title: const Text('View Contents'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(realParentPathProvider.notifier).state = ref.read(currentPathProvider);
                    ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(zipFilePath: filePath);
                    ref.read(currentPathProvider.notifier).state = '/';
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

              if (!isDirectory && !isApk && !isArchive && !isSelectionMode)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final adapter = ref.read(storageAdapterProvider);
                    final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                    if (handler != null) {
                      handler.open(context, file, adapter);
                    }
                  },
                ),

              ListTile(
                leading: const Icon(Icons.content_copy),
                title: Text(isSelectionMode ? 'Copy ${targetPaths.length} items' : 'Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.copy);
                  ref.read(selectedFilesProvider.notifier).state = {}; // Clear selection after action
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_cut),
                title: Text(isSelectionMode ? 'Cut ${targetPaths.length} items' : 'Cut'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.cut);
                  ref.read(selectedFilesProvider.notifier).state = {};
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_zip, color: Colors.teal),
                title: Text(isSelectionMode ? 'Compress ${targetPaths.length} items to ZIP' : 'Compress to ZIP'),
                onTap: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...')));
                  // Note: The ArchiveService currently compresses one item. For multi-item, it requires a small update later.
                  final zipDest = p.join(p.dirname(filePath), '${p.basename(filePath)}.zip');
                  await ArchiveService.compressEntity(filePath, zipDest);
                  ref.read(selectedFilesProvider.notifier).state = {};
                  ref.invalidate(directoryContentsProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(isSelectionMode ? 'Delete ${targetPaths.length} items' : 'Delete', style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context, ref, targetPaths);
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
  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, List<String> filePaths) {
    final isMultiple = filePaths.length > 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(isMultiple 
            ? 'Are you sure you want to permanently delete ${filePaths.length} items?' 
            : 'Are you sure you want to permanently delete "${p.basename(filePaths.first)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (String path in filePaths) {
                await FileOperationsService.deleteEntity(path);
              }
              ref.read(selectedFilesProvider.notifier).state = {};
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
    
    if (clipboard.action == ClipboardAction.extract) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting...')));
      await ArchiveService.extractZip(clipboard.paths.first, destDir);
      ref.read(clipboardProvider.notifier).state = ClipboardState();
      ref.invalidate(directoryContentsProvider);
      return;
    }

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

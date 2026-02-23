import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'providers.dart';
import 'search_debug.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../adapters/virtual/zip_archive_adapter.dart';
import '../../services/storage/storage_volumes_service.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';
import '../../core/models/file_entry.dart';

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
    final hasClipboard = clipboard.action != ClipboardAction.none && clipboard.paths.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (isSelectionMode) {
          ref.read(selectedFilesProvider.notifier).state = {};
          return;
        }

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
          title: Text(isSelectionMode 
              ? "${selectedFiles.length} Selected" 
              : (hasClipboard ? "Select Destination" : (p.basename(currentPath).isEmpty ? "Root" : p.basename(currentPath)))),
          
          leading: isSelectionMode 
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(selectedFilesProvider.notifier).state = {},
                )
              : (hasClipboard ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  tooltip: 'Cancel Action',
                  onPressed: () => ref.read(clipboardProvider.notifier).state = ClipboardState(),
                ) : null),

          actions: [
            if (!isSelectionMode && !hasClipboard) ...[
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchDebugScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.sd_card),
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
                    final indexer = await ref.read(indexServiceProvider.future);
                    await indexer.start(rootPath: '/storage/emulated/0', rebuild: true);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indexing started!')));
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

        floatingActionButton: hasClipboard && !isSelectionMode
            ? FloatingActionButton.extended(
                backgroundColor: clipboard.action == ClipboardAction.extract ? Colors.orange : Colors.teal,
                onPressed: () => _handleFabAction(context, ref, currentPath),
                icon: Icon(
                  clipboard.action == ClipboardAction.extract ? Icons.unarchive : 
                  clipboard.action == ClipboardAction.cut ? Icons.drive_file_move : Icons.content_paste, 
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
                      if (isSelectionMode || hasClipboard) return;
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
                          right: 0, bottom: 0,
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

                  onTap: () async {
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

                    if (hasClipboard) {
                      if (isDirectory) {
                        ref.read(currentPathProvider.notifier).state = file.path;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancel current action first.')));
                      }
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
                        }
                      }
                    }
                  },

                  onLongPress: () async {
                    if (hasClipboard) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancel current action first.')));
                      return;
                    }

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
  // CUSTOM ZIP NAME DIALOG
  // ==========================================
  Future<String?> _showZipNameDialog(BuildContext context, String defaultName) async {
    TextEditingController controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compress Files'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Archive Name', suffixText: '.zip'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Compress')),
        ],
      )
    );
  }

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
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLongPressMenu(BuildContext context, WidgetRef ref, FileEntry file, bool isArchive, bool isApk) {
    final filePath = file.path;
    final isDirectory = file.isDirectory;
    final selectedFiles = ref.read(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;

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
              ListTile(
                tileColor: Colors.blueGrey.withValues(alpha: 0.2),
                leading: const Icon(Icons.radio_button_checked, color: Colors.teal),
                title: Text(isSelectionMode ? '${targetPaths.length} Items Selected' : 'Select File'),
                subtitle: Text(p.basename(filePath), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
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
                    if (handler != null) handler.open(context, file, adapter);
                  },
                ),

              ListTile(
                leading: const Icon(Icons.content_copy),
                title: Text(isSelectionMode ? 'Copy ${targetPaths.length} items' : 'Copy'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.copy);
                  ref.read(selectedFilesProvider.notifier).state = {}; 
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
                  final defaultName = targetPaths.length == 1 ? p.basenameWithoutExtension(targetPaths.first) : 'Archive';
                  final zipName = await _showZipNameDialog(context, defaultName);
                  
                  if (zipName != null && zipName.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...')));
                    final zipDest = p.join(p.dirname(filePath), '$zipName.zip');
                    await ArchiveService.compressEntities(targetPaths, zipDest);
                    ref.read(selectedFilesProvider.notifier).state = {};
                    ref.invalidate(directoryContentsProvider);
                  }
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
    
    // 1. EXTRACT
    if (clipboard.action == ClipboardAction.extract) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting...')));
      await ArchiveService.extractZip(clipboard.paths.first, destDir);
      ref.read(clipboardProvider.notifier).state = ClipboardState();
      ref.invalidate(directoryContentsProvider);
      return;
    }

    bool applyToAll = false;
    String? bulkAction;

    // 2. COPY & MOVE
    for (String sourcePath in clipboard.paths) {
      
      // COPY logic explicitly ignores the dialog and just creates (copy) variations 
      if (clipboard.action == ClipboardAction.copy) {
        await FileOperationsService.copyEntity(sourcePath, destDir, autoRename: true);
      } 
      // MOVE logic triggers the advanced stateful collision dialog
      else if (clipboard.action == ClipboardAction.cut) {
        bool success = await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
        
        if (!success && context.mounted) {
          String action;
          
          if (applyToAll && bulkAction != null) {
            action = bulkAction!;
          } else {
            final result = await _showAdvancedCollisionDialog(context, sourcePath);
            if (result == null) break; // User clicked Cancel
            
            action = result['action'];
            if (result['applyToAll'] == true) {
              applyToAll = true;
              bulkAction = action;
            }
          }

          if (action == 'skip') {
            continue;
          } else if (action == 'replace') {
            final targetPath = p.join(destDir, p.basename(sourcePath));
            await FileOperationsService.deleteEntity(targetPath);
            await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
          } else if (action == 'rename') {
            await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: true);
          }
        }
      }
    }

    if (clipboard.action == ClipboardAction.cut || clipboard.action == ClipboardAction.copy) {
      ref.read(clipboardProvider.notifier).state = ClipboardState();
    }
    
    ref.invalidate(directoryContentsProvider);
  }

  // ==========================================
  // ADVANCED COLLISION DIALOG (Apply to All)
  // ==========================================
  Future<Map<String, dynamic>?> _showAdvancedCollisionDialog(BuildContext context, String sourcePath) {
    bool applyToAll = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('File Already Exists'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('"${p.basename(sourcePath)}" already exists in this folder.'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: applyToAll,
                      onChanged: (val) => setState(() => applyToAll = val ?? false),
                    ),
                    const Expanded(child: Text('Apply to all existing files')),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'action': 'skip', 'applyToAll': applyToAll}), 
                child: const Text('Skip')
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'action': 'rename', 'applyToAll': applyToAll}), 
                child: const Text('Rename')
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, {'action': 'replace', 'applyToAll': applyToAll}), 
                child: const Text('Replace', style: TextStyle(color: Colors.red))
              ),
            ],
          );
        }
      ),
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../core/enums/file_type.dart';

import 'providers.dart';
import 'search_debug.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../adapters/virtual/zip_archive_adapter.dart';
import '../../services/storage/storage_volumes_service.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';
import '../../services/operations/apk_icon_service.dart';
import '../../core/models/file_entry.dart';

enum FileSortType { name, size, date, type }
enum FileSortOrder { ascending, descending }

final fileSortProvider = StateProvider<FileSortType>((ref) => FileSortType.name);
final fileSortOrderProvider = StateProvider<FileSortOrder>((ref) => FileSortOrder.ascending);

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({super.key});

  String _formatPathForUI(String path) {
    if (path == '/') return 'Root';
    String formatted = path;
    if (formatted.startsWith('/storage/emulated/0')) {
      formatted = formatted.replaceFirst('/storage/emulated/0', 'Internal Storage');
    } else {
      formatted = formatted.replaceAll(RegExp(r'/storage/[A-Z0-9]{4}-[A-Z0-9]{4}'), 'SD Card');
    }
    return formatted;
  }

  // ==========================================
  // THUMBNAIL GENERATOR (Images & APKs)
  // ==========================================
  Widget _buildThumbnail(FileEntry file, StorageAdapter adapter, bool isDirectory) {
    if (isDirectory) return const Icon(Icons.folder, color: Colors.amber, size: 40);
    
    final ext = p.extension(file.path).toLowerCase();

    // 1. APK Thumbnails (Using our new Native Kotlin Channel)
    if (ext == '.apk' && adapter is LocalStorageAdapter) {
      return FutureBuilder<Uint8List?>(
        future: ApkIconService.getApkIcon(file.path),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(snapshot.data!, width: 40, height: 40, fit: BoxFit.contain, cacheWidth: 120);
          }
          return const Icon(Icons.android, color: Colors.green, size: 40);
        }
      );
    }
    
    // Fallbacks for other archives
    if (ext == '.apk') return const Icon(Icons.android, color: Colors.green, size: 40);
    if (ext == '.zip' || ext == '.rar') return const Icon(Icons.archive, color: Colors.orange, size: 40);

    // 2. Image Thumbnails (Works physically AND inside virtual archives)
    if (file.type == FileType.image) {
      if (adapter is LocalStorageAdapter) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(File(file.path), width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 120, errorBuilder: (c,e,s) => const Icon(Icons.image, color: Colors.blue, size: 40)),
        );
      } else {
        return FutureBuilder<List<int>>(
          future: adapter.openRead(file.path).then((s) => s.expand((e) => e).toList()),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(Uint8List.fromList(snapshot.data!), width: 40, height: 40, fit: BoxFit.cover, cacheWidth: 120, errorBuilder: (c,e,s) => const Icon(Icons.image, color: Colors.blue, size: 40)),
              );
            }
            return const Icon(Icons.image, color: Colors.blue, size: 40);
          }
        );
      }
    }
    
    return const Icon(Icons.insert_drive_file, color: Colors.tealAccent, size: 40);
  }

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
          titleSpacing: 0,
          leading: isSelectionMode 
              ? IconButton(icon: const Icon(Icons.close), onPressed: () => ref.read(selectedFilesProvider.notifier).state = {})
              : (hasClipboard ? IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () => ref.read(clipboardProvider.notifier).state = ClipboardState()) : null),

          title: isSelectionMode 
              ? Text("${selectedFiles.length} Selected", style: const TextStyle(fontSize: 18))
              : hasClipboard 
                  ? Text(clipboard.action == ClipboardAction.extract ? "Select Extract Destination" : "Select Destination", style: const TextStyle(fontSize: 18))
                  : PopupMenuButton<String>(
                      offset: const Offset(0, 50),
                      tooltip: 'Navigation & Drives',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(p.basename(currentPath).isEmpty ? "Root" : _formatPathForUI(p.basename(currentPath)), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(_formatPathForUI(currentPath), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      itemBuilder: (context) {
                        List<PopupMenuEntry<String>> items = [];
                        items.add(const PopupMenuItem(enabled: false, child: Text('CURRENT PATH', style: TextStyle(fontSize: 11, color: Colors.teal))));
                        
                        String cumulativePath = '/';
                        final segments = currentPath.split('/');
                        int indent = 0;
                        
                        for (int i = 0; i < segments.length; i++) {
                          if (segments[i].isEmpty) continue;
                          cumulativePath = p.join(cumulativePath, segments[i]);
                          
                          if (cumulativePath == '/storage' || cumulativePath == '/storage/emulated') continue;
                          
                          String displayName = segments[i];
                          if (cumulativePath == '/storage/emulated/0') displayName = 'Internal Storage';
                          else if (RegExp(r'^/storage/[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(cumulativePath)) displayName = 'SD Card';

                          final navPath = cumulativePath; 
                          items.add(PopupMenuItem(
                            value: 'nav|$navPath',
                            child: Padding(
                              padding: EdgeInsets.only(left: (indent * 10.0).clamp(0.0, 40.0)),
                              child: Row(children: [const Icon(Icons.subdirectory_arrow_right, size: 16), const SizedBox(width: 8), Text(displayName)]),
                            ),
                          ));
                          indent++;
                        }

                        items.add(const PopupMenuDivider());
                        items.add(const PopupMenuItem(enabled: false, child: Text('DRIVES', style: TextStyle(fontSize: 11, color: Colors.teal))));
                        items.add(const PopupMenuItem(value: 'drive|/storage/emulated/0', child: Row(children: [Icon(Icons.phone_android), SizedBox(width: 8), Text('Internal Storage')])));
                        items.add(const PopupMenuItem(value: 'drive_sd', child: Row(children: [Icon(Icons.sd_storage), SizedBox(width: 8), Text('SD Card / USB')])));
                        
                        return items;
                      },
                      onSelected: (value) async {
                        if (value.startsWith('nav|')) {
                          ref.read(currentAdapter is LocalStorageAdapter ? currentPathProvider.notifier : realParentPathProvider.notifier).state = value.split('|')[1];
                          if (currentAdapter is! LocalStorageAdapter) {
                             ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
                             ref.read(currentPathProvider.notifier).state = value.split('|')[1];
                          }
                        } else if (value.startsWith('drive|')) {
                          ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
                          ref.read(currentPathProvider.notifier).state = value.split('|')[1];
                        } else if (value == 'drive_sd') {
                          final roots = await StorageVolumesService.getStorageRoots();
                          final sdCard = roots.firstWhere((r) => r != '/storage/emulated/0', orElse: () => '');
                          if (sdCard.isNotEmpty) {
                            ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
                            ref.read(currentPathProvider.notifier).state = sdCard;
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No SD Card detected.')));
                          }
                        }
                      },
                    ),

          actions: [
            if (isSelectionMode) ...[
              PopupMenuButton<String>(
                icon: const Icon(Icons.checklist),
                tooltip: 'Selection Options',
                onSelected: (val) {
                  final allFiles = asyncContents.value?.where((e) => e.path != '..').map((e) => e.path).toSet() ?? {};
                  if (val == 'all') ref.read(selectedFilesProvider.notifier).state = allFiles;
                  else if (val == 'none') ref.read(selectedFilesProvider.notifier).state = {};
                  else if (val == 'invert') {
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
                onSelected: (val) => _handleBulkActions(context, ref, val, selectedFiles.toList()),
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
            ] else if (!hasClipboard) ...[
              IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchDebugScreen()))),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleNormalMenu(context, ref, value, currentPath),
                itemBuilder: (context) {
                  final sType = ref.watch(fileSortProvider);
                  final sOrder = ref.watch(fileSortOrderProvider);
                  return [
                    const PopupMenuItem(value: 'new_folder', child: Row(children: [Icon(Icons.create_new_folder), SizedBox(width: 8), Text('New Folder')])),
                    const PopupMenuItem(value: 'new_file', child: Row(children: [Icon(Icons.note_add), SizedBox(width: 8), Text('New File')])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(enabled: false, child: Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                    PopupMenuItem(value: 'sort_name', child: _buildSortItem('Name', sType == FileSortType.name)),
                    PopupMenuItem(value: 'sort_size', child: _buildSortItem('Size', sType == FileSortType.size)),
                    PopupMenuItem(value: 'sort_date', child: _buildSortItem('Date', sType == FileSortType.date)),
                    PopupMenuItem(value: 'sort_type', child: _buildSortItem('Type', sType == FileSortType.type)),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: 'order_asc', child: _buildSortItem('Ascending', sOrder == FileSortOrder.ascending)),
                    PopupMenuItem(value: 'order_desc', child: _buildSortItem('Descending', sOrder == FileSortOrder.descending)),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'index', child: Text('Rebuild Search Index')),
                  ];
                },
              ),
            ]
          ],
        ),

        floatingActionButton: hasClipboard && !isSelectionMode
            ? FloatingActionButton.extended(
                backgroundColor: clipboard.action == ClipboardAction.extract ? Colors.orange : Colors.teal,
                onPressed: () => _handleFabAction(context, ref, currentPath),
                icon: Icon(clipboard.action == ClipboardAction.extract ? Icons.unarchive : clipboard.action == ClipboardAction.cut ? Icons.drive_file_move : Icons.content_paste, color: Colors.white),
                label: Text(
                  clipboard.action == ClipboardAction.extract ? 'Extract Here' : clipboard.action == ClipboardAction.cut ? 'Move Here (${clipboard.paths.length})' : 'Paste Here (${clipboard.paths.length})',
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
            final sortOrder = ref.watch(fileSortOrderProvider);
            final sortedFiles = List<FileEntry>.from(files);
            
            sortedFiles.sort((a, b) {
              if (a.isDirectory && !b.isDirectory) return -1;
              if (!a.isDirectory && b.isDirectory) return 1;
              
              int result = 0;
              if (sortType == FileSortType.size) result = a.size.compareTo(b.size);
              else if (sortType == FileSortType.date) result = a.modifiedAt.compareTo(b.modifiedAt);
              else if (sortType == FileSortType.type) result = p.extension(a.path).compareTo(p.extension(b.path));
              else result = p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
              
              return sortOrder == FileSortOrder.ascending ? result : -result;
            });

            final canGoBack = currentPath != '/storage/emulated/0' && currentPath != '/';
            final itemCount = canGoBack ? sortedFiles.length + 1 : sortedFiles.length;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(directoryContentsProvider),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  
                  String dateStr = "${file.modifiedAt.day}/${file.modifiedAt.month}/${file.modifiedAt.year} ${file.modifiedAt.hour}:${file.modifiedAt.minute.toString().padLeft(2, '0')}";

                  return ListTile(
                    tileColor: isSelected ? Colors.teal.withValues(alpha: 0.2) : null,
                    leading: Stack(
                      children: [
                        _buildThumbnail(file, currentAdapter, isDirectory),
                        if (isSelected) const Positioned(right: 0, bottom: 0, child: Icon(Icons.check_circle, color: Colors.teal, size: 20))
                      ],
                    ),
                    title: Text(p.basename(file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: isDirectory
                        ? FutureBuilder<int>(
                            future: currentAdapter is LocalStorageAdapter ? Directory(file.path).list().length : Future.value(0),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) return Text('${snapshot.data} items');
                              return const Text('...');
                            },
                          )
                        : Text('${(file.size / 1024).toStringAsFixed(2)} KB'),
                    
                    trailing: Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),

                    onTap: () async {
                      if (isSelectionMode) {
                        final set = Set<String>.from(selectedFiles);
                        set.contains(file.path) ? set.remove(file.path) : set.add(file.path);
                        ref.read(selectedFilesProvider.notifier).state = set;
                        return;
                      }

                      if (hasClipboard) {
                        if (isDirectory) ref.read(currentPathProvider.notifier).state = file.path;
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

                        if (isArchive && context.mounted) {
                          _showArchiveTapMenu(context, ref, file, isApk: p.extension(file.path).toLowerCase() == '.apk');
                        } else if (context.mounted) {
                          final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                          if (handler != null) handler.open(context, file, currentAdapter);
                        }
                      }
                    },
                    onLongPress: () async {
                      if (hasClipboard) return;
                      bool isArchive = false;
                      if (!isDirectory && currentAdapter is LocalStorageAdapter) isArchive = await ArchiveService.isArchiveFile(file.path);
                      if (context.mounted) _showLongPressMenu(context, ref, file, isArchive, p.extension(file.path).toLowerCase() == '.apk');
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortItem(String text, bool isSelected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(text), if (isSelected) const Icon(Icons.check, color: Colors.teal, size: 18)],
    );
  }

  void _handleBulkActions(BuildContext context, WidgetRef ref, String action, List<String> paths) async {
    if (action == 'copy') {
      ref.read(clipboardProvider.notifier).state = ClipboardState(paths: paths, action: ClipboardAction.copy);
      ref.read(selectedFilesProvider.notifier).state = {};
    } else if (action == 'cut') {
      ref.read(clipboardProvider.notifier).state = ClipboardState(paths: paths, action: ClipboardAction.cut);
      ref.read(selectedFilesProvider.notifier).state = {};
    } else if (action == 'delete') {
      _showDeleteConfirmation(context, ref, paths);
    } else if (action == 'compress') {
      final defaultName = paths.length == 1 ? p.basenameWithoutExtension(paths.first) : 'Archive';
      final zipName = await _showZipNameDialog(context, defaultName);
      if (zipName != null && zipName.isNotEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...')));
        final zipDest = p.join(p.dirname(paths.first), '$zipName.zip');
        await ArchiveService.compressEntities(paths, zipDest);
        ref.read(selectedFilesProvider.notifier).state = {};
        ref.invalidate(directoryContentsProvider);
      }
    } else if (action == 'share') {
       final xFiles = paths.map((path) => XFile(path)).toList();
       await Share.shareXFiles(xFiles, text: 'Shared via Argus Archive');
       ref.read(selectedFilesProvider.notifier).state = {};
    } else if (action == 'details') {
      final entries = await _getEntriesFromPaths(paths, ref.read(storageAdapterProvider));
      if (context.mounted) _showDetailsDialog(context, entries);
    }
  }

  void _handleNormalMenu(BuildContext context, WidgetRef ref, String value, String currentPath) async {
    if (value.startsWith('sort_')) {
      final map = {'sort_name': FileSortType.name, 'sort_size': FileSortType.size, 'sort_date': FileSortType.date, 'sort_type': FileSortType.type};
      ref.read(fileSortProvider.notifier).state = map[value]!;
    } else if (value.startsWith('order_')) {
      ref.read(fileSortOrderProvider.notifier).state = value == 'order_asc' ? FileSortOrder.ascending : FileSortOrder.descending;
    } else if (value == 'index') {
      final indexer = await ref.read(indexServiceProvider.future);
      await indexer.start(rootPath: '/storage/emulated/0', rebuild: true);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indexing started!')));
    } else if (value == 'new_folder' || value == 'new_file') {
      final isFolder = value == 'new_folder';
      final name = await _showCreateDialog(context, isFolder ? 'New Folder' : 'New File');
      if (name != null && name.isNotEmpty) {
        final newPath = p.join(currentPath, name);
        if (isFolder) {
          await Directory(newPath).create();
        } else {
          await File(newPath).create();
        }
        ref.invalidate(directoryContentsProvider);
      }
    }
  }

  Future<String?> _showCreateDialog(BuildContext context, String title) async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Enter name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Create')),
        ],
      )
    );
  }

  Future<List<FileEntry>> _getEntriesFromPaths(List<String> paths, currentAdapter) async {
    List<FileEntry> entries = [];
    for (String path in paths) {
      bool isDir = await FileSystemEntity.isDirectory(path);
      final stat = await FileStat.stat(path);
      entries.add(FileEntry(id: path, path: path, type: isDir ? FileType.dir : FileType.unknown, size: stat.size, modifiedAt: stat.modified));
    }
    return entries;
  }

  void _showDetailsDialog(BuildContext context, List<FileEntry> files) {
    if (files.isEmpty) return;
    final isMulti = files.length > 1;
    final totalSize = files.fold(0, (sum, file) => sum + file.size);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMulti ? 'Multiple Items Details' : 'File Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMulti) ...[
                _detailRow('Name:', p.basename(files.first.path)),
                _detailRow('Type:', files.first.isDirectory ? 'Folder' : p.extension(files.first.path).toUpperCase()),
                _detailRow('Size:', '${(totalSize / 1024).toStringAsFixed(2)} KB'),
                _detailRow('Modified:', files.first.modifiedAt.toString().split('.')[0]),
                const SizedBox(height: 8),
                const Text('Location (Hold to copy):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                SelectableText(files.first.path, style: const TextStyle(fontSize: 14)), 
              ] else ...[
                _detailRow('Items Selected:', '${files.length}'),
                _detailRow('Total Size:', '${(totalSize / 1024).toStringAsFixed(2)} KB'),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (c, i) => Text('- ${p.basename(files[i].path)}', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ]
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      )
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _showLongPressMenu(BuildContext context, WidgetRef ref, FileEntry file, bool isArchive, bool isApk) {
    final filePath = file.path;
    final selectedFiles = ref.read(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;
    final targetPaths = isSelectionMode && selectedFiles.contains(filePath) ? selectedFiles.toList() : [filePath];

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
              
              if (!isSelectionMode) ...[
                if (isApk) ListTile(leading: const Icon(Icons.android, color: Colors.green), title: const Text('Install'), onTap: () { Navigator.pop(ctx); final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file); if (handler != null) handler.open(context, file, ref.read(storageAdapterProvider)); }),
                if (isArchive) ...[
                  ListTile(leading: const Icon(Icons.visibility, color: Colors.blue), title: const Text('View Contents'), onTap: () { Navigator.pop(ctx); ref.read(realParentPathProvider.notifier).state = ref.read(currentPathProvider); ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(zipFilePath: filePath); ref.read(currentPathProvider.notifier).state = '/'; }),
                  ListTile(leading: const Icon(Icons.unarchive, color: Colors.orange), title: const Text('Extract Here'), onTap: () async { Navigator.pop(ctx); await ArchiveService.extractZip(filePath, p.dirname(filePath)); ref.invalidate(directoryContentsProvider); }),
                  ListTile(leading: const Icon(Icons.drive_file_move, color: Colors.teal), title: const Text('Extract To...'), onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract); }),
                ],
                if (!file.isDirectory && !isApk && !isArchive) ListTile(leading: const Icon(Icons.open_in_new), title: const Text('Open'), onTap: () { Navigator.pop(ctx); final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file); if (handler != null) handler.open(context, file, ref.read(storageAdapterProvider)); }),
              ],

              ListTile(leading: const Icon(Icons.content_copy), title: Text(isSelectionMode ? 'Copy ${targetPaths.length} items' : 'Copy'), onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.copy); ref.read(selectedFilesProvider.notifier).state = {}; }),
              ListTile(leading: const Icon(Icons.content_cut), title: Text(isSelectionMode ? 'Cut ${targetPaths.length} items' : 'Cut'), onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.cut); ref.read(selectedFilesProvider.notifier).state = {}; }),
              ListTile(leading: const Icon(Icons.folder_zip, color: Colors.teal), title: Text(isSelectionMode ? 'Compress ${targetPaths.length} items to ZIP' : 'Compress to ZIP'), onTap: () async { Navigator.pop(ctx); final defaultName = targetPaths.length == 1 ? p.basenameWithoutExtension(targetPaths.first) : 'Archive'; final zipName = await _showZipNameDialog(context, defaultName); if (zipName != null && zipName.isNotEmpty) { if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...'))); final zipDest = p.join(p.dirname(filePath), '$zipName.zip'); await ArchiveService.compressEntities(targetPaths, zipDest); ref.read(selectedFilesProvider.notifier).state = {}; ref.invalidate(directoryContentsProvider); } }),
              ListTile(leading: const Icon(Icons.share), title: const Text('Share'), onTap: () async { Navigator.pop(ctx); final xFiles = targetPaths.map((path) => XFile(path)).toList(); await Share.shareXFiles(xFiles, text: 'Shared via Argus Archive'); ref.read(selectedFilesProvider.notifier).state = {}; }),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () async { Navigator.pop(ctx); final entries = await _getEntriesFromPaths(targetPaths, ref.read(storageAdapterProvider)); if (context.mounted) _showDetailsDialog(context, entries); }),
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(isSelectionMode ? 'Delete ${targetPaths.length} items' : 'Delete', style: const TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); _showDeleteConfirmation(context, ref, targetPaths); }),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showZipNameDialog(BuildContext context, String defaultName) async {
    TextEditingController controller = TextEditingController(text: defaultName);
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Compress Files'), content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Archive Name', suffixText: '.zip'), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Compress'))]));
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
            if (isApk) ListTile(leading: const Icon(Icons.android, color: Colors.green), title: const Text('Install APK'), onTap: () { Navigator.pop(ctx); final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file); if (handler != null) handler.open(context, file, ref.read(storageAdapterProvider)); }),
            ListTile(leading: const Icon(Icons.visibility, color: Colors.blue), title: const Text('View Contents'), onTap: () { Navigator.pop(ctx); ref.read(realParentPathProvider.notifier).state = ref.read(currentPathProvider); ref.read(storageAdapterProvider.notifier).state = ZipArchiveAdapter(zipFilePath: filePath); ref.read(currentPathProvider.notifier).state = '/'; }),
            ListTile(leading: const Icon(Icons.unarchive, color: Colors.orange), title: const Text('Extract Here'), onTap: () async { Navigator.pop(ctx); await ArchiveService.extractZip(filePath, p.dirname(filePath)); ref.read(clipboardProvider.notifier).state = ClipboardState(); ref.invalidate(directoryContentsProvider); }),
            ListTile(leading: const Icon(Icons.drive_file_move, color: Colors.teal), title: const Text('Extract To...'), onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract); }),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, List<String> filePaths) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(filePaths.length > 1 ? 'Are you sure you want to permanently delete ${filePaths.length} items?' : 'Are you sure you want to permanently delete "${p.basename(filePaths.first)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () async { Navigator.pop(ctx); for (String path in filePaths) { await FileOperationsService.deleteEntity(path); } ref.read(selectedFilesProvider.notifier).state = {}; ref.invalidate(directoryContentsProvider); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _handleFabAction(BuildContext context, WidgetRef ref, String destDir) async {
    final clipboard = ref.read(clipboardProvider);
    
    if (clipboard.action == ClipboardAction.extract) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extracting...')));
      final zipPath = clipboard.paths.first;
      
      final tempExtractDir = p.join(destDir, '.temp_extract_${DateTime.now().millisecondsSinceEpoch}');
      await Directory(tempExtractDir).create();
      
      bool success = await ArchiveService.extractZip(zipPath, tempExtractDir);
      
      if (success && context.mounted) {
         final tempEntities = Directory(tempExtractDir).listSync();
         List<String> tempPaths = tempEntities.map((e) => e.path).toList();
         
         bool applyToAll = false;
         String? bulkAction;
         for (String sourcePath in tempPaths) {
            bool moveSuccess = await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
            if (!moveSuccess && context.mounted) {
                 String action;
                 if (applyToAll && bulkAction != null) { action = bulkAction; } 
                 else {
                   final result = await _showAdvancedCollisionDialog(context, sourcePath);
                   if (result == null) break; 
                   action = result['action'];
                   if (result['applyToAll'] == true) { applyToAll = true; bulkAction = action; }
                 }
                 if (action == 'skip') { continue; } 
                 else if (action == 'replace') { await FileOperationsService.deleteEntity(p.join(destDir, p.basename(sourcePath))); await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false); } 
                 else if (action == 'rename') { await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: true); }
            }
         }
      }
      
      if (Directory(tempExtractDir).existsSync()) await Directory(tempExtractDir).delete(recursive: true);
      ref.read(clipboardProvider.notifier).state = ClipboardState();
      ref.invalidate(directoryContentsProvider);
      return;
    }

    bool applyToAll = false;
    String? bulkAction;
    for (String sourcePath in clipboard.paths) {
      if (clipboard.action == ClipboardAction.copy) {
        await FileOperationsService.copyEntity(sourcePath, destDir, autoRename: true);
      } else if (clipboard.action == ClipboardAction.cut) {
        bool success = await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
        if (!success && context.mounted) {
          String action;
          if (applyToAll && bulkAction != null) { action = bulkAction; } 
          else {
            final result = await _showAdvancedCollisionDialog(context, sourcePath);
            if (result == null) break; 
            action = result['action'];
            if (result['applyToAll'] == true) { applyToAll = true; bulkAction = action; }
          }
          if (action == 'skip') { continue; } 
          else if (action == 'replace') { await FileOperationsService.deleteEntity(p.join(destDir, p.basename(sourcePath))); await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false); } 
          else if (action == 'rename') { await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: true); }
        }
      }
    }
    if (clipboard.action == ClipboardAction.cut || clipboard.action == ClipboardAction.copy) ref.read(clipboardProvider.notifier).state = ClipboardState();
    ref.invalidate(directoryContentsProvider);
  }

  Future<Map<String, dynamic>?> _showAdvancedCollisionDialog(BuildContext context, String sourcePath) {
    bool applyToAll = false;
    return showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('File Already Exists'),
            content: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [ Text('"${p.basename(sourcePath)}" already exists.'), const SizedBox(height: 16), Row(children: [Checkbox(value: applyToAll, onChanged: (val) => setState(() => applyToAll = val ?? false)), const Expanded(child: Text('Apply to all files'))]) ],
            ),
            actions: [ TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'skip', 'applyToAll': applyToAll}), child: const Text('Skip')), TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'rename', 'applyToAll': applyToAll}), child: const Text('Rename')), TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'replace', 'applyToAll': applyToAll}), child: const Text('Replace', style: TextStyle(color: Colors.red))) ],
          );
        }
      ),
    );
  }
}

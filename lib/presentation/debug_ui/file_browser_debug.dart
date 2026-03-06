import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/file_entry.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';

import 'providers.dart';
import 'header_popup_menu_debug.dart';
import 'selection_menu_debug.dart';
import 'header_icons_debug.dart';
import 'file_thumbnail_debug.dart';
import 'file_bottom_sheets_debug.dart';
import 'file_action_handler_debug.dart';

class FileBrowserDebug extends ConsumerWidget {
  const FileBrowserDebug({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(indexServiceProvider);

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
        if (isSelectionMode) { ref.read(selectedFilesProvider.notifier).state = {}; return; }
        if (currentAdapter is! LocalStorageAdapter) {
          final parentPath = ref.read(realParentPathProvider);
          if (parentPath != null) {
            ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
            ref.read(currentPathProvider.notifier).state = parentPath;
            ref.read(realParentPathProvider.notifier).state = null;
          } else { Navigator.of(context).pop(); }
        } else {
          if (currentPath == '/storage/emulated/0' || currentPath == '/') {
            Navigator.of(context).pop();
          } else {
            ref.read(currentPathProvider.notifier).state = p.dirname(currentPath);
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
                  : HeaderPopupMenuDebug(currentPath: currentPath, currentAdapter: currentAdapter),
          actions: [
            if (isSelectionMode)
              SelectionMenuDebug(onActionSelected: (val) => FileActionHandlerDebug.handleBulkActions(context, ref, val, selectedFiles.toList()))
            else if (!hasClipboard)
              HeaderIconsDebug(
                currentPath: currentPath,
                onActionSelected: (val) => FileActionHandlerDebug.handleNormalMenu(context, ref, val, currentPath),
              ),
          ],
        ),

        floatingActionButton: hasClipboard && !isSelectionMode
            ? FloatingActionButton.extended(
                backgroundColor: clipboard.action == ClipboardAction.extract ? Colors.orange : Colors.teal,
                onPressed: () => FileActionHandlerDebug.handleFabAction(context, ref, currentPath),
                icon: Icon(
                  clipboard.action == ClipboardAction.extract ? Icons.unarchive : clipboard.action == ClipboardAction.cut ? Icons.drive_file_move : Icons.content_paste,
                  color: Colors.white,
                ),
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
            if (files.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_open, size: 64, color: Colors.grey), SizedBox(height: 8), Text("Empty directory", style: TextStyle(color: Colors.grey))]));

            final sortType = ref.watch(fileSortProvider);
            final sortOrder = ref.watch(fileSortOrderProvider);
            final sortedFiles = List<FileEntry>.from(files);

            sortedFiles.sort((a, b) {
              if (a.isDirectory && !b.isDirectory) return -1;
              if (!a.isDirectory && b.isDirectory) return 1;
              int result = 0;
              if (sortType == FileSortType.size) { result = a.size.compareTo(b.size); }
              else if (sortType == FileSortType.date) { result = a.modifiedAt.compareTo(b.modifiedAt); }
              else if (sortType == FileSortType.type) { result = p.extension(a.path).compareTo(p.extension(b.path)); }
              else { result = p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()); }
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
                        ref.read(currentPathProvider.notifier).state = p.dirname(currentPath);
                      },
                    );
                  }

                  final fileIndex = canGoBack ? index - 1 : index;
                  final file = sortedFiles[fileIndex];
                  final isDirectory = file.isDirectory;
                  final isSelected = selectedFiles.contains(file.path);
                  final name = p.basename(file.path);
                  final isHidden = name.startsWith('.');

                  final dateStr = "${file.modifiedAt.day}/${file.modifiedAt.month}/${file.modifiedAt.year} ${file.modifiedAt.hour}:${file.modifiedAt.minute.toString().padLeft(2, '0')}";

                  return ListTile(
                    tileColor: isSelected ? Colors.teal.withValues(alpha: 0.2) : null,
                    leading: Stack(children: [
                      Opacity(
                        opacity: isHidden ? 0.5 : 1.0,
                        child: FileThumbnailDebug(file: file, adapter: currentAdapter, isDirectory: isDirectory),
                      ),
                      if (isSelected) const Positioned(right: 0, bottom: 0, child: Icon(Icons.check_circle, color: Colors.teal, size: 20)),
                    ]),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isHidden ? Colors.grey : null)),
                    subtitle: isDirectory
                        ? _FolderSubtitle(path: file.path, adapter: currentAdapter)
                        : Text(_formatSize(file.size), style: const TextStyle(fontSize: 11)),
                    trailing: Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    onTap: () async {
                      if (isSelectionMode) {
                        final set = Set<String>.from(selectedFiles);
                        set.contains(file.path) ? set.remove(file.path) : set.add(file.path);
                        ref.read(selectedFilesProvider.notifier).state = set;
                        return;
                      }
                      if (hasClipboard) {
                        if (isDirectory) { ref.read(currentPathProvider.notifier).state = file.path; }
                        return;
                      }
                      if (isDirectory) {
                        ref.read(currentPathProvider.notifier).state = file.path;
                      } else {
                        bool isArchive = false;
                        if (currentAdapter is LocalStorageAdapter) {
                          isArchive = await ArchiveService.isArchiveFile(file.path);
                        }
                        if (isArchive && context.mounted) {
                          FileBottomSheetsDebug.showArchiveTapMenu(context, ref, file, isApk: p.extension(file.path).toLowerCase() == '.apk');
                        } else if (context.mounted) {
                          final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                          if (handler != null) { handler.open(context, file, currentAdapter); }
                        }
                      }
                    },
                    onLongPress: () async {
                      if (hasClipboard) return;
                      bool isArchive = false;
                      if (!isDirectory && currentAdapter is LocalStorageAdapter) {
                        isArchive = await ArchiveService.isArchiveFile(file.path);
                      }
                      if (context.mounted) {
                        FileBottomSheetsDebug.showLongPressMenu(context, ref, file, isArchive, p.extension(file.path).toLowerCase() == '.apk');
                      }
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  }
}

/// Shows folder item count and size lazily
class _FolderSubtitle extends StatelessWidget {
  final String path;
  final dynamic adapter;
  const _FolderSubtitle({required this.path, required this.adapter});

  @override
  Widget build(BuildContext context) {
    if (adapter is! LocalStorageAdapter) return const Text('Folder');
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        Directory(path).list().length,
        FileOperationsService.getFolderSize(path),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Text('...', style: TextStyle(fontSize: 11));
        final count = snap.data![0] as int;
        final size = snap.data![1] as int;
        final sizeStr = size < 1048576 ? '${(size / 1024).toStringAsFixed(0)} KB' : '${(size / 1048576).toStringAsFixed(1)} MB';
        return Text('$count items • $sizeStr', style: const TextStyle(fontSize: 11));
      },
    );
  }
}

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

    final currentPath     = ref.watch(currentPathProvider);
    final currentAdapter  = ref.watch(storageAdapterProvider);
    final asyncContents   = ref.watch(directoryContentsProvider);
    final clipboard       = ref.watch(clipboardProvider);
    final selectedFiles   = ref.watch(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;
    final hasClipboard    =
        clipboard.action != ClipboardAction.none && clipboard.paths.isNotEmpty;

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
            ref.read(currentPathProvider.notifier).state = p.dirname(currentPath);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(selectedFilesProvider.notifier).state = {},
                )
              : (hasClipboard
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () =>
                          ref.read(clipboardProvider.notifier).state = ClipboardState(),
                    )
                  : null),
          title: isSelectionMode
              ? Text('${selectedFiles.length} selected',
                  style: const TextStyle(fontSize: 18))
              : hasClipboard
                  ? Text(
                      clipboard.action == ClipboardAction.extract
                          ? 'Select Extract Destination'
                          : 'Select Destination',
                      style: const TextStyle(fontSize: 18),
                    )
                  : HeaderPopupMenuDebug(
                      currentPath: currentPath,
                      currentAdapter: currentAdapter,
                    ),
          actions: [
            if (isSelectionMode)
              SelectionMenuDebug(
                onActionSelected: (val) => FileActionHandlerDebug.handleBulkActions(
                    context, ref, val, selectedFiles.toList()),
              )
            else if (!hasClipboard)
              HeaderIconsDebug(
                currentPath: currentPath,
                onActionSelected: (val) =>
                    FileActionHandlerDebug.handleNormalMenu(context, ref, val, currentPath),
              ),
          ],
        ),

        // ── Paste / Extract FAB ──────────────────────────────────────────────
        floatingActionButton: hasClipboard && !isSelectionMode
            ? FloatingActionButton.extended(
                backgroundColor: clipboard.action == ClipboardAction.extract
                    ? Colors.orange
                    : Colors.teal,
                onPressed: () =>
                    FileActionHandlerDebug.handleFabAction(context, ref, currentPath),
                icon: Icon(
                  clipboard.action == ClipboardAction.extract
                      ? Icons.unarchive
                      : clipboard.action == ClipboardAction.cut
                          ? Icons.drive_file_move
                          : Icons.content_paste,
                  color: Colors.white,
                ),
                label: Text(
                  clipboard.action == ClipboardAction.extract
                      ? 'Extract Here'
                      : clipboard.action == ClipboardAction.cut
                          ? 'Move Here (${clipboard.paths.length})'
                          : 'Paste Here (${clipboard.paths.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,

        body: asyncContents.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          data: (files) {
            if (files.isEmpty) {
              return const Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Empty directory', style: TextStyle(color: Colors.grey)),
                ]),
              );
            }

            final sortType  = ref.watch(fileSortProvider);
            final sortOrder = ref.watch(fileSortOrderProvider);
            final sorted    = List<FileEntry>.from(files);

            sorted.sort((a, b) {
              if (a.isDirectory && !b.isDirectory) return -1;
              if (!a.isDirectory && b.isDirectory) return 1;
              int r = 0;
              if (sortType == FileSortType.size) {
                r = a.size.compareTo(b.size);
              } else if (sortType == FileSortType.date) {
                r = a.modifiedAt.compareTo(b.modifiedAt);
              } else if (sortType == FileSortType.type) {
                r = p.extension(a.path).compareTo(p.extension(b.path));
              } else {
                r = p.basename(a.path)
                    .toLowerCase()
                    .compareTo(p.basename(b.path).toLowerCase());
              }
              return sortOrder == FileSortOrder.ascending ? r : -r;
            });

            final canGoBack =
                currentPath != '/storage/emulated/0' && currentPath != '/';
            final itemCount = canGoBack ? sorted.length + 1 : sorted.length;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(directoryContentsProvider),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  // Up-dir row
                  if (canGoBack && index == 0) {
                    return ListTile(
                      leading: _circleIcon(Icons.drive_folder_upload, Colors.blueGrey),
                      title: const Text('..'),
                      subtitle: const Text('Parent folder',
                          style: TextStyle(fontSize: 11)),
                      onTap: () {
                        if (isSelectionMode) return;
                        ref.read(currentPathProvider.notifier).state =
                            p.dirname(currentPath);
                      },
                    );
                  }

                  final fi     = canGoBack ? index - 1 : index;
                  final file   = sorted[fi];
                  final isDir  = file.isDirectory;
                  final isSelected = selectedFiles.contains(file.path);
                  final name   = p.basename(file.path);
                  final isHidden = name.startsWith('.');
                  final dateStr  = _fmtDate(file.modifiedAt);

                  return _FileRow(
                    file: file,
                    adapter: currentAdapter,
                    isDirectory: isDir,
                    isSelected: isSelected,
                    isSelectionMode: isSelectionMode,
                    isHidden: isHidden,
                    dateStr: dateStr,
                    name: name,
                    onTap: () async {
                      if (isSelectionMode) {
                        _toggle(ref, selectedFiles, file.path);
                        return;
                      }
                      if (hasClipboard) {
                        if (isDir) {
                          ref.read(currentPathProvider.notifier).state = file.path;
                        }
                        return;
                      }
                      if (isDir) {
                        ref.read(currentPathProvider.notifier).state = file.path;
                      } else {
                        bool isArchive = false;
                        if (currentAdapter is LocalStorageAdapter) {
                          isArchive = await ArchiveService.isArchiveFile(file.path);
                        }
                        if (context.mounted) {
                          if (isArchive) {
                            FileBottomSheetsDebug.showArchiveTapMenu(
                                context, ref, file,
                                isApk: p.extension(file.path).toLowerCase() == '.apk');
                          } else {
                            final handler =
                                ref.read(fileHandlerRegistryProvider).handlerFor(file);
                            handler?.open(context, file, currentAdapter);
                          }
                        }
                      }
                    },
                    onLongPress: () async {
                      if (hasClipboard) return;
                      bool isArchive = false;
                      if (!isDir && currentAdapter is LocalStorageAdapter) {
                        isArchive = await ArchiveService.isArchiveFile(file.path);
                      }
                      if (context.mounted) {
                        FileBottomSheetsDebug.showLongPressMenu(context, ref, file,
                            isArchive, p.extension(file.path).toLowerCase() == '.apk');
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

  static void _toggle(WidgetRef ref, Set<String> current, String path) {
    final next = Set<String>.from(current);
    next.contains(path) ? next.remove(path) : next.add(path);
    ref.read(selectedFilesProvider.notifier).state = next;
  }

  static Widget _circleIcon(IconData icon, Color color) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: 0.15),
    ),
    child: Icon(icon, color: color, size: 22),
  );

  static String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Individual file row with native-Android selection overlay ────────────────
class _FileRow extends ConsumerWidget {
  final FileEntry file;
  final dynamic adapter;
  final bool isDirectory, isSelected, isSelectionMode, isHidden;
  final String dateStr, name;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileRow({
    required this.file,
    required this.adapter,
    required this.isDirectory,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isHidden,
    required this.dateStr,
    required this.name,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: isSelected
          ? Colors.teal.withValues(alpha: 0.14)
          : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: _buildLeading(),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isHidden ? Colors.grey : Colors.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: isDirectory
            ? _FolderSubtitle(path: file.path, adapter: adapter)
            : Text(
                _fmtSize(file.size),
                style: const TextStyle(fontSize: 11),
              ),
        trailing: Text(dateStr,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _buildLeading() {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          // Thumbnail / icon
          Positioned.fill(
            child: Opacity(
              opacity: isHidden ? 0.45 : 1.0,
              child: FileThumbnailDebug(
                  file: file, adapter: adapter, isDirectory: isDirectory),
            ),
          ),

          // Native-Android style circular checkbox overlay
          if (isSelectionMode)
            Positioned(
              top: 0, left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.teal : const Color(0xAA121212),
                  border: Border.all(
                    color: isSelected ? Colors.teal : Colors.white60,
                    width: 1.8,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  }
}

/// Async folder item-count + size subtitle
class _FolderSubtitle extends StatelessWidget {
  final String path;
  final dynamic adapter;
  const _FolderSubtitle({required this.path, required this.adapter});

  @override
  Widget build(BuildContext context) {
    if (adapter is! LocalStorageAdapter) {
      return const Text('Folder', style: TextStyle(fontSize: 11));
    }
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        Directory(path).list().length,
        FileOperationsService.getFolderSize(path),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Text('…', style: TextStyle(fontSize: 11));
        }
        final count   = snap.data![0] as int;
        final size    = snap.data![1] as int;
        final sizeStr = size < 1048576
            ? '${(size / 1024).toStringAsFixed(0)} KB'
            : '${(size / 1048576).toStringAsFixed(1)} MB';
        return Text('$count items · $sizeStr',
            style: const TextStyle(fontSize: 11));
      },
    );
  }
}

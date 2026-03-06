import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_entry.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';

import 'providers.dart';
import 'file_dialog_debug.dart';
import 'file_action_handler_debug.dart';
import 'archive_browser_debug.dart';

class FileBottomSheetsDebug {

  // ─── ARCHIVE TAP MENU ────────────────────────────────────────────────────
  static void showArchiveTapMenu(BuildContext context, WidgetRef ref, FileEntry file, {required bool isApk}) {
    final filePath = file.path;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            if (isApk)
              ListTile(
                leading: const Icon(Icons.android, color: Colors.green),
                title: const Text('Install APK'),
                onTap: () { Navigator.pop(ctx); final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file); if (handler != null) handler.open(context, file, ref.read(storageAdapterProvider)); },
              ),
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.blue),
              title: const Text('Browse Contents'),
              subtitle: const Text('View & extract individual files'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArchiveBrowserScreen(archivePath: filePath)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.unarchive, color: Colors.orange),
              title: const Text('Extract Here'),
              onTap: () async {
                Navigator.pop(ctx);
                _showExtractionProgress(context, ref, filePath, p.dirname(filePath));
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
            ListTile(
              leading: const Icon(Icons.verified, color: Colors.purple),
              title: const Text('Test Integrity'),
              onTap: () async {
                Navigator.pop(ctx);
                showDialog(
                  context: context, barrierDismissible: false,
                  builder: (_) => const AlertDialog(title: Text('Testing...'), content: Center(child: CircularProgressIndicator())),
                );
                final ok = await ArchiveService.testArchiveIntegrity(filePath);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? '✓ Archive is intact' : '✗ Archive may be corrupt!'),
                  backgroundColor: ok ? Colors.teal : Colors.red,
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
              title: const Text('Archive Info'),
              onTap: () async {
                Navigator.pop(ctx);
                showDialog(
                  context: context, barrierDismissible: false,
                  builder: (_) => const AlertDialog(content: Center(child: CircularProgressIndicator())),
                );
                final info = await ArchiveService.getArchiveInfo(filePath);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(p.basename(filePath)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _row('Format', info.format),
                        _row('Files', '${info.fileCount}'),
                        _row('Folders', '${info.dirCount}'),
                        _row('Original Size', _fmtSize(info.totalUncompressedSize)),
                        _row('Compressed', _fmtSize(info.compressedSize)),
                        if (info.totalUncompressedSize > 0)
                          _row('Ratio', '${((1 - info.compressedSize / info.totalUncompressedSize) * 100).toStringAsFixed(1)}% saved'),
                      ],
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showExtractionProgress(BuildContext context, WidgetRef ref, String zipPath, String destPath) {
    double progress = 0;
    String currentFile = 'Starting...';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Start extraction
          ArchiveService.extractZip(zipPath, destPath, onProgress: (prog, file) {
            progress = prog;
            currentFile = p.basename(file);
            if (ctx.mounted) setDlg(() {});
            if (prog >= 1.0) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (ctx.mounted) Navigator.of(ctx).pop();
                ref.invalidate(directoryContentsProvider);
              });
            }
          });
          return AlertDialog(
            title: const Row(children: [Icon(Icons.unarchive, color: Colors.teal), SizedBox(width: 8), Text('Extracting')]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(currentFile, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress, color: Colors.teal, backgroundColor: Colors.teal.withValues(alpha: 0.2)),
                const SizedBox(height: 8),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── LONG PRESS MENU ─────────────────────────────────────────────────────
  static void showLongPressMenu(BuildContext context, WidgetRef ref, FileEntry file, bool isArchive, bool isApk) {
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
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),

              // Selection header
              ListTile(
                tileColor: Colors.blueGrey.withValues(alpha: 0.15),
                leading: const Icon(Icons.radio_button_checked, color: Colors.teal),
                title: Text(isSelectionMode ? '${targetPaths.length} Items Selected' : 'Select File'),
                subtitle: Text(p.basename(filePath), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  final set = Set<String>.from(selectedFiles)..add(filePath);
                  ref.read(selectedFilesProvider.notifier).state = set;
                },
              ),
              const Divider(height: 1),

              if (!isSelectionMode) ...[
                if (isApk)
                  ListTile(leading: const Icon(Icons.android, color: Colors.green), title: const Text('Install APK'),
                    onTap: () { Navigator.pop(ctx); final h = ref.read(fileHandlerRegistryProvider).handlerFor(file); if (h != null) h.open(context, file, ref.read(storageAdapterProvider)); }),
                if (isArchive) ...[
                  ListTile(leading: const Icon(Icons.folder_open, color: Colors.blue), title: const Text('Browse Contents'),
                    onTap: () { Navigator.pop(ctx); Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArchiveBrowserScreen(archivePath: filePath))); }),
                  ListTile(leading: const Icon(Icons.unarchive, color: Colors.orange), title: const Text('Extract Here'),
                    onTap: () { Navigator.pop(ctx); _showExtractionProgress(context, ref, filePath, p.dirname(filePath)); }),
                  ListTile(leading: const Icon(Icons.drive_file_move, color: Colors.teal), title: const Text('Extract To...'),
                    onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract); }),
                ],
                if (!file.isDirectory && !isApk && !isArchive)
                  ListTile(leading: const Icon(Icons.open_in_new), title: const Text('Open'),
                    onTap: () { Navigator.pop(ctx); final h = ref.read(fileHandlerRegistryProvider).handlerFor(file); if (h != null) h.open(context, file, ref.read(storageAdapterProvider)); }),

                // RENAME
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline, color: Colors.amber),
                  title: const Text('Rename'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newName = await FileDialogsDebug.showRenameDialog(context, p.basename(filePath));
                    if (newName != null && newName.isNotEmpty && newName != p.basename(filePath)) {
                      final newPath = p.join(p.dirname(filePath), newName);
                      final ok = await FileOperationsService.renameEntity(filePath, newPath);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Renamed to $newName' : 'Rename failed')));
                        if (ok) ref.invalidate(directoryContentsProvider);
                      }
                    }
                  },
                ),
              ],

              ListTile(leading: const Icon(Icons.content_copy), title: Text(isSelectionMode ? 'Copy ${targetPaths.length} items' : 'Copy'),
                onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.copy); ref.read(selectedFilesProvider.notifier).state = {}; }),
              ListTile(leading: const Icon(Icons.content_cut), title: Text(isSelectionMode ? 'Cut ${targetPaths.length} items' : 'Cut'),
                onTap: () { Navigator.pop(ctx); ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.cut); ref.read(selectedFilesProvider.notifier).state = {}; }),

              ListTile(
                leading: const Icon(Icons.folder_zip, color: Colors.teal),
                title: Text(isSelectionMode ? 'Compress ${targetPaths.length} items' : 'Compress'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final defaultName = targetPaths.length == 1 ? p.basenameWithoutExtension(targetPaths.first) : 'Archive';
                  final result = await FileDialogsDebug.showCompressDialog(context, defaultName);
                  if (result != null && result['name']!.isNotEmpty) {
                    final ext = result['format']!;
                    final dest = p.join(p.dirname(filePath), '${result['name']}.$ext');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...')));
                    await ArchiveService.compressEntities(targetPaths, dest, format: ext.replaceAll('.', ''));
                    ref.read(selectedFilesProvider.notifier).state = {};
                    ref.invalidate(directoryContentsProvider);
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final xFiles = targetPaths.map((path) => XFile(path)).toList();
                  await Share.shareXFiles(xFiles, text: 'Shared via Argus Archive');
                  ref.read(selectedFilesProvider.notifier).state = {};
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Details'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final entries = await FileActionHandlerDebug.getEntriesFromPaths(targetPaths, ref.read(storageAdapterProvider));
                  if (context.mounted) FileDialogsDebug.showDetailsDialog(context, entries);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: Text(isSelectionMode ? 'Move ${targetPaths.length} items to Trash' : 'Move to Trash', style: const TextStyle(color: Colors.orange)),
                onTap: () { Navigator.pop(ctx); FileDialogsDebug.showDeleteConfirmation(context, ref, targetPaths); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

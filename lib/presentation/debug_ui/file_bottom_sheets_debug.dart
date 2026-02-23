import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_entry.dart';
import '../../adapters/virtual/zip_archive_adapter.dart';
import '../../services/operations/archive_service.dart';

import 'providers.dart';
import 'file_dialog_debug.dart';
import 'file_action_handler_debug.dart';

class FileBottomSheetsDebug {
  static void showArchiveTapMenu(BuildContext context, WidgetRef ref, FileEntry file, {required bool isApk}) {
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
              ListTile(leading: const Icon(Icons.folder_zip, color: Colors.teal), title: Text(isSelectionMode ? 'Compress ${targetPaths.length} items to ZIP' : 'Compress to ZIP'), onTap: () async { 
                Navigator.pop(ctx); 
                final defaultName = targetPaths.length == 1 ? p.basenameWithoutExtension(targetPaths.first) : 'Archive'; 
                final zipName = await FileDialogsDebug.showZipNameDialog(context, defaultName); 
                if (zipName != null && zipName.isNotEmpty) { 
                  if (!context.mounted) return; 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compressing...'))); 
                  final zipDest = p.join(p.dirname(filePath), '$zipName.zip'); 
                  await ArchiveService.compressEntities(targetPaths, zipDest); 
                  ref.read(selectedFilesProvider.notifier).state = {}; 
                  ref.invalidate(directoryContentsProvider); 
                } 
              }),
              ListTile(leading: const Icon(Icons.share), title: const Text('Share'), onTap: () async { Navigator.pop(ctx); final xFiles = targetPaths.map((path) => XFile(path)).toList(); await Share.shareXFiles(xFiles, text: 'Shared via Argus Archive'); ref.read(selectedFilesProvider.notifier).state = {}; }),
              ListTile(leading: const Icon(Icons.info_outline), title: const Text('Details'), onTap: () async { Navigator.pop(ctx); final entries = await FileActionHandlerDebug.getEntriesFromPaths(targetPaths, ref.read(storageAdapterProvider)); if (context.mounted) FileDialogsDebug.showDetailsDialog(context, entries); }),
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(isSelectionMode ? 'Delete ${targetPaths.length} items' : 'Delete', style: const TextStyle(color: Colors.red)), onTap: () { Navigator.pop(ctx); FileDialogsDebug.showDeleteConfirmation(context, ref, targetPaths); }),
            ],
          ),
        ),
      ),
    );
  }
}

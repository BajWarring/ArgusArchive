import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../services/transfer/transfer_task.dart';
import '../../services/operations/file_operations_service.dart';
import '../../services/operations/archive_service.dart'; // Added missing import

import 'providers.dart';
import 'header_icons_debug.dart';
import 'operation_progress_dialog_debug.dart';
import 'file_dialog_debug.dart';

class FileActionHandlerDebug {
  
  static Future<List<FileEntry>> getEntriesFromPaths(List<String> paths, dynamic currentAdapter) async {
    List<FileEntry> entries = [];
    for (String path in paths) {
      bool isDir = await FileSystemEntity.isDirectory(path);
      final stat = await FileStat.stat(path);
      entries.add(FileEntry(id: path, path: path, type: isDir ? FileType.dir : FileType.unknown, size: stat.size, modifiedAt: stat.modified));
    }
    return entries;
  }

  static void handleBulkActions(BuildContext context, WidgetRef ref, String action, List<String> paths) async {
    final queue = ref.read(transferQueueProvider);
    final currentAdapter = ref.read(storageAdapterProvider);

    if (action == 'copy') {
      ref.read(clipboardProvider.notifier).state = ClipboardState(paths: paths, action: ClipboardAction.copy);
      ref.read(selectedFilesProvider.notifier).state = {};
    } else if (action == 'cut') {
      ref.read(clipboardProvider.notifier).state = ClipboardState(paths: paths, action: ClipboardAction.cut);
      ref.read(selectedFilesProvider.notifier).state = {};
    } else if (action == 'delete') {
      FileDialogsDebug.showDeleteConfirmation(context, ref, paths);
    } else if (action == 'compress') {
      final defaultName = paths.length == 1 ? p.basenameWithoutExtension(paths.first) : 'Archive';
      final zipName = await FileDialogsDebug.showZipNameDialog(context, defaultName);
      
      if (zipName != null && zipName.isNotEmpty) {
        final zipDest = p.join(p.dirname(paths.first), '$zipName.zip');
        List<String> queuedTaskIds = [];

        for (int i = 0; i < paths.length; i++) {
          final stat = await FileStat.stat(paths[i]);
          final dest = paths.length == 1 ? zipDest : p.join(p.dirname(paths.first), '${p.basenameWithoutExtension(paths[i])}.zip');
          
          final task = TransferTask(
            id: 'compress_${DateTime.now().millisecondsSinceEpoch}_$i',
            sourcePath: paths[i],
            destPath: dest,
            totalBytes: stat.size,
            operation: TransferOperation.compress,
          );
          queue.enqueue(task, currentAdapter, currentAdapter);
          queuedTaskIds.add(task.id);
        }

        if (!context.mounted) return;
        
        OperationProgressDialogDebug.show(context, queuedTaskIds);
        ref.read(selectedFilesProvider.notifier).state = {};
      }
    } else if (action == 'share') {
       final xFiles = paths.map((path) => XFile(path)).toList();
       await Share.shareXFiles(xFiles, text: 'Shared via Argus Archive');
       ref.read(selectedFilesProvider.notifier).state = {};
    } else if (action == 'details') {
      final entries = await getEntriesFromPaths(paths, ref.read(storageAdapterProvider));
      if (context.mounted) FileDialogsDebug.showDetailsDialog(context, entries);
    }
  }

  static void handleNormalMenu(BuildContext context, WidgetRef ref, String value, String currentPath) async {
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
      final name = await FileDialogsDebug.showCreateDialog(context, isFolder ? 'New Folder' : 'New File');
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

  static Future<void> handleFabAction(BuildContext context, WidgetRef ref, String destDir) async {
    final clipboard = ref.read(clipboardProvider);
    final queue = ref.read(transferQueueProvider);
    final currentAdapter = ref.read(storageAdapterProvider);
    
    List<String> queuedTaskIds = [];

    // --- HANDLE EXTRACTION ---
    if (clipboard.action == ClipboardAction.extract) {
      final zipPath = clipboard.paths.first;
      
      final tempExtractDir = p.join(destDir, '.temp_extract_${DateTime.now().millisecondsSinceEpoch}');
      await Directory(tempExtractDir).create();
      
      bool success = await ArchiveService.extractZip(zipPath, tempExtractDir);
      
      if (success && context.mounted) {
         final allExtractedFiles = Directory(tempExtractDir).listSync(recursive: true).whereType<File>().toList();
         
         bool applyToAll = false;
         String? bulkAction;

         for (var tempFile in allExtractedFiles) {
            final relativePath = p.relative(tempFile.path, from: tempExtractDir);
            String finalPath = p.join(destDir, relativePath);
            
            await Directory(p.dirname(finalPath)).create(recursive: true);

            if (File(finalPath).existsSync()) {
                 String action;
                 if (applyToAll && bulkAction != null) { 
                   action = bulkAction; 
                 } else {
                   if (!context.mounted) return;
                   final result = await FileDialogsDebug.showAdvancedCollisionDialog(context, tempFile.path);
                   if (result == null) break; 
                   action = result['action'];
                   if (result['applyToAll'] == true) { applyToAll = true; bulkAction = action; }
                 }
                 
                 if (action == 'skip') { 
                   continue; 
                 } else if (action == 'replace') { 
                   await File(finalPath).delete(); 
                 } else if (action == 'rename') { 
                   finalPath = FileOperationsService.getRenameUniquePath(p.dirname(finalPath), p.basename(finalPath));
                 }
            }
            
            await tempFile.rename(finalPath);
         }
      }
      
      if (Directory(tempExtractDir).existsSync()) await Directory(tempExtractDir).delete(recursive: true);
      
      ref.read(clipboardProvider.notifier).state = ClipboardState();
      ref.invalidate(directoryContentsProvider);
      return;
    }

    // --- HANDLE COPY/MOVE ---
    bool applyToAll = false;
    String? bulkAction;
    
    for (int i = 0; i < clipboard.paths.length; i++) {
      String sourcePath = clipboard.paths[i];
      String originalName = p.basename(sourcePath);
      String targetPath = p.join(destDir, originalName);

      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        if (clipboard.action == ClipboardAction.copy) {
          targetPath = FileOperationsService.getCopyUniquePath(destDir, originalName);
        } else {
          String action;
          if (applyToAll && bulkAction != null) { 
            action = bulkAction; 
          } else {
            if (!context.mounted) return;
            final result = await FileDialogsDebug.showAdvancedCollisionDialog(context, sourcePath);
            if (result == null) break; 
            action = result['action'];
            if (result['applyToAll'] == true) { applyToAll = true; bulkAction = action; }
          }
          
          if (action == 'skip') { 
            continue; 
          } else if (action == 'replace') { 
            await FileOperationsService.deleteEntity(targetPath); 
          } else if (action == 'rename') { 
            targetPath = FileOperationsService.getRenameUniquePath(destDir, originalName);
          }
        }
      }

      final stat = await FileStat.stat(sourcePath);
      final task = TransferTask(
        id: 'transfer_${DateTime.now().millisecondsSinceEpoch}_$i',
        sourcePath: sourcePath,
        destPath: targetPath,
        totalBytes: stat.size,
        operation: clipboard.action == ClipboardAction.copy ? TransferOperation.copy : TransferOperation.move,
      );

      queue.enqueue(task, currentAdapter, currentAdapter);
      queuedTaskIds.add(task.id);
    }
    
    if (queuedTaskIds.isNotEmpty) {
       if (!context.mounted) return;
       OperationProgressDialogDebug.show(context, queuedTaskIds);
    }
    
    if (clipboard.action == ClipboardAction.cut || clipboard.action == ClipboardAction.copy) {
      ref.read(clipboardProvider.notifier).state = ClipboardState();
    }
  }
} // Fixed: Added missing class closing brace!

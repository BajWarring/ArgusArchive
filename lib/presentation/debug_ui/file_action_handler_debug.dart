import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';

import 'providers.dart';
import 'header_icons_debug.dart';
import 'operation_progress_dialog_debug.dart';
import 'file_dialogs_debug.dart';

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
        if (!context.mounted) return;
        
        final progressNotifier = ValueNotifier<double>(0.0);
        final fileNotifier = ValueNotifier<String>('Initializing...');
        OperationProgressDialogDebug.show(context, OperationType.compress, progressNotifier, fileNotifier);

        final zipDest = p.join(p.dirname(paths.first), '$zipName.zip');
        await ArchiveService.compressEntities(paths, zipDest);
        
        if (context.mounted) Navigator.of(context).pop();
        ref.read(selectedFilesProvider.notifier).state = {};
        ref.invalidate(directoryContentsProvider);
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
    
    final progressNotifier = ValueNotifier<double>(0.0);
    final fileNotifier = ValueNotifier<String>('Initializing...');
    
    if (clipboard.action == ClipboardAction.extract) {
      OperationProgressDialogDebug.show(context, OperationType.extract, progressNotifier, fileNotifier);
      
      final zipPath = clipboard.paths.first;
      final tempExtractDir = p.join(destDir, '.temp_extract_${DateTime.now().millisecondsSinceEpoch}');
      await Directory(tempExtractDir).create();
      
      bool success = await ArchiveService.extractZip(zipPath, tempExtractDir);
      
      if (success && context.mounted) {
         final tempEntities = Directory(tempExtractDir).listSync();
         List<String> tempPaths = tempEntities.map((e) => e.path).toList();
         
         bool applyToAll = false;
         String? bulkAction;
         for (int i = 0; i < tempPaths.length; i++) {
            String sourcePath = tempPaths[i];
            
            progressNotifier.value = i / tempPaths.length;
            fileNotifier.value = p.basename(sourcePath);

            bool moveSuccess = await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
            if (!moveSuccess && context.mounted) {
                 String action;
                 if (applyToAll && bulkAction != null) { action = bulkAction; } 
                 else {
                   final result = await FileDialogsDebug.showAdvancedCollisionDialog(context, sourcePath);
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
      if (context.mounted) Navigator.of(context).pop();

      ref.read(clipboardProvider.notifier).state = ClipboardState();
      ref.invalidate(directoryContentsProvider);
      return;
    }

    OperationType opType = clipboard.action == ClipboardAction.copy ? OperationType.copy : OperationType.move;
    OperationProgressDialogDebug.show(context, opType, progressNotifier, fileNotifier);

    bool applyToAll = false;
    String? bulkAction;
    for (int i = 0; i < clipboard.paths.length; i++) {
      String sourcePath = clipboard.paths[i];
      
      progressNotifier.value = i / clipboard.paths.length;
      fileNotifier.value = p.basename(sourcePath);

      if (clipboard.action == ClipboardAction.copy) {
        await FileOperationsService.copyEntity(sourcePath, destDir, autoRename: true);
      } else if (clipboard.action == ClipboardAction.cut) {
        bool success = await FileOperationsService.moveEntity(sourcePath, destDir, autoRename: false);
        if (!success && context.mounted) {
          String action;
          if (applyToAll && bulkAction != null) { action = bulkAction; } 
          else {
            final result = await FileDialogsDebug.showAdvancedCollisionDialog(context, sourcePath);
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
    
    if (context.mounted) Navigator.of(context).pop();
    
    if (clipboard.action == ClipboardAction.cut || clipboard.action == ClipboardAction.copy) ref.read(clipboardProvider.notifier).state = ClipboardState();
    ref.invalidate(directoryContentsProvider);
  }
}

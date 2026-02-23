  static Future<void> handleFabAction(BuildContext context, WidgetRef ref, String destDir) async {
    final clipboard = ref.read(clipboardProvider);
    final queue = ref.read(transferQueueProvider);
    final currentAdapter = ref.read(storageAdapterProvider);
    
    List<String> queuedTaskIds = [];

    // --- HANDLE EXTRACTION ---
    if (clipboard.action == ClipboardAction.extract) {
      final zipPath = clipboard.paths.first;
      
      // We extract to a hidden temp folder first
      final tempExtractDir = p.join(destDir, '.temp_extract_${DateTime.now().millisecondsSinceEpoch}');
      await Directory(tempExtractDir).create();
      
      bool success = await ArchiveService.extractZip(zipPath, tempExtractDir);
      
      if (success && context.mounted) {
         // Recursive list gets ALL files, avoiding folder-level overwrite blocks
         final allExtractedFiles = Directory(tempExtractDir).listSync(recursive: true).whereType<File>().toList();
         
         bool applyToAll = false;
         String? bulkAction;

         for (var tempFile in allExtractedFiles) {
            // Calculate where this specific file belongs in the final destination
            final relativePath = p.relative(tempFile.path, from: tempExtractDir);
            String finalPath = p.join(destDir, relativePath);
            
            // Ensure parent directories exist
            await Directory(p.dirname(finalPath)).create(recursive: true);

            // File-level collision check
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
            
            // Move the individual file
            await tempFile.rename(finalPath);
         }
      }
      
      // Cleanup temp folder
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

      // 1. Collision Check
      if (File(targetPath).existsSync() || Directory(targetPath).existsSync()) {
        
        // FIX: If it's a Copy operation, force auto-rename without showing a dialog
        if (clipboard.action == ClipboardAction.copy) {
          targetPath = FileOperationsService.getCopyUniquePath(destDir, originalName);
        } else {
          // If it's a Cut/Move operation, show the collision dialog
          String action;
          if (applyToAll && bulkAction != null) { 
            action = bulkAction; 
          } else {
            if (!context.mounted) return;
            final result = await FileDialogsDebug.showAdvancedCollisionDialog(context, sourcePath);
            if (result == null) break; // User hit cancel
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

      // 2. Build the Task
      final stat = await FileStat.stat(sourcePath);
      final task = TransferTask(
        id: 'transfer_${DateTime.now().millisecondsSinceEpoch}_$i',
        sourcePath: sourcePath,
        destPath: targetPath,
        totalBytes: stat.size,
        operation: clipboard.action == ClipboardAction.copy ? TransferOperation.copy : TransferOperation.move,
      );

      // 3. Enqueue
      queue.enqueue(task, currentAdapter, currentAdapter);
      queuedTaskIds.add(task.id);
    }
    
    // Show the active progress dialog bound to these specific tasks
    if (queuedTaskIds.isNotEmpty) {
       if (!context.mounted) return;
       OperationProgressDialogDebug.show(context, queuedTaskIds);
    }
    
    if (clipboard.action == ClipboardAction.cut || clipboard.action == ClipboardAction.copy) {
      ref.read(clipboardProvider.notifier).state = ClipboardState();
    }
  }

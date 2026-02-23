import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/file_entry.dart';
import '../../services/operations/file_operations_service.dart';
import 'providers.dart';

class FileDialogsDebug {
  static Future<String?> showCreateDialog(BuildContext context, String title) async {
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

  static void showDetailsDialog(BuildContext context, List<FileEntry> files) {
    if (files.isEmpty) return;
    final isMulti = files.length > 1;
    final totalSize = files.fold(0, (sum, file) => sum + file.size);
    
    Widget detailRow(String label, String value) {
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
                detailRow('Name:', p.basename(files.first.path)),
                detailRow('Type:', files.first.isDirectory ? 'Folder' : p.extension(files.first.path).toUpperCase()),
                detailRow('Size:', '${(totalSize / 1024).toStringAsFixed(2)} KB'),
                detailRow('Modified:', files.first.modifiedAt.toString().split('.')[0]),
                const SizedBox(height: 8),
                const Text('Location (Hold to copy):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                SelectableText(files.first.path, style: const TextStyle(fontSize: 14)), 
              ] else ...[
                detailRow('Items Selected:', '${files.length}'),
                detailRow('Total Size:', '${(totalSize / 1024).toStringAsFixed(2)} KB'),
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

  static Future<String?> showZipNameDialog(BuildContext context, String defaultName) async {
    TextEditingController controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text('Compress Files'), 
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Archive Name', suffixText: '.zip'), autofocus: true), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), 
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Compress'))
        ]
      )
    );
  }

  static void showDeleteConfirmation(BuildContext context, WidgetRef ref, List<String> filePaths) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(filePaths.length > 1 ? 'Are you sure you want to permanently delete ${filePaths.length} items?' : 'Are you sure you want to permanently delete "${p.basename(filePaths.first)}"?'),
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
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  static Future<Map<String, dynamic>?> showAdvancedCollisionDialog(BuildContext context, String sourcePath) {
    bool applyToAll = false;
    return showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('File Already Exists'),
            content: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [ 
                Text('"${p.basename(sourcePath)}" already exists.'), 
                const SizedBox(height: 16), 
                Row(children: [Checkbox(value: applyToAll, onChanged: (val) => setState(() => applyToAll = val ?? false)), const Expanded(child: Text('Apply to all files'))]) 
              ],
            ),
            actions: [ 
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')), 
              TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'skip', 'applyToAll': applyToAll}), child: const Text('Skip')), 
              TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'rename', 'applyToAll': applyToAll}), child: const Text('Rename')), 
              TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'replace', 'applyToAll': applyToAll}), child: const Text('Replace', style: TextStyle(color: Colors.red))) 
            ],
          );
        }
      ),
    );
  }
}

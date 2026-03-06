import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/file_entry.dart';
import '../../services/operations/file_operations_service.dart';
import '../../services/storage/bookmarks_service.dart';
import 'providers.dart';

class FileDialogsDebug {

  // ─── CREATE FOLDER/FILE ──────────────────────────────────────────────────
  static Future<String?> showCreateDialog(BuildContext context, String title) async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Enter name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
  }

  // ─── RENAME ──────────────────────────────────────────────────────────────
  static Future<String?> showRenameDialog(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    // Select only the name without extension for convenience
    final dotIndex = currentName.lastIndexOf('.');
    final selection = dotIndex > 0
        ? TextSelection(baseOffset: 0, extentOffset: dotIndex)
        : TextSelection(baseOffset: 0, extentOffset: currentName.length);
    controller.selection = selection;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
  }

  // ─── DETAILS ─────────────────────────────────────────────────────────────
  static void showDetailsDialog(BuildContext context, List<FileEntry> files) {
    if (files.isEmpty) return;
    final isMulti = files.length > 1;
    final totalSize = files.fold(0, (sum, f) => sum + f.size);

    Widget detailRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ]),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMulti ? 'Multiple Items' : 'File Details'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!isMulti) ...[
              detailRow('Name:', p.basename(files.first.path)),
              detailRow('Type:', files.first.isDirectory ? 'Folder' : p.extension(files.first.path).toUpperCase()),
              detailRow('Size:', _formatSize(totalSize)),
              detailRow('Modified:', files.first.modifiedAt.toString().split('.')[0]),
              const SizedBox(height: 8),
              const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              SelectableText(files.first.path, style: const TextStyle(fontSize: 13)),
            ] else ...[
              detailRow('Items:', '${files.length}'),
              detailRow('Total Size:', _formatSize(totalSize)),
              const Divider(),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (c, i) => Text('• ${p.basename(files[i].path)}', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  // ─── COMPRESS DIALOG (with format picker) ────────────────────────────────
  static Future<Map<String, String>?> showCompressDialog(BuildContext context, String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    String selectedFormat = 'zip';

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Compress Files'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Archive Name',
                  suffixText: '.$selectedFormat',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Format:', style: TextStyle(color: Colors.grey, fontSize: 12))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['zip', 'tar.gz', 'tar.bz2', 'tar'].map((fmt) => ChoiceChip(
                  label: Text(fmt),
                  selected: selectedFormat == fmt,
                  onSelected: (_) => setDlg(() => selectedFormat = fmt),
                  selectedColor: Colors.teal,
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {'name': controller.text.trim(), 'format': selectedFormat}),
              child: const Text('Compress'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DELETE CONFIRMATION ────────────────────────────────────────────────
  static void showDeleteConfirmation(BuildContext context, WidgetRef ref, List<String> filePaths) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text(filePaths.length > 1
            ? 'Move ${filePaths.length} items to trash?'
            : 'Move "${p.basename(filePaths.first)}" to trash?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final path in filePaths) {
                await FileOperationsService.moveToTrash(path);
              }
              ref.read(selectedFilesProvider.notifier).state = {};
              ref.invalidate(directoryContentsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${filePaths.length} item(s) moved to trash'),
                    action: SnackBarAction(label: 'UNDO', onPressed: () async {
                      // Restore last batch from trash
                      final items = await TrashService.getItems();
                      for (final path in filePaths) {
                        final item = items.firstWhere((i) => i.originalPath == path, orElse: () => items.last);
                        await TrashService.restore(item);
                      }
                      ref.invalidate(directoryContentsProvider);
                      ref.invalidate(trashItemsProvider);
                    }),
                  ),
                );
              }
            },
            child: const Text('Trash', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final path in filePaths) {
                await FileOperationsService.deleteEntity(path);
              }
              ref.read(selectedFilesProvider.notifier).state = {};
              ref.invalidate(directoryContentsProvider);
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── COLLISION DIALOG ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> showAdvancedCollisionDialog(BuildContext context, String sourcePath) {
    bool applyToAll = false;
    return showDialog<Map<String, dynamic>>(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('File Already Exists'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('"${p.basename(sourcePath)}" already exists.'),
              const SizedBox(height: 16),
              Row(children: [
                Checkbox(value: applyToAll, onChanged: (v) => setState(() => applyToAll = v ?? false)),
                const Expanded(child: Text('Apply to all files')),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'skip', 'applyToAll': applyToAll}), child: const Text('Skip')),
            TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'rename', 'applyToAll': applyToAll}), child: const Text('Rename')),
            TextButton(onPressed: () => Navigator.pop(ctx, {'action': 'replace', 'applyToAll': applyToAll}), child: const Text('Replace', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  // ─── BOOKMARK MANAGER DIALOG ─────────────────────────────────────────────
  static void showBookmarksDialog(BuildContext context, WidgetRef ref, String currentPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final bookmarksAsync = ref.watch(bookmarksProvider);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            builder: (_, ctrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bookmarks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Current'),
                        onPressed: () async {
                          await BookmarksService.add(currentPath);
                          ref.invalidate(bookmarksProvider);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: bookmarksAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (bookmarks) => bookmarks.isEmpty
                        ? const Center(child: Text('No bookmarks yet. Navigate to a folder and tap Add.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            controller: ctrl,
                            itemCount: bookmarks.length,
                            itemBuilder: (_, i) {
                              final bm = bookmarks[i];
                              return ListTile(
                                leading: const Icon(Icons.bookmark, color: Colors.amber),
                                title: Text(bm.label),
                                subtitle: Text(bm.path, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await BookmarksService.remove(bm.path);
                                    ref.invalidate(bookmarksProvider);
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  ref.read(currentPathProvider.notifier).state = bm.path;
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── TRASH VIEWER DIALOG ─────────────────────────────────────────────────
  static void showTrashDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final trashAsync = ref.watch(trashItemsProvider);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            builder: (_, ctrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('Empty Trash', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          await TrashService.emptyTrash();
                          ref.invalidate(trashItemsProvider);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: trashAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (items) => items.isEmpty
                        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete_outlined, size: 64, color: Colors.grey), SizedBox(height: 8), Text('Trash is empty', style: TextStyle(color: Colors.grey))]))
                        : ListView.builder(
                            controller: ctrl,
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final item = items[i];
                              return ListTile(
                                leading: Icon(item.isDirectory ? Icons.folder : Icons.insert_drive_file, color: item.isDirectory ? Colors.amber : Colors.grey),
                                title: Text(p.basename(item.originalPath), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${_formatSize(item.size)} • Deleted ${_timeAgo(item.deletedAt)}', style: const TextStyle(fontSize: 11)),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(icon: const Icon(Icons.restore, color: Colors.teal), onPressed: () async {
                                    await TrashService.restore(item);
                                    ref.invalidate(trashItemsProvider);
                                    ref.invalidate(directoryContentsProvider);
                                  }),
                                  IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () async {
                                    await TrashService.deletePermanently(item);
                                    ref.invalidate(trashItemsProvider);
                                  }),
                                ]),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

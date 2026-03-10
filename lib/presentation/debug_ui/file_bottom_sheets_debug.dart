import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../core/models/file_entry.dart';
import '../../services/operations/archive_service.dart';
import '../../services/operations/file_operations_service.dart';
import '../operations_ui/standalone_operation_popup.dart';

import 'providers.dart';
import 'file_dialog_debug.dart';
import 'archive_browser_debug.dart';
import 'file_action_handler_debug.dart';

class FileBottomSheetsDebug {

  static const _sheetBg    = Color(0xFF1E1E2E);
  static const _divColor   = Color(0xFF2A2A3A);
  static const _radius     = BorderRadius.vertical(top: Radius.circular(28));

  static Widget _handle() => Center(
    child: Container(
      width: 36, height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
    ),
  );

  static Widget _fileHeader(FileEntry file, {int selectedCount = 1}) {
    final isMulti  = selectedCount > 1;
    final name     = isMulti ? '$selectedCount items selected' : p.basename(file.path);
    final subtitle = isMulti ? null : '${_fmtSize(file.size)} · ${_fmtDate(file.modifiedAt)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFF252540), borderRadius: BorderRadius.circular(12)),
            child: Icon(isMulti ? Icons.folder_copy : _iconFor(file), color: isMulti ? Colors.teal : _colorFor(file), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _action({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    Color iconColor = Colors.white,
    Color? labelColor,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return ListTile(
      dense: true, enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
      title: Text(label, style: TextStyle(fontSize: 14, color: labelColor ?? Colors.white, fontWeight: FontWeight.w500)),
      onTap: () { Navigator.pop(ctx); onTap(); },
    );
  }

  static Widget _divider() => const Divider(height: 1, thickness: 1, color: _divColor, indent: 20, endIndent: 20);

  // ─── ARCHIVE TAP MENU ─────────────────────────────────────────────────────
  static void showArchiveTapMenu(BuildContext context, WidgetRef ref, FileEntry file, {required bool isApk}) {
    final filePath = file.path;

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: _sheetBg, borderRadius: _radius),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(), _fileHeader(file), const Divider(height: 1, color: _divColor), const SizedBox(height: 4),
              if (isApk)
                _action(
                  ctx: ctx, icon: Icons.android, iconColor: Colors.green, label: 'Install APK',
                  onTap: () { final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file); handler?.open(context, file, ref.read(storageAdapterProvider)); },
                ),
              _action(
                ctx: ctx, icon: Icons.folder_open, iconColor: Colors.blue, label: 'Browse Contents',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArchiveBrowserScreen(archivePath: filePath))),
              ),
              _action(
                ctx: ctx, icon: Icons.unarchive, iconColor: Colors.orange, label: 'Extract Here',
                onTap: () => _extractWithProgress(context, ref, filePath, p.dirname(filePath)),
              ),
              _action(
                ctx: ctx, icon: Icons.drive_file_move, iconColor: Colors.teal, label: 'Extract To…',
                onTap: () => ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract),
              ),
              _divider(),
              _action(
                ctx: ctx, icon: Icons.verified_outlined, iconColor: Colors.purple, label: 'Test Integrity',
                onTap: () async {
                  showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(title: Text('Testing…'), content: Center(child: CircularProgressIndicator())));
                  final ok = await ArchiveService.testArchiveIntegrity(filePath);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✓ Archive is intact' : '✗ Archive may be corrupt!'), backgroundColor: ok ? Colors.teal : Colors.red));
                },
              ),
              _action(
                ctx: ctx, icon: Icons.info_outline, iconColor: Colors.blueGrey, label: 'Archive Info',
                onTap: () async {
                  showDialog(context: context, barrierDismissible: false, builder: (_) => const AlertDialog(content: Center(child: CircularProgressIndicator())));
                  final info = await ArchiveService.getArchiveInfo(filePath);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  _showArchiveInfoDialog(context, filePath, info);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── LONG-PRESS / SELECTION MENU ─────────────────────────────────────────
  static void showLongPressMenu(BuildContext context, WidgetRef ref, FileEntry file, bool isArchive, bool isApk) {
    final filePath      = file.path;
    final selectedFiles = ref.read(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;
    final targetPaths   = isSelectionMode && selectedFiles.contains(filePath) ? selectedFiles.toList() : [filePath];

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: _sheetBg, borderRadius: _radius),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _handle(), _fileHeader(file, selectedCount: targetPaths.length), const Divider(height: 1, color: _divColor), const SizedBox(height: 4),

                _action(
                  ctx: ctx, icon: isSelectionMode ? Icons.deselect : Icons.radio_button_checked, iconColor: Colors.teal,
                  label: isSelectionMode ? '${targetPaths.length} items selected  (tap to deselect all)' : 'Select',
                  onTap: () {
                    if (isSelectionMode) { ref.read(selectedFilesProvider.notifier).state = {}; } 
                    else { final set = Set<String>.from(selectedFiles)..add(filePath); ref.read(selectedFilesProvider.notifier).state = set; }
                  },
                ),
                _divider(),

                if (!isSelectionMode) ...[
                  if (isApk)
                    _action(ctx: ctx, icon: Icons.android, iconColor: Colors.green, label: 'Install APK', onTap: () { final h = ref.read(fileHandlerRegistryProvider).handlerFor(file); h?.open(context, file, ref.read(storageAdapterProvider)); }),
                  if (isArchive) ...[
                    _action(ctx: ctx, icon: Icons.folder_open, iconColor: Colors.blue, label: 'Browse Contents', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArchiveBrowserScreen(archivePath: filePath)))),
                    _action(ctx: ctx, icon: Icons.unarchive, iconColor: Colors.orange, label: 'Extract Here', onTap: () => _extractWithProgress(context, ref, filePath, p.dirname(filePath))),
                    _action(ctx: ctx, icon: Icons.drive_file_move, iconColor: Colors.teal, label: 'Extract To…', onTap: () => ref.read(clipboardProvider.notifier).state = ClipboardState(paths: [filePath], action: ClipboardAction.extract)),
                  ],
                  if (!file.isDirectory && !isApk && !isArchive)
                    _action(ctx: ctx, icon: Icons.open_in_new, iconColor: Colors.lightBlue, label: 'Open', onTap: () { final h = ref.read(fileHandlerRegistryProvider).handlerFor(file); h?.open(context, file, ref.read(storageAdapterProvider)); }),
                  _action(ctx: ctx, icon: Icons.drive_file_rename_outline, iconColor: Colors.amber, label: 'Rename', onTap: () async {
                      final newName = await FileDialogsDebug.showRenameDialog(context, p.basename(filePath));
                      if (newName != null && newName.isNotEmpty && newName != p.basename(filePath)) {
                        final newPath = p.join(p.dirname(filePath), newName);
                        final ok = await FileOperationsService.renameEntity(filePath, newPath);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Renamed to $newName' : 'Rename failed')));
                          if (ok) ref.invalidate(directoryContentsProvider);
                        }
                      }
                    }),
                  _divider(),
                ],

                _action(ctx: ctx, icon: Icons.content_copy, iconColor: Colors.blueGrey, label: targetPaths.length > 1 ? 'Copy ${targetPaths.length} items' : 'Copy', onTap: () { ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.copy); ref.read(selectedFilesProvider.notifier).state = {}; }),
                _action(ctx: ctx, icon: Icons.content_cut, iconColor: Colors.blueGrey, label: targetPaths.length > 1 ? 'Cut ${targetPaths.length} items' : 'Cut', onTap: () { ref.read(clipboardProvider.notifier).state = ClipboardState(paths: targetPaths, action: ClipboardAction.cut); ref.read(selectedFilesProvider.notifier).state = {}; }),
                _action(ctx: ctx, icon: Icons.folder_zip_outlined, iconColor: Colors.teal, label: targetPaths.length > 1 ? 'Compress ${targetPaths.length} items' : 'Compress', onTap: () async {
                    final defaultName = targetPaths.length == 1 ? p.basenameWithoutExtension(targetPaths.first) : 'Archive';
                    final result = await FileDialogsDebug.showCompressDialog(context, defaultName);
                    if (result != null && result['name']!.isNotEmpty) {
                      final ext  = result['format']!;
                      final dest = p.join(p.dirname(filePath), '${result['name']}.$ext');
                      if (!context.mounted) return;
                      // FIXED: Added cancelToken parameter
                      StandaloneOperationPopup.show(
                        context: context, title: 'Compressing', destination: dest,
                        action: (onProgress, cancelToken) => ArchiveService.compressEntities(targetPaths, dest, format: ext.replaceAll('.', ''), onProgress: onProgress, cancelToken: cancelToken),
                        onComplete: () { ref.read(selectedFilesProvider.notifier).state = {}; ref.invalidate(directoryContentsProvider); },
                      );
                    }
                  }),
                _action(ctx: ctx, icon: Icons.share_outlined, iconColor: Colors.indigo, label: 'Share', onTap: () async { await Share.shareXFiles(targetPaths.map((path) => XFile(path)).toList(), text: 'Shared via Argus Archive'); ref.read(selectedFilesProvider.notifier).state = {}; }),
                _action(ctx: ctx, icon: Icons.info_outline, iconColor: Colors.blueGrey, label: 'Details', onTap: () async { final entries = await FileActionHandlerDebug.getEntriesFromPaths(targetPaths, ref.read(storageAdapterProvider)); if (context.mounted) { FileDialogsDebug.showDetailsDialog(context, entries); } }),
                _divider(),
                _action(ctx: ctx, icon: Icons.delete_outline, iconColor: Colors.orange, labelColor: Colors.orange, label: targetPaths.length > 1 ? 'Move ${targetPaths.length} items to Trash' : 'Move to Trash', onTap: () => FileDialogsDebug.showDeleteConfirmation(context, ref, targetPaths)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── extraction progress ──────────────────────────────────────────────────
  static void _extractWithProgress(BuildContext context, WidgetRef ref, String zipPath, String destPath) {
    StandaloneOperationPopup.show(
      context: context,
      title: 'Extracting',
      destination: destPath,
      // FIXED: Added cancelToken parameter
      action: (onProgress, cancelToken) => ArchiveService.extractZip(zipPath, destPath, onProgress: onProgress, cancelToken: cancelToken),
      onComplete: () => ref.invalidate(directoryContentsProvider),
    );
  }

  static void _showArchiveInfoDialog(BuildContext context, String filePath, ArchiveInfo info) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.basename(filePath)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _row('Format',    info.format),
          _row('Files',     '${info.fileCount}'),
          _row('Folders',   '${info.dirCount}'),
          _row('Original Size', _fmtSize(info.totalUncompressedSize)),
          _row('Compressed',   _fmtSize(info.compressedSize)),
          if (info.totalUncompressedSize > 0)
            _row('Ratio', '${((1 - info.compressedSize / info.totalUncompressedSize) * 100).toStringAsFixed(1)}% saved'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  static Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value,  style: const TextStyle(fontWeight: FontWeight.bold))]));
  
  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  static String _fmtDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  static IconData _iconFor(FileEntry e) {
    if (e.isDirectory) return Icons.folder;
    final ext = p.extension(e.path).toLowerCase();
    if (['.jpg','.jpeg','.png','.gif','.webp'].contains(ext)) return Icons.image;
    if (['.mp4','.mkv','.avi','.mov'].contains(ext)) return Icons.movie;
    if (['.mp3','.wav','.flac'].contains(ext)) return Icons.audiotrack;
    if (ext == '.pdf') return Icons.picture_as_pdf;
    if (ext == '.apk') return Icons.android;
    if (['.zip','.rar','.7z','.tar'].contains(ext)) return Icons.archive;
    return Icons.insert_drive_file;
  }

  static Color _colorFor(FileEntry e) {
    if (e.isDirectory) return Colors.amber;
    final ext = p.extension(e.path).toLowerCase();
    if (['.jpg','.jpeg','.png','.gif'].contains(ext)) return Colors.blue;
    if (['.mp4','.mkv'].contains(ext)) return Colors.indigo;
    if (ext == '.pdf') return Colors.red;
    if (ext == '.apk') return Colors.green;
    if (['.zip','.rar','.7z'].contains(ext)) return Colors.orange;
    return Colors.tealAccent;
  }
}

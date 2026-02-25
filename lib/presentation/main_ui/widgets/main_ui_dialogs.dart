import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../ui_theme.dart';
import '../../../core/models/file_entry.dart';
import '../../../core/enums/file_type.dart';
import '../../debug_ui/providers.dart';
import '../../debug_ui/file_action_handler_debug.dart';
import '../../debug_ui/file_bottom_sheets_debug.dart'; // For ZIP/APK extraction menu

class MainUIDialogs {
  
  static void showActionBottomSheet(BuildContext context, WidgetRef ref, FileEntry file, {required IconData icon, required Color iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFolder = file.isDirectory;
    final ext = p.extension(file.path).toLowerCase();
    final isArchive = ext == '.zip' || ext == '.apk' || ext == '.rar';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? ArgusColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: isDark ? ArgusColors.bgDark : Colors.grey.shade200)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: isDark ? Colors.grey.shade600 : Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 24),
                
                // HEADER
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.basename(file.path), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(isFolder ? 'Folder' : '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB • ${file.modifiedAt.day}/${file.modifiedAt.month}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    // THE SELECTION BUTTON
                    IconButton(
                      icon: const Icon(Icons.radio_button_unchecked, color: ArgusColors.slate500),
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(selectedFilesProvider.notifier).state = {file.path};
                      },
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // ACTION GRID
                if (ext == '.apk') ...[
                  _buildActionRow(context, 'Install APK', Icons.android, Colors.green, () {
                     final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                     if (handler != null) handler.open(context, file, ref.read(storageAdapterProvider));
                  }),
                  const Divider(height: 16, thickness: 1, color: Colors.black12),
                ] else if (isArchive) ...[
                  _buildActionRow(context, 'Extract Options', Icons.unarchive, Colors.orange, () {
                     FileBottomSheetsDebug.showArchiveTapMenu(context, ref, file, isApk: false);
                  }),
                  const Divider(height: 16, thickness: 1, color: Colors.black12),
                ] else if (!isFolder) ...[
                  _buildActionRow(context, 'Open File', Icons.open_in_new, isDark ? Colors.white70 : Colors.black87, () {
                     final handler = ref.read(fileHandlerRegistryProvider).handlerFor(file);
                     if (handler != null) handler.open(context, file, ref.read(storageAdapterProvider));
                  }),
                  const Divider(height: 16, thickness: 1, color: Colors.black12),
                ],

                _buildActionRow(context, 'Copy', Icons.content_copy, isDark ? Colors.white70 : Colors.black87, () {
                  FileActionHandlerDebug.handleBulkActions(context, ref, 'copy', [file.path]);
                }),
                _buildActionRow(context, 'Cut', Icons.content_cut, isDark ? Colors.white70 : Colors.black87, () {
                  FileActionHandlerDebug.handleBulkActions(context, ref, 'cut', [file.path]);
                }),
                if (!isFolder && !isArchive) 
                  _buildActionRow(context, 'Compress to ZIP', Icons.folder_zip, Colors.teal, () {
                    FileActionHandlerDebug.handleBulkActions(context, ref, 'compress', [file.path]);
                  }),
                _buildActionRow(context, 'Delete', Icons.delete, Colors.red, () {
                  FileActionHandlerDebug.handleBulkActions(context, ref, 'delete', [file.path]);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildActionRow(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () { 
        Navigator.pop(context); 
        onTap(); 
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

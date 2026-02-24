import 'package:flutter/material.dart';
import '../../ui_theme.dart';

class MainUIDialogs {
  
  /// Matches the `#bottom-sheet` HTML definition
  static void showActionBottomSheet(BuildContext context, {required String itemName, required String subtitle, required IconData icon, required Color iconColor, required bool isFolder}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
                
                // Header
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
                          Text(itemName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                      onPressed: () { /* Start Selection Stub */ Navigator.pop(context); },
                    )
                  ],
                ),
                const SizedBox(height: 16),
                
                // Action Grid
                if (!isFolder) ...[
                  _buildActionRow(context, 'Open File', Icons.open_in_new, isDark ? Colors.white70 : Colors.black87),
                  const Divider(height: 16, thickness: 1, color: Colors.white10),
                ],
                _buildActionRow(context, 'Copy', Icons.content_copy, isDark ? Colors.white70 : Colors.black87),
                _buildActionRow(context, 'Cut', Icons.content_cut, isDark ? Colors.white70 : Colors.black87),
                if (!isFolder) _buildActionRow(context, 'Compress', Icons.folder_zip, Colors.teal),
                _buildActionRow(context, 'Delete', Icons.delete, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildActionRow(BuildContext context, String label, IconData icon, Color color) {
    return InkWell(
      onTap: () { Navigator.pop(context); /* Action Stub */ },
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

  /// Matches the `#pin-modal-backdrop` Mini Explorer HTML
  static void showPinFolderModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? ArgusColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select folder to pin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Colors.white10),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      _buildMiniExplorerHeader('Internal Storage', isDark),
                      _buildMiniExplorerItem('Documents', context),
                      _buildMiniExplorerItem('Downloads', context),
                      _buildMiniExplorerHeader('SD Card', isDark),
                      _buildMiniExplorerItem('Media', context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  static Widget _buildMiniExplorerHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
    );
  }

  static Widget _buildMiniExplorerItem(String folderName, BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder, color: ArgusColors.primary),
      title: Text(folderName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.add, color: Colors.grey, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () { Navigator.pop(context); /* Pin action stub */ },
    );
  }

  /// Matches the `#task-progress-backdrop` HTML
  static void showTaskProgressDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? ArgusColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.drive_file_move, color: ArgusColors.primary, size: 28),
                    const SizedBox(width: 8),
                    const Text('Moving...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('item.txt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('0 / 1 files', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey)),
                    const Text('45%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.45,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(ArgusColors.primary),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 12,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      style: TextButton.styleFrom(foregroundColor: Colors.grey, textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                      child: const Text('Hide in Background')
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context), 
                      style: TextButton.styleFrom(foregroundColor: Colors.red, textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                      child: const Text('Cancel')
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      }
    );
  }
}

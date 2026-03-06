import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_debug.dart';
import 'providers.dart';
import 'file_dialog_debug.dart';

enum FileSortType { name, size, date, type }
enum FileSortOrder { ascending, descending }

final fileSortProvider = StateProvider<FileSortType>((ref) => FileSortType.name);
final fileSortOrderProvider = StateProvider<FileSortOrder>((ref) => FileSortOrder.ascending);

class HeaderIconsDebug extends ConsumerWidget {
  final Function(String) onActionSelected;
  final String currentPath;

  const HeaderIconsDebug({
    super.key,
    required this.onActionSelected,
    required this.currentPath,
  });

  Widget _buildSortItem(String text, bool isSelected) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(text), if (isSelected) const Icon(Icons.check, color: Colors.teal, size: 18)],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHidden = ref.watch(showHiddenFilesProvider);
    final sType = ref.watch(fileSortProvider);
    final sOrder = ref.watch(fileSortOrderProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchDebugScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_border),
          tooltip: 'Bookmarks',
          onPressed: () => FileDialogsDebug.showBookmarksDialog(context, ref, currentPath),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: onActionSelected,
          itemBuilder: (context) => [
            // CREATE
            const PopupMenuItem(value: 'new_folder', child: Row(children: [Icon(Icons.create_new_folder), SizedBox(width: 8), Text('New Folder')])),
            const PopupMenuItem(value: 'new_file', child: Row(children: [Icon(Icons.note_add), SizedBox(width: 8), Text('New File')])),
            const PopupMenuDivider(),

            // SORT BY
            const PopupMenuItem(enabled: false, child: Text('SORT BY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 11))),
            PopupMenuItem(value: 'sort_name', child: _buildSortItem('Name', sType == FileSortType.name)),
            PopupMenuItem(value: 'sort_size', child: _buildSortItem('Size', sType == FileSortType.size)),
            PopupMenuItem(value: 'sort_date', child: _buildSortItem('Date', sType == FileSortType.date)),
            PopupMenuItem(value: 'sort_type', child: _buildSortItem('Type', sType == FileSortType.type)),
            const PopupMenuDivider(),

            // ORDER
            PopupMenuItem(value: 'order_asc', child: _buildSortItem('Ascending ↑', sOrder == FileSortOrder.ascending)),
            PopupMenuItem(value: 'order_desc', child: _buildSortItem('Descending ↓', sOrder == FileSortOrder.descending)),
            const PopupMenuDivider(),

            // VIEW OPTIONS
            const PopupMenuItem(enabled: false, child: Text('VIEW', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 11))),
            PopupMenuItem(
              value: 'toggle_hidden',
              child: Row(children: [
                Icon(showHidden ? Icons.visibility_off : Icons.visibility, size: 20),
                const SizedBox(width: 8),
                Text(showHidden ? 'Hide Hidden Files' : 'Show Hidden Files'),
              ]),
            ),
            const PopupMenuDivider(),

            // TOOLS
            const PopupMenuItem(enabled: false, child: Text('TOOLS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 11))),
            const PopupMenuItem(value: 'index', child: Row(children: [Icon(Icons.refresh, size: 20), SizedBox(width: 8), Text('Rebuild Search Index')])),
            const PopupMenuItem(value: 'trash', child: Row(children: [Icon(Icons.delete_outline, size: 20), SizedBox(width: 8), Text('View Trash')])),
            const PopupMenuDivider(),

            // SUB-APPS
            const PopupMenuItem(enabled: false, child: Text('SUB-APPS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 11))),
            const PopupMenuItem(value: 'shortcut_video', child: Row(children: [Icon(Icons.video_library, size: 20), SizedBox(width: 8), Text('Pin Video Player Shortcut')])),
          ],
        ),
      ],
    );
  }
}

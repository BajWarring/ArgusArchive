import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'search_debug.dart';

enum FileSortType { name, size, date, type }
enum FileSortOrder { ascending, descending }

final fileSortProvider = StateProvider<FileSortType>((ref) => FileSortType.name);
final fileSortOrderProvider = StateProvider<FileSortOrder>((ref) => FileSortOrder.ascending);

class HeaderIconsDebug extends ConsumerWidget {
  final Function(String) onActionSelected;

  const HeaderIconsDebug({
    super.key,
    required this.onActionSelected,
  });

  Widget _buildSortItem(String text, bool isSelected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(text), if (isSelected) const Icon(Icons.check, color: Colors.teal, size: 18)],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.search), 
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchDebugScreen()))
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: onActionSelected,
          itemBuilder: (context) {
            final sType = ref.watch(fileSortProvider);
            final sOrder = ref.watch(fileSortOrderProvider);
            return [
              const PopupMenuItem(value: 'new_folder', child: Row(children: [Icon(Icons.create_new_folder), SizedBox(width: 8), Text('New Folder')])),
              const PopupMenuItem(value: 'new_file', child: Row(children: [Icon(Icons.note_add), SizedBox(width: 8), Text('New File')])),
              const PopupMenuDivider(),
              const PopupMenuItem(enabled: false, child: Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
              PopupMenuItem(value: 'sort_name', child: _buildSortItem('Name', sType == FileSortType.name)),
              PopupMenuItem(value: 'sort_size', child: _buildSortItem('Size', sType == FileSortType.size)),
              PopupMenuItem(value: 'sort_date', child: _buildSortItem('Date', sType == FileSortType.date)),
              PopupMenuItem(value: 'sort_type', child: _buildSortItem('Type', sType == FileSortType.type)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'order_asc', child: _buildSortItem('Ascending', sOrder == FileSortOrder.ascending)),
              PopupMenuItem(value: 'order_desc', child: _buildSortItem('Descending', sOrder == FileSortOrder.descending)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'index', child: Text('Rebuild Search Index')),
            ];
          },
        ),
      ],
    );
  }
}

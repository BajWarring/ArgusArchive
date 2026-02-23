import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../adapters/local/local_storage_adapter.dart';
import '../../services/storage/storage_volumes_service.dart';
import 'providers.dart';

class HeaderPopupMenuDebug extends ConsumerWidget {
  final String currentPath;
  final dynamic currentAdapter;

  const HeaderPopupMenuDebug({
    super.key,
    required this.currentPath,
    required this.currentAdapter,
  });

  String _formatPathForUI(String path) {
    if (path == '/' || path.isEmpty) return 'Root';
    if (path == '/storage/emulated/0' || path == '0') return 'Internal Storage';
    
    String formatted = path;
    if (formatted.startsWith('/storage/emulated/0')) {
      formatted = formatted.replaceFirst('/storage/emulated/0', 'Internal Storage');
    } else {
      formatted = formatted.replaceAll(RegExp(r'/storage/[A-Z0-9]{4}-[A-Z0-9]{4}'), 'SD Card');
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseName = p.basename(currentPath);
    final displayTitle = (currentPath == '/storage/emulated/0' || baseName == '0') 
        ? 'Internal Storage' 
        : _formatPathForUI(baseName);

    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      tooltip: 'Navigation & Drives',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(displayTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_formatPathForUI(currentPath), style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      // ... (Keep the rest of your itemBuilder and onSelected logic exactly the same)
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> items = [];
        items.add(const PopupMenuItem(enabled: false, child: Text('CURRENT PATH', style: TextStyle(fontSize: 11, color: Colors.teal))));
        
        String cumulativePath = '/';
        final segments = currentPath.split('/');
        int indent = 0;
        
        for (int i = 0; i < segments.length; i++) {
          if (segments[i].isEmpty) { continue; }
          cumulativePath = p.join(cumulativePath, segments[i]);
          
          if (cumulativePath == '/storage' || cumulativePath == '/storage/emulated') { continue; }
          
          String displayName = segments[i];
          if (cumulativePath == '/storage/emulated/0') {
            displayName = 'Internal Storage';
          } else if (RegExp(r'^/storage/[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(cumulativePath)) {
            displayName = 'SD Card';
          }

          final navPath = cumulativePath; 
          items.add(PopupMenuItem(
            value: 'nav|$navPath',
            child: Padding(
              padding: EdgeInsets.only(left: (indent * 10.0).clamp(0.0, 40.0)),
              child: Row(children: [const Icon(Icons.subdirectory_arrow_right, size: 16), const SizedBox(width: 8), Text(displayName)]),
            ),
          ));
          indent++;
        }

        items.add(const PopupMenuDivider());
        items.add(const PopupMenuItem(enabled: false, child: Text('DRIVES', style: TextStyle(fontSize: 11, color: Colors.teal))));
        items.add(const PopupMenuItem(value: 'drive|/storage/emulated/0', child: Row(children: [Icon(Icons.phone_android), SizedBox(width: 8), Text('Internal Storage')])));
        items.add(const PopupMenuItem(value: 'drive_sd', child: Row(children: [Icon(Icons.sd_storage), SizedBox(width: 8), Text('SD Card / USB')])));
        
        return items;
      },
      onSelected: (value) async {
        if (value.startsWith('nav|')) {
          ref.read(currentAdapter is LocalStorageAdapter ? currentPathProvider.notifier : realParentPathProvider.notifier).state = value.split('|')[1];
          if (currentAdapter is! LocalStorageAdapter) {
             ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
             ref.read(currentPathProvider.notifier).state = value.split('|')[1];
          }
        } else if (value.startsWith('drive|')) {
          ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
          ref.read(currentPathProvider.notifier).state = value.split('|')[1];
        } else if (value == 'drive_sd') {
          final roots = await StorageVolumesService.getStorageRoots();
          final sdCard = roots.firstWhere((r) => r != '/storage/emulated/0', orElse: () => '');
          if (sdCard.isNotEmpty) {
            ref.read(storageAdapterProvider.notifier).state = LocalStorageAdapter();
            ref.read(currentPathProvider.notifier).state = sdCard;
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No SD Card detected.')));
          }
        }
      },
    );
  }
}

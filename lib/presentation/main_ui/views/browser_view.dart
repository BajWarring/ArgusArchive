import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../ui_theme.dart';
import '../../../core/enums/file_type.dart';
import '../../debug_ui/providers.dart';
import '../widgets/main_ui_dialogs.dart'; // The new bottom sheet logic
import '../../debug_ui/file_bottom_sheets_debug.dart'; // For archive taps

class BrowserView extends ConsumerWidget {
  const BrowserView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(directoryContentsProvider);
    final selectedFiles = ref.watch(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;

    return asyncFiles.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ArgusColors.primary)),
      error: (err, stack) => Center(child: Text('Error loading files: $err', style: const TextStyle(color: Colors.red))),
      data: (files) {
        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: ArgusColors.slate500),
                SizedBox(height: 8),
                Text('Folder is empty', style: TextStyle(color: ArgusColors.slate500, fontWeight: FontWeight.bold)),
              ],
            )
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final isFolder = file.isDirectory;
            final isSelected = selectedFiles.contains(file.path);
            
            IconData icon; Color iconColor; Color bgColor;
            if (isFolder) { icon = Icons.folder; iconColor = ArgusColors.primary; bgColor = ArgusColors.primary.withValues(alpha: 0.1); } 
            else if (file.type == FileType.video) { icon = Icons.movie; iconColor = Colors.purple; bgColor = Colors.purple.withValues(alpha: 0.1); } 
            else if (file.type == FileType.image) { icon = Icons.image; iconColor = Colors.blue; bgColor = Colors.blue.withValues(alpha: 0.1); } 
            else if (file.type == FileType.archive) { icon = Icons.folder_zip; iconColor = Colors.orange; bgColor = Colors.orange.withValues(alpha: 0.1); } 
            else if (file.path.toLowerCase().endsWith('.apk')) { icon = Icons.android; iconColor = Colors.green; bgColor = Colors.green.withValues(alpha: 0.1); } 
            else { icon = Icons.insert_drive_file; iconColor = ArgusColors.slate500; bgColor = Colors.blueGrey.withValues(alpha: 0.1); }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                
                // WORKING LONG PRESS -> Opens HTML styled Bottom Sheet
                onLongPress: () {
                  if (isSelectionMode) return;
                  MainUIDialogs.showActionBottomSheet(context, ref, file, icon: icon, iconColor: iconColor);
                },
                
                onTap: () async {
                  if (isSelectionMode) {
                     final set = Set<String>.from(selectedFiles);
                     if (isSelected) set.remove(file.path); else set.add(file.path);
                     ref.read(selectedFilesProvider.notifier).state = set;
                  } else if (isFolder) {
                     ref.read(currentPathProvider.notifier).state = file.path;
                  } else {
                     final ext = p.extension(file.path).toLowerCase();
                     final isArchive = ext == '.zip' || ext == '.apk' || ext == '.rar';
                     
                     // WORKING APK & ZIP TAPS
                     if (isArchive) {
                       FileBottomSheetsDebug.showArchiveTapMenu(context, ref, file, isApk: ext == '.apk');
                     } else {
                       final registry = ref.read(fileHandlerRegistryProvider);
                       final handler = registry.handlerFor(file);
                       if (handler != null) {
                         await handler.open(context, file, ref.read(storageAdapterProvider));
                       } else if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app found to open this file.')));
                       }
                     }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? ArgusColors.primary.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? ArgusColors.primary.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))]
                  ),
                  child: Row(
                    children: [
                      if (isSelectionMode)
                        Container(
                          width: 40, height: 40, alignment: Alignment.center,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? ArgusColors.primary : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? ArgusColors.primary : Colors.grey.shade400, width: 2),
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        )
                      else
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.basename(file.path), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(isFolder ? 'Folder' : '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB • ${file.modifiedAt.day}/${file.modifiedAt.month}', style: const TextStyle(fontSize: 12, color: ArgusColors.slate500)),
                          ],
                        ),
                      ),
                      if (!isSelectionMode)
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: ArgusColors.slate500),
                          onPressed: () => MainUIDialogs.showActionBottomSheet(context, ref, file, icon: icon, iconColor: iconColor),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }
}

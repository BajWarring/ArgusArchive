import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../ui_theme.dart';
import '../../../core/enums/file_type.dart';
import '../../debug_ui/providers.dart';
import '../../../services/operations/video_thumbnail_service.dart';

class VideoExplorerView extends ConsumerWidget {
  final String currentPath;
  final Function(String) onFolderEnter;

  const VideoExplorerView({super.key, required this.currentPath, required this.onFolderEnter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFiles = ref.watch(directoryContentsProvider);

    return asyncFiles.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ArgusColors.primary)),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (allFiles) {
        final files = allFiles.where((f) => f.isDirectory || f.type == FileType.video).toList();

        if (files.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('No videos found here', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            )
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final isFolder = file.isDirectory;

            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (isFolder) {
                  onFolderEnter(file.path);
                } else {
                   final registry = ref.read(fileHandlerRegistryProvider);
                   final adapter = ref.read(storageAdapterProvider);
                   
                   // FIXED: Uses handlerFor()
                   final handler = registry.handlerFor(file);
                   if (handler != null) handler.open(context, file, adapter);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ArgusColors.surfaceDark.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    if (isFolder)
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: ArgusColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.folder, color: ArgusColors.primary),
                      )
                    else
                      Container(
                        width: 64, height: 48,
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FutureBuilder<Uint8List?>(
                              future: VideoThumbnailService.getThumbnail(file.path),
                              builder: (ctx, tSnap) {
                                if (tSnap.hasData && tSnap.data != null) {
                                  return Image.memory(tSnap.data!, fit: BoxFit.cover);
                                }
                                return const SizedBox.shrink();
                              }
                            ),
                            Container(color: Colors.black45),
                            const Center(child: Icon(Icons.play_arrow, color: Colors.white70)),
                          ],
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.basename(file.path), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(
                            isFolder ? 'Folder' : '${(file.size / 1024 / 1024).toStringAsFixed(1)} MB', 
                            style: const TextStyle(fontSize: 10, color: Colors.grey)
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_vert, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
}

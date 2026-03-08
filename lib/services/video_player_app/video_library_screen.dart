import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../providers/video_history_provider.dart';
import '../../features/file_handlers/file_handler_registry.dart'; 
import '../../presentation/debug_ui/file_thumbnail_debug.dart'; 

class VideoLibraryScreen extends ConsumerWidget {
  const VideoLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPathProvider);
    final asyncFiles = ref.watch(directoryContentsProvider);
    final history = ref.watch(videoHistoryProvider);

    final canGoBack = currentPath != '/storage/emulated/0' && currentPath != '/';

    return PopScope(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(currentPathProvider.notifier).state = p.dirname(currentPath);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text('Video Library', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. History Section
            if (history.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('RECENTLY PLAYED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: 1.2)),
              ),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final progress = item.durationMs > 0 ? (item.positionMs / item.durationMs) : 0.0;
                    
                    return GestureDetector(
                      onTap: () {
                        final registry = ref.read(fileHandlerRegistryProvider);
                        final adapter = ref.read(storageAdapterProvider);
                        final entry = FileEntry(
                          id: item.path,
                          path: item.path,
                          type: FileType.video,
                          size: 0,
                          modifiedAt: item.lastPlayed,
                        );
                        registry.handlerFor(entry)?.open(context, entry, adapter);
                      },
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                    child: FileThumbnailDebug(
                                      file: FileEntry(id: item.path, path: item.path, type: FileType.video, size: 0, modifiedAt: DateTime.now()),
                                      adapter: ref.read(storageAdapterProvider),
                                      isDirectory: false,
                                    ),
                                  ),
                                  const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.teal)),
                                ],
                              ),
                            ),
                            LinearProgressIndicator(value: progress, backgroundColor: Colors.black, color: Colors.teal),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white10, height: 24),
            ],

            // 2. Navigation Header (Debug UI Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  if (canGoBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => ref.read(currentPathProvider.notifier).state = p.dirname(currentPath),
                    ),
                  Expanded(
                    child: Text(currentPath, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

            // 3. Filtered File List
            Expanded(
              child: asyncFiles.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
                data: (files) {
                  // FILTER: Only show directories OR video files
                  final filtered = files.where((f) {
                     if (f.isDirectory) return true;
                     return f.type == FileType.video || ['mp4','mkv','avi','webm'].contains(p.extension(f.path).toLowerCase().replaceAll('.',''));
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No videos found here.', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    );
                  }

                  return ListView.builder(
                    itemCount: canGoBack ? filtered.length + 1 : filtered.length,
                    itemBuilder: (context, index) {
                      if (canGoBack && index == 0) {
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.drive_folder_upload, color: Colors.blueGrey)),
                          title: const Text('..'),
                          subtitle: const Text('Parent folder', style: TextStyle(fontSize: 11)),
                          onTap: () => ref.read(currentPathProvider.notifier).state = p.dirname(currentPath),
                        );
                      }

                      final file = filtered[canGoBack ? index - 1 : index];
                      final isFolder = file.isDirectory;

                      return ListTile(
                        leading: SizedBox(
                           width: 40, height: 40,
                           child: FileThumbnailDebug(file: file, adapter: ref.read(storageAdapterProvider), isDirectory: isFolder)
                        ),
                        title: Text(p.basename(file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: isFolder ? const Text('Folder') : Text('${(file.size / 1024 / 1024).toStringAsFixed(1)} MB'),
                        onTap: () {
                          if (isFolder) {
                            ref.read(currentPathProvider.notifier).state = file.path;
                          } else {
                            final registry = ref.read(fileHandlerRegistryProvider);
                            final adapter = ref.read(storageAdapterProvider);
                            registry.handlerFor(file)?.open(context, file, adapter);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

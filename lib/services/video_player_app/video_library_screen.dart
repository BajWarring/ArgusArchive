import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/enums/file_type.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../providers/video_history_provider.dart';

final videoBrowsePathProvider = StateProvider<String>((ref) => '/storage/emulated/0');

class VideoLibraryScreen extends ConsumerWidget {
  const VideoLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(videoBrowsePathProvider);
    final asyncFiles = ref.watch(directoryContentsProvider(currentPath));
    final history = ref.watch(videoHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Library', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {
            // Settings logic
          })
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. History Section
          if (history.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('RECENTLY PLAYED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final progress = item.durationMs > 0 ? (item.positionMs / item.durationMs) : 0.0;
                  
                  return GestureDetector(
                    onTap: () {
                      // Uses the handler registry to open the video player natively
                      final registry = ref.read(fileHandlerRegistryProvider);
                      final adapter = ref.read(storageAdapterProvider);
                      // Create a dummy file entry to pass to the handler
                      registry.handlers.firstWhere((h) => h.runtimeType.toString() == 'VideoHandler')
                          .open(context, adapter.list(item.path) as dynamic, adapter); 
                          // NOTE: You'll want to adapt this to your specific VideoHandler interface
                    },
                    child: Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.blue)),
                          ),
                          LinearProgressIndicator(value: progress, backgroundColor: Colors.black, color: Colors.blue),
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
            const Divider(color: Colors.white10),
          ],

          // 2. Navigation Header (Debug UI Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                if (currentPath != '/storage/emulated/0')
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => ref.read(videoBrowsePathProvider.notifier).state = p.dirname(currentPath),
                  ),
                Expanded(
                  child: Text(currentPath, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          // 3. Filtered File List (Videos and Folders Only)
          Expanded(
            child: asyncFiles.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
              data: (files) {
                // FILTER: Only show directories OR video files
                final filtered = files.where((f) => f.isDirectory || f.type == FileType.video).toList();

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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final file = filtered[index];
                    final isFolder = file.isDirectory;

                    return ListTile(
                      leading: Icon(isFolder ? Icons.folder : Icons.movie, color: isFolder ? Colors.amber : Colors.blue),
                      title: Text(p.basename(file.path)),
                      subtitle: isFolder ? const Text('Folder') : Text('${(file.size / 1024 / 1024).toStringAsFixed(1)} MB'),
                      onTap: () {
                        if (isFolder) {
                          ref.read(videoBrowsePathProvider.notifier).state = file.path;
                        } else {
                          final registry = ref.read(fileHandlerRegistryProvider);
                          final adapter = ref.read(storageAdapterProvider);
                          final handler = registry.handlerFor(file);
                          if (handler != null) {
                            handler.open(context, file, adapter);
                          }
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
    );
  }
}

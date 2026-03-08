import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/enums/file_type.dart';
import '../../debug_ui/providers.dart';
import '../../../providers/video_history_provider.dart';
import '../../ui_theme.dart';

final videoBrowsePathProvider = StateProvider<String>((ref) => '/storage/emulated/0');

class BrowseView extends ConsumerWidget {
  const BrowseView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(videoBrowsePathProvider);
    final asyncFiles = ref.watch(directoryContentsProvider(currentPath));
    final history = ref.watch(videoHistoryProvider);

    return Column(
      children: [
        // 1. History Section
        if (history.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('RECENTLY PLAYED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            ),
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
                    // Open player with history settings
                  },
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: ArgusColors.surfaceDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Center(child: Icon(Icons.play_circle_fill, size: 40, color: ArgusColors.primary)),
                        ),
                        LinearProgressIndicator(value: progress, backgroundColor: Colors.black, color: ArgusColors.primary),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

        // 2. Navigation Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

        // 3. Filtered File List
        Expanded(
          child: asyncFiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
            data: (files) {
              final filtered = files.where((f) => f.isDirectory || f.type == FileType.video).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No videos found in this folder.', style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final file = filtered[index];
                  final isFolder = file.isDirectory;

                  return ListTile(
                    leading: Icon(isFolder ? Icons.folder : Icons.movie, color: isFolder ? Colors.amber : ArgusColors.primary),
                    title: Text(p.basename(file.path)),
                    subtitle: isFolder ? const Text('Folder') : Text('${(file.size / 1024 / 1024).toStringAsFixed(1)} MB'),
                    onTap: () {
                      if (isFolder) {
                        ref.read(videoBrowsePathProvider.notifier).state = file.path;
                      } else {
                        // Open Native Video Player
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
    );
  }
}

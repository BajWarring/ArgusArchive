import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../ui_theme.dart';
import '../../../core/models/file_entry.dart';
import '../../../core/enums/file_type.dart';
import '../../debug_ui/search_providers.dart';
import '../../debug_ui/providers.dart';
import '../../../services/operations/video_thumbnail_service.dart';

class VideoGridView extends ConsumerWidget {
  const VideoGridView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REAL DATA: Fetch database provider
    final dbAsync = ref.watch(searchDatabaseProvider);

    return dbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ArgusColors.primary)),
      error: (e, s) => Center(child: Text('Error loading database: $e')),
      data: (db) {
        return FutureBuilder<List<FileEntry>>(
          // Fetch real videos from the FTS index
          future: db.search(query: '', filterType: FileType.video).then((v) {
            v.sort((a,b) => b.modifiedAt.compareTo(a.modifiedAt));
            return v;
          }),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: ArgusColors.primary));
            
            final videos = snap.data ?? [];
            if (videos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    const Text('No videos found in index.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Padding for bottom nav
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                     // REAL DATA: Launch Native Video Player!
                     final handlers = ref.read(fileHandlerRegistryProvider);
                     final adapter = ref.read(storageAdapterProvider);
                     for (var h in handlers) {
                       if (h.canHandle(video)) { 
                         h.open(context, video, adapter); 
                         break; 
                       }
                     }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // REAL DATA: Native Kotlin Thumbnail Bridge
                              FutureBuilder<Uint8List?>(
                                future: VideoThumbnailService.getThumbnail(video.path),
                                builder: (ctx, tSnap) {
                                  if (tSnap.hasData && tSnap.data != null) {
                                    return Image.memory(tSnap.data!, fit: BoxFit.cover);
                                  }
                                  return const Center(child: Icon(Icons.movie, color: Colors.indigo, size: 32));
                                }
                              ),
                              Container(color: Colors.black26),
                              const Center(
                                child: CircleAvatar(
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.play_arrow, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(p.basenameWithoutExtension(video.path), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${(video.size / 1024 / 1024).toStringAsFixed(1)} MB • ${video.modifiedAt.day}/${video.modifiedAt.month}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              },
            );
          }
        );
      }
    );
  }
}

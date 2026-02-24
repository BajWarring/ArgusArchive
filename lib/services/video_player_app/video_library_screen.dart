import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/search_providers.dart';
import '../../presentation/debug_ui/file_thumbnail_debug.dart';
import '../../presentation/debug_ui/providers.dart';
import '../file_handlers/video_handler.dart';

class VideoLibraryScreen extends ConsumerWidget {
  const VideoLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(searchDatabaseProvider);
    final adapter = ref.watch(storageAdapterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Library', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: dbAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
        error: (err, stack) => Center(child: Text('Error loading library: $err')),
        data: (db) {
          return FutureBuilder<List<FileEntry>>(
            future: db.search(query: '', filterType: FileType.video).then((videos) {
              // Sort date descending
              videos.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
              return videos;
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final videos = snapshot.data ?? [];
              if (videos.isEmpty) {
                return const Center(child: Text('No videos found on device.', style: TextStyle(color: Colors.grey)));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 16 / 12,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  String dateStr = "${video.modifiedAt.day}/${video.modifiedAt.month}/${video.modifiedAt.year}";
                  
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(entry: video))),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FileThumbnailDebug(file: video, adapter: adapter, isDirectory: false),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8, left: 8, right: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.basenameWithoutExtension(video.path),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 48)),
                      ],
                    ),
                  );
                },
              );
            },
          );
        }
      ),
    );
  }
}

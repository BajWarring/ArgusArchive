import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/search_providers.dart';
import '../../features/file_handlers/video_handler.dart';
import '../operations/video_thumbnail_service.dart'; // The new bridge

class VideoLibraryScreen extends ConsumerWidget {
  const VideoLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(searchDatabaseProvider);

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
            // Pass an empty string, the upgraded FTS engine will now safely return all videos!
            future: db.search(query: '', filterType: FileType.video),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final videos = snapshot.data ?? [];
              if (videos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No videos found on device.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(searchDatabaseProvider),
                        child: const Text('Refresh Library')
                      )
                    ],
                  )
                );
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
                          child: Container(
                            color: Colors.grey[900], // Background color while native thumbnail loads
                            child: FutureBuilder<Uint8List?>(
                              future: VideoThumbnailService.getThumbnail(video.path),
                              builder: (context, thumbSnapshot) {
                                if (thumbSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                }
                                if (thumbSnapshot.hasData && thumbSnapshot.data != null) {
                                  return Image.memory(
                                    thumbSnapshot.data!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  );
                                }
                                return const Center(child: Icon(Icons.movie, size: 40, color: Colors.indigo));
                              }
                            ),
                          ),
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
            }
          );
        }
      ),
    );
  }
}

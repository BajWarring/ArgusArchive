import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../providers/media_history_provider.dart';

class MediaFolderDetailScreen extends ConsumerStatefulWidget {
  final String folderPath;
  final bool isVideo;

  const MediaFolderDetailScreen({super.key, required this.folderPath, required this.isVideo});

  @override
  ConsumerState<MediaFolderDetailScreen> createState() => _MediaFolderDetailScreenState();
}

class _MediaFolderDetailScreenState extends ConsumerState<MediaFolderDetailScreen> {
  
  Future<List<FileEntry>> _fetchMedia() async {
    final adapter = ref.read(storageAdapterProvider);
    try {
      final allFiles = await adapter.list(widget.folderPath);
      return allFiles.where((f) {
        if (f.isDirectory) return false;
        final ext = p.extension(f.path).toLowerCase().replaceAll('.', '');
        if (widget.isVideo) {
          return f.type == FileType.video || ['mp4','mkv','webm','avi'].contains(ext);
        } else {
          return f.type == FileType.audio || ['mp3','wav','aac','m4a','ogg'].contains(ext);
        }
      }).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.folderPath), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
      ),
      body: FutureBuilder<List<FileEntry>>(
        future: _fetchMedia(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E00)));
          }
          final files = snapshot.data ?? [];
          if (files.isEmpty) {
            return const Center(child: Text('No media files found in this folder.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final sizeMb = (file.size / 1024 / 1024).toStringAsFixed(1);
              final date = '${file.modifiedAt.day}/${file.modifiedAt.month}/${file.modifiedAt.year}';
              
              return InkWell(
                onTap: () {
                  if (!widget.isVideo) {
                    ref.read(mediaHistoryProvider.notifier).save(
                      MediaHistoryItem(
                        path: file.path,
                        title: p.basename(file.path),
                        type: 'audio',
                        positionMs: 0, durationMs: 0,
                        lastPlayed: DateTime.now(),
                      )
                    );
                  }
                  
                  final registry = ref.read(fileHandlerRegistryProvider);
                  final adapter = ref.read(storageAdapterProvider);
                  registry.handlerFor(file)?.open(context, file, adapter);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Container(
                        width: widget.isVideo ? 110 : 48, 
                        height: widget.isVideo ? 70 : 48,
                        decoration: BoxDecoration(color: widget.isVideo ? const Color(0xFFE0E0E0) : const Color(0xFF2C3E50), borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Icon(widget.isVideo ? Icons.play_circle_fill : Icons.music_note, color: Colors.white70, size: widget.isVideo ? 32 : 24)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.basename(file.path), style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Text('$sizeMb MB  •  $date', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E8E)), onPressed: (){}),
                    ],
                  ),
                ),
              );
            },
          );
        }
      )
    );
  }
}

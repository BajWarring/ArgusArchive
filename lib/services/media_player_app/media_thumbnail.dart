import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/models/file_entry.dart';
import '../operations/video_thumbnail_service.dart';

class MediaThumbnail extends StatelessWidget {
  final FileEntry file;
  final bool isVideo;

  const MediaThumbnail({super.key, required this.file, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: isVideo 
          ? VideoThumbnailService.getThumbnail(file.path)
          : VideoThumbnailService.getAudioThumbnail(file.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: isVideo ? const Color(0xFFE0E0E0) : const Color(0xFF2C3E50));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!, 
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        
        // Native fallback if no thumbnail/album art exists
        return Container(
          color: isVideo ? const Color(0xFFE0E0E0) : const Color(0xFF2C3E50),
          child: Center(
            child: Icon(
              isVideo ? Icons.play_circle_fill : Icons.music_note, 
              color: Colors.white70, 
              size: isVideo ? 32 : 24
            ),
          ),
        );
      },
    );
  }
}

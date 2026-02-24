import 'package:flutter/material.dart';
import '../../ui_theme.dart';

class VideoExplorerView extends StatelessWidget {
  const VideoExplorerView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), // Bottom padding for nav bar
      itemCount: 8,
      itemBuilder: (context, index) {
        if (index == 0) return _buildGoBackRow(); // Matches the Go Back row from HTML
        
        bool isFolder = index < 3;
        return Container(
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
                  child: const Center(child: Icon(Icons.play_arrow, color: Colors.white70)),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isFolder ? 'Folder $index' : 'Video_Clip_$index.mp4', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(isFolder ? 'Today • 4 items' : 'Oct 20 • 450 MB • 14:20', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.more_vert, color: Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoBackRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
            child: const Icon(Icons.turn_left, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          const Text('Go Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}

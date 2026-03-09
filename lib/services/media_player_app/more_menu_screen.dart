import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../providers/media_history_provider.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../presentation/debug_ui/providers.dart';
import 'media_thumbnail.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(mediaHistoryProvider);
    final videoHistory = history.where((e) => e.type == 'video').toList();
    final audioHistory = history.where((e) => e.type == 'audio').toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('More', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF4A4A4A)), onPressed: () {})],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF5E00),
        onRefresh: () async {
          ref.invalidate(mediaHistoryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(4)), 
                  child: ListTile(
                    leading: const Icon(Icons.settings_outlined, color: Color(0xFFFF5E00)), 
                    title: const Text('SETTINGS', style: TextStyle(color: Color(0xFFFF5E00), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                    onTap: () {},
                  )
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(4)), 
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Color(0xFFFF5E00)), 
                    title: const Text('ABOUT', style: TextStyle(color: Color(0xFFFF5E00), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                    onTap: () {},
                  )
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Divider(color: Color(0xFFE0E0E0))),
              
              _buildHistorySection('Video History'),
              _buildHistoryList(context, ref, videoHistory, true),

              _buildHistorySection('Audio History'),
              _buildHistoryList(context, ref, audioHistory, false),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFFF5E00), fontSize: 18, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_forward, color: Colors.black87),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, WidgetRef ref, List<MediaHistoryItem> history, bool isVideo) {
    if (history.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text('No ${isVideo ? 'video' : 'audio'} history recorded yet.', style: const TextStyle(color: Colors.grey)));
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final item = history[index];
          final progress = item.durationMs > 0 ? (item.positionMs / item.durationMs).clamp(0.0, 1.0) : 0.0;
          final entry = FileEntry(id: item.path, path: item.path, type: isVideo ? FileType.video : FileType.audio, size: 0, modifiedAt: item.lastPlayed);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () {
                final registry = ref.read(fileHandlerRegistryProvider);
                registry.handlerFor(entry)?.open(context, entry, ref.read(storageAdapterProvider));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120, height: 90,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MediaThumbnail(file: entry, isVideo: isVideo),
                        if (isVideo)
                          Align(alignment: Alignment.bottomLeft, child: FractionallySizedBox(widthFactor: progress, child: Container(height: 3, color: const Color(0xFFFF5E00))))
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: 120, child: Text(p.basename(item.path), style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

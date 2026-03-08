import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../providers/video_history_provider.dart';
import '../../features/file_handlers/file_handler_registry.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../presentation/debug_ui/providers.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the real data!
    final videoHistory = ref.watch(videoHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('More', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF4A4A4A)), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
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
                ),
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
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Divider(color: Color(0xFFE0E0E0))),
            
            _buildHistorySection('Video History'),
            _buildVideoHistoryList(context, ref, videoHistory),

            _buildHistorySection('Audio History'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('No audio history recorded yet.', style: TextStyle(color: Colors.grey)),
            ),
            
            const SizedBox(height: 24),
          ],
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

  Widget _buildVideoHistoryList(BuildContext context, WidgetRef ref, List<VideoHistoryItem> history) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0),
        child: Text('No video history recorded yet.', style: TextStyle(color: Colors.grey)),
      );
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () {
                final registry = ref.read(fileHandlerRegistryProvider);
                final adapter = ref.read(storageAdapterProvider);
                final entry = FileEntry(id: item.path, path: item.path, type: FileType.video, size: 0, modifiedAt: item.lastPlayed);
                registry.handlerFor(entry)?.open(context, entry, adapter);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120, height: 90,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(4)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Center(child: Icon(Icons.movie, color: Colors.white70, size: 40)),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(height: 3, color: const Color(0xFFFF5E00)),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 120,
                    child: Text(p.basename(item.path), style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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

// ─── Sort options ─────────────────────────────────────────────────────────────
enum VideoSortBy { dateDesc, dateAsc, name, size }

final videoSortProvider = StateProvider<VideoSortBy>((ref) => VideoSortBy.dateDesc);
final videoViewModeProvider = StateProvider<bool>((ref) => true); // true = grid, false = list

// ─── Main grid widget ─────────────────────────────────────────────────────────
class VideoGridView extends ConsumerWidget {
  const VideoGridView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(searchDatabaseProvider);
    final sortBy = ref.watch(videoSortProvider);
    final isGrid = ref.watch(videoViewModeProvider);

    return dbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ArgusColors.primary)),
      error: (e, s) => _ErrorState(message: e.toString()),
      data: (db) {
        return FutureBuilder<List<FileEntry>>(
          future: db.search(query: '', filterType: FileType.video).then((v) {
            switch (sortBy) {
              case VideoSortBy.dateDesc: v.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
              case VideoSortBy.dateAsc:  v.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
              case VideoSortBy.name:     v.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
              case VideoSortBy.size:     v.sort((a, b) => b.size.compareTo(a.size));
            }
            return v;
          }),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: ArgusColors.primary));
            }

            final videos = snap.data ?? [];

            if (videos.isEmpty) {
              return _EmptyState(message: 'No videos in index yet.\nRebuild the search index from ⋮ menu.');
            }

            return CustomScrollView(
              slivers: [
                // ── Stats + toolbar ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _VideoToolbar(
                    count: videos.length,
                    totalSize: videos.fold(0, (s, v) => s + v.size),
                    sortBy: sortBy,
                    isGrid: isGrid,
                    onSort: (s) => ref.read(videoSortProvider.notifier).state = s,
                    onToggleView: () => ref.read(videoViewModeProvider.notifier).state = !isGrid,
                  ),
                ),

                // ── Grid / List ────────────────────────────────────────────
                isGrid
                    ? SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _VideoGridCard(video: videos[i], ref: ref),
                            childCount: videos.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.78,
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _VideoListTile(video: videos[i], ref: ref),
                            childCount: videos.length,
                          ),
                        ),
                      ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Toolbar ──────────────────────────────────────────────────────────────────
class _VideoToolbar extends StatelessWidget {
  final int count;
  final int totalSize;
  final VideoSortBy sortBy;
  final bool isGrid;
  final void Function(VideoSortBy) onSort;
  final VoidCallback onToggleView;

  const _VideoToolbar({
    required this.count,
    required this.totalSize,
    required this.sortBy,
    required this.isGrid,
    required this.onSort,
    required this.onToggleView,
  });

  String get _sortLabel {
    switch (sortBy) {
      case VideoSortBy.dateDesc: return 'Newest';
      case VideoSortBy.dateAsc: return 'Oldest';
      case VideoSortBy.name: return 'Name';
      case VideoSortBy.size: return 'Size';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count video${count != 1 ? 's' : ''}  •  ${_fmtBytes(totalSize)}',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 12,
              ),
            ),
          ),
          // Sort popup
          PopupMenuButton<VideoSortBy>(
            tooltip: 'Sort',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black08,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 16, color: ArgusColors.primary),
                  const SizedBox(width: 4),
                  Text(_sortLabel,
                      style: const TextStyle(color: ArgusColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            onSelected: onSort,
            itemBuilder: (_) => [
              _sortItem(VideoSortBy.dateDesc, 'Newest First', sortBy),
              _sortItem(VideoSortBy.dateAsc, 'Oldest First', sortBy),
              _sortItem(VideoSortBy.name, 'By Name', sortBy),
              _sortItem(VideoSortBy.size, 'By Size', sortBy),
            ],
          ),
          const SizedBox(width: 4),
          // View mode toggle
          IconButton(
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view, size: 20, color: ArgusColors.primary),
            onPressed: onToggleView,
            tooltip: isGrid ? 'List view' : 'Grid view',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<VideoSortBy> _sortItem(VideoSortBy value, String label, VideoSortBy current) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(value == current ? Icons.radio_button_checked : Icons.radio_button_off,
              color: value == current ? ArgusColors.primary : Colors.grey, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

// ─── Grid Card ────────────────────────────────────────────────────────────────
class _VideoGridCard extends StatelessWidget {
  final FileEntry video;
  final WidgetRef ref;
  const _VideoGridCard({required this.video, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _openVideo(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? ArgusColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Black base
                    Container(color: Colors.black),
                    // Thumbnail
                    FutureBuilder<Uint8List?>(
                      future: VideoThumbnailService.getThumbnail(video.path),
                      builder: (_, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Image.memory(snap.data!, fit: BoxFit.cover);
                        }
                        return Center(
                          child: Icon(Icons.movie_outlined,
                              color: Colors.white24,
                              size: MediaQuery.of(context).size.width * 0.08),
                        );
                      },
                    ),
                    // Gradient overlay
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                    // Play button
                    const Center(
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                    // Size badge (bottom-left)
                    Positioned(
                      bottom: 6, left: 6,
                      child: _Badge(label: _fmtBytes(video.size), color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basenameWithoutExtension(video.path),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDate(video.modifiedAt),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideo(BuildContext context) {
    final registry = ref.read(fileHandlerRegistryProvider);
    final adapter = ref.read(storageAdapterProvider);
    final handler = registry.handlerFor(video);
    if (handler != null) handler.open(context, video, adapter);
  }
}

// ─── List Tile ────────────────────────────────────────────────────────────────
class _VideoListTile extends StatelessWidget {
  final FileEntry video;
  final WidgetRef ref;
  const _VideoListTile({required this.video, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final registry = ref.read(fileHandlerRegistryProvider);
        final adapter = ref.read(storageAdapterProvider);
        final handler = registry.handlerFor(video);
        if (handler != null) handler.open(context, video, adapter);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? ArgusColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black),
                    FutureBuilder<Uint8List?>(
                      future: VideoThumbnailService.getThumbnail(video.path),
                      builder: (_, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Image.memory(snap.data!, fit: BoxFit.cover);
                        }
                        return const Center(child: Icon(Icons.movie_outlined, color: Colors.white24, size: 24));
                      },
                    ),
                    const Center(child: Icon(Icons.play_arrow, color: Colors.white70, size: 20)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.basenameWithoutExtension(video.path),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _fmtBytes(video.size),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const Text('  •  ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(
                        _fmtDate(video.modifiedAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.more_vert, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Empty / Error states ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 72, color: Colors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text('Error: $message', style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String _fmtDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// Needed for opacity workaround
extension on double {
  double get clamp01 => clamp(0.0, 1.0);
}

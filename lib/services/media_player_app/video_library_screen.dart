import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../presentation/debug_ui/search_providers.dart';

class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});
  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper to fetch all videos from indexer
  Future<List<FileEntry>> _fetchVideos() async {
    final db = await ref.read(searchDatabaseProvider.future);
    final results = await db.search(query: '', filterType: FileType.video);
    // Add manual extension fallback for safety
    final allFiles = await db.search(query: '');
    final fallback = allFiles.where((f) => 
      f.type == FileType.video || ['mp4','mkv','webm','avi'].contains(p.extension(f.path).toLowerCase().replaceAll('.',''))
    ).toList();
    return fallback.toSet().toList(); // Ensure unique
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Library', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Color(0xFF4A4A4A)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF4A4A4A)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline, color: Color(0xFF4A4A4A)), onPressed: () {}),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFF5E00),
          unselectedLabelColor: const Color(0xFF6B6B6B),
          indicatorColor: const Color(0xFFFF5E00),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13, letterSpacing: 1.2),
          tabs: const [Tab(text: 'FOLDERS'), Tab(text: 'VIDEOS'), Tab(text: 'PLAYLISTS')],
        ),
      ),
      body: FutureBuilder<List<FileEntry>>(
        future: _fetchVideos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E00)));
          }
          final videos = snapshot.data ?? [];
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildFoldersList(videos), 
              _buildVideosList(videos), 
              _buildPlaylists()
            ],
          );
        }
      ),
    );
  }

  Widget _buildFoldersList(List<FileEntry> videos) {
    // 1. Group videos by their parent folder path
    final Map<String, List<FileEntry>> groupedFolders = {};
    for (var video in videos) {
      final dir = p.dirname(video.path);
      groupedFolders.putIfAbsent(dir, () => []).add(video);
    }

    final folderPaths = groupedFolders.keys.toList()..sort((a,b) => p.basename(a).compareTo(p.basename(b)));

    if (folderPaths.isEmpty) {
      return const Center(child: Text('No video folders found.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: folderPaths.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final path = folderPaths[index];
        final folderVideos = groupedFolders[path]!;
        final folderName = p.basename(path);
        final isFirst = index == 0; 
        
        return InkWell(
          onTap: () {
            // Update global path and navigate back to main file browser to view folder
            ref.read(currentPathProvider.notifier).state = path;
            Navigator.pop(context); 
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 65, height: 50,
                  decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(8)),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0, left: 0,
                        child: Container(
                          width: 25, height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE5E5E5),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                          ),
                        ),
                      ),
                      const Center(child: Icon(Icons.folder, color: Color(0xFFB0B0B0))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(folderName, style: TextStyle(fontSize: 16, color: isFirst ? const Color(0xFFFF5E00) : const Color(0xFF1A1A1A), fontWeight: isFirst ? FontWeight.bold : FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${folderVideos.length} video${folderVideos.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosList(List<FileEntry> videos) {
    if (videos.isEmpty) {
      return const Center(child: Text('No videos found.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: videos.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final video = videos[index];
        final sizeMb = (video.size / 1024 / 1024).toStringAsFixed(1);
        final date = '${video.modifiedAt.day}/${video.modifiedAt.month}/${video.modifiedAt.year}';
        
        return InkWell(
          onTap: () {
            final registry = ref.read(fileHandlerRegistryProvider);
            final adapter = ref.read(storageAdapterProvider);
            registry.handlerFor(video)?.open(context, video, adapter);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Container(
                  width: 110, height: 70,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(6)),
                  child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 32)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.basename(video.path), style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 14, color: Color(0xFF8E8E8E)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(p.basename(p.dirname(video.path)), style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 4),
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

  Widget _buildPlaylists() {
    // Playlists remain mock since the app backend doesn't have a playlist manager yet
    final playlists = [
      {'name': 'Favorites', 'count': 0, 'icon': Icons.favorite_border},
      {'name': 'Watch Later', 'count': 0, 'icon': Icons.watch_later_outlined},
    ];

    return ListView.builder(
      itemCount: playlists.length + 1, 
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xFFFF5E00)),
                    SizedBox(width: 8),
                    Text('Create New Playlist', style: TextStyle(color: Color(0xFFFF5E00), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ),
          );
        }
        final playlist = playlists[index - 1];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: const Color(0xFFFFF0E6), borderRadius: BorderRadius.circular(8)),
            child: Icon(playlist['icon'] as IconData, color: const Color(0xFFFF5E00), size: 28),
          ),
          title: Text(playlist['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          subtitle: Text('${playlist['count']} videos', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          trailing: IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E8E)), onPressed: (){}),
          onTap: () {},
        );
      },
    );
  }
}

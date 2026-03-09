import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../presentation/debug_ui/search_providers.dart';
import 'media_folder_detail_screen.dart'; // NEW

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

  Future<List<FileEntry>> _fetchVideos() async {
    final db = await ref.read(searchDatabaseProvider.future);
    final results = await db.search(query: '', filterType: FileType.video);
    final allFiles = await db.search(query: '');
    final fallback = allFiles.where((f) => 
      ['mp4','mkv','webm','avi'].contains(p.extension(f.path).toLowerCase().replaceAll('.',''))
    ).toList();
    return {...results, ...fallback}.toList(); 
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
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E00)));
          final videos = snapshot.data ?? [];
          return TabBarView(
            controller: _tabController,
            children: [ _buildFoldersList(videos), _buildVideosList(videos), _buildPlaylists() ],
          );
        }
      ),
    );
  }

  Widget _buildFoldersList(List<FileEntry> videos) {
    final Map<String, List<FileEntry>> groupedFolders = {};
    for (var video in videos) {
      final dir = p.dirname(video.path);
      groupedFolders.putIfAbsent(dir, () => []).add(video);
    }
    final folderPaths = groupedFolders.keys.toList()..sort((a,b) => p.basename(a).compareTo(p.basename(b)));

    if (folderPaths.isEmpty) return const Center(child: Text('No video folders found.', style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      itemCount: folderPaths.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final path = folderPaths[index];
        final folderVideos = groupedFolders[path]!;
        
        return InkWell(
          // NEW NAVIGATION BEHAVIOR
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaFolderDetailScreen(folderPath: path, isVideo: true))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 65, height: 50,
                  decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(8)),
                  child: Stack(
                    children: [
                      Positioned(top: 0, left: 0, child: Container(width: 25, height: 10, decoration: const BoxDecoration(color: Color(0xFFE5E5E5), borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))))),
                      const Center(child: Icon(Icons.folder, color: Color(0xFFB0B0B0))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.basename(path), style: TextStyle(fontSize: 16, color: index == 0 ? const Color(0xFFFF5E00) : const Color(0xFF1A1A1A), fontWeight: index == 0 ? FontWeight.bold : FontWeight.w500)),
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
    if (videos.isEmpty) return const Center(child: Text('No videos found.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: videos.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final video = videos[index];
        return InkWell(
          onTap: () {
            final registry = ref.read(fileHandlerRegistryProvider);
            registry.handlerFor(video)?.open(context, video, ref.read(storageAdapterProvider));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Container(width: 110, height: 70, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(6)), child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 32))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.basename(video.path), style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(children: [const Icon(Icons.folder_outlined, size: 14, color: Color(0xFF8E8E8E)), const SizedBox(width: 4), Expanded(child: Text(p.basename(p.dirname(video.path)), style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)), overflow: TextOverflow.ellipsis))]),
                      const SizedBox(height: 4),
                      Text('${(video.size / 1024 / 1024).toStringAsFixed(1)} MB  •  ${video.modifiedAt.day}/${video.modifiedAt.month}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
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

  Widget _buildPlaylists() {
    return ListView(children: const [Padding(padding: EdgeInsets.all(16.0), child: Text('Playlists not supported yet.', style: TextStyle(color: Colors.grey)))]);
  }
}

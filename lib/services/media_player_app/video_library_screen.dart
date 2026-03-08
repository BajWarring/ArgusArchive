import 'package:flutter/material.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});
  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _folders = [
    {'name': '1DM', 'count': 1},
    {'name': 'All Pictures', 'count': 4},
    {'name': 'All Videos', 'count': 94},
    {'name': 'Camera', 'count': 43},
    {'name': 'Download', 'count': 3},
    {'name': 'ScreenRecorder', 'count': 2},
    {'name': 'VN', 'count': 1},
    {'name': 'Wallpapers', 'count': 2},
    {'name': 'WhatsApp Video', 'count': 6},
  ];
  final List<Map<String, dynamic>> _videos = [
    {'title': 'VID_20260308_1011.mp4', 'duration': '14:20', 'size': '156 MB', 'date': '08 Mar', 'folder': 'Camera'},
    {'title': 'Tears_of_Steel_1080p.mkv', 'duration': '12:14', 'size': '450 MB', 'date': '07 Mar', 'folder': 'Download'},
    {'title': 'Screen_Recording_2026.mp4', 'duration': '02:45', 'size': '24 MB', 'date': '05 Mar', 'folder': 'ScreenRecorder'},
    {'title': 'WhatsApp_Video_1.mp4', 'duration': '00:30', 'size': '5 MB', 'date': '02 Mar', 'folder': 'WhatsApp Video'},
    {'title': 'Big_Buck_Bunny.mp4', 'duration': '09:56', 'size': '210 MB', 'date': '01 Mar', 'folder': 'Download'},
    {'title': 'Elephants_Dream.mp4', 'duration': '10:54', 'size': '320 MB', 'date': '28 Feb', 'folder': 'Download'},
  ];
  final List<Map<String, dynamic>> _playlists = [
    {'name': 'Favorites', 'count': 12, 'icon': Icons.favorite_border},
    {'name': 'Recently Played', 'count': 25, 'icon': Icons.history},
    {'name': 'Watch Later', 'count': 5, 'icon': Icons.watch_later_outlined},
    {'name': 'My Edits', 'count': 3, 'icon': Icons.video_collection_outlined},
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
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
      body: TabBarView(
        controller: _tabController,
        children: [_buildFoldersList(), _buildVideosList(), _buildPlaylists()],
      ),
    );
  }

  Widget _buildFoldersList() {
    return ListView.builder(
      itemCount: _folders.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final isFirst = index == 0; 
        
        return InkWell(
          onTap: () {},
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
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(folder['name'], style: TextStyle(fontSize: 16, color: isFirst ? const Color(0xFFFF5E00) : const Color(0xFF1A1A1A), fontWeight: isFirst ? FontWeight.bold : FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${folder['count']} video${folder['count'] > 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
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

  Widget _buildVideosList() {
    return ListView.builder(
      itemCount: _videos.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final video = _videos[index];
        return InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Container(
                  width: 110, height: 70,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(6)),
                  child: Stack(
                    children: [
                      const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 32)),
                      Positioned(
                        bottom: 4, right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                          child: Text(video['duration'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video['title'], style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 14, color: Color(0xFF8E8E8E)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(video['folder'], style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${video['size']}  •  ${video['date']}', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
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
    return ListView.builder(
      itemCount: _playlists.length + 1, 
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
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0), style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)),
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
        final playlist = _playlists[index - 1];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: const Color(0xFFFFF0E6), borderRadius: BorderRadius.circular(8)),
            child: Icon(playlist['icon'], color: const Color(0xFFFF5E00), size: 28),
          ),
          title: Text(playlist['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          subtitle: Text('${playlist['count']} videos', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          trailing: IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E8E)), onPressed: (){}),
          onTap: () {},
        );
      },
    );
  }
}

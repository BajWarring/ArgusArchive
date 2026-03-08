import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../presentation/debug_ui/search_providers.dart';

class AudioLibraryScreen extends ConsumerStatefulWidget {
  const AudioLibraryScreen({super.key});
  @override
  ConsumerState<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends ConsumerState<AudioLibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<FileEntry>> _fetchAudio() async {
    final db = await ref.read(searchDatabaseProvider.future);
    final results = await db.search(query: '', filterType: FileType.audio);
    final allFiles = await db.search(query: '');
    final fallback = allFiles.where((f) => 
      f.type == FileType.audio || ['mp3','wav','aac','m4a','ogg'].contains(p.extension(f.path).toLowerCase().replaceAll('.',''))
    ).toList();
    return fallback.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Color(0xFF4A4A4A)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFF4A4A4A)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline, color: Color(0xFF4A4A4A)), onPressed: () {}),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFFF5E00),
          unselectedLabelColor: const Color(0xFF6B6B6B),
          indicatorColor: const Color(0xFFFF5E00),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [Tab(text: 'Tracks'), Tab(text: 'Playlists'), Tab(text: 'Albums'), Tab(text: 'Artists'), Tab(text: 'Folders')],
        ),
      ),
      body: FutureBuilder<List<FileEntry>>(
        future: _fetchAudio(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E00)));
          }
          final audios = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTracksList(audios), 
              _buildEmptyState('Playlists not supported yet'), 
              _buildGroupedList(audios, 'Albums', Icons.album), 
              _buildGroupedList(audios, 'Artists', Icons.person), 
              _buildAudioFolders(audios)
            ],
          );
        }
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(8)),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF999999), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 40,
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(8)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.shuffle, color: Colors.black87, size: 18),
                      SizedBox(width: 8),
                      Text('Shuffle All', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracksList(List<FileEntry> audios) {
    if (audios.isEmpty) return const Center(child: Text('No audio files found.'));

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: ListView.builder(
            itemCount: audios.length,
            itemBuilder: (context, index) {
              final audio = audios[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: const Color(0xFF2C3E50), borderRadius: BorderRadius.circular(6)),
                  child: const Center(child: Icon(Icons.music_note, color: Colors.white, size: 24)),
                ),
                title: Text(p.basename(audio.path), style: TextStyle(color: index == 0 ? const Color(0xFFFF5E00) : const Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.basename(p.dirname(audio.path)), style: TextStyle(color: index == 0 ? const Color(0xFFFF5E00) : const Color(0xFF8E8E8E), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF999999)), onPressed: (){}),
                onTap: () {
                  final registry = ref.read(fileHandlerRegistryProvider);
                  registry.handlerFor(audio)?.open(context, audio, ref.read(storageAdapterProvider));
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Dynamic Grouper used for Albums/Artists (Grouping by parent folder name since ID3 tags aren't parsed)
  Widget _buildGroupedList(List<FileEntry> audios, String title, IconData icon) {
    final Map<String, int> groups = {};
    for (var a in audios) {
      final folder = p.basename(p.dirname(a.path));
      groups[folder] = (groups[folder] ?? 0) + 1;
    }
    
    final keys = groups.keys.toList()..sort();

    return ListView.builder(
      itemCount: keys.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final key = keys[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE0E0E0),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          title: Text(key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          subtitle: Text('${groups[key]} tracks', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          onTap: () {},
        );
      },
    );
  }

  Widget _buildAudioFolders(List<FileEntry> audios) {
    final Map<String, int> folderCounts = {};
    for (var a in audios) {
      final dir = p.dirname(a.path);
      folderCounts[dir] = (folderCounts[dir] ?? 0) + 1;
    }
    final paths = folderCounts.keys.toList()..sort();

    return ListView.builder(
      itemCount: paths.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final path = paths[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 65, height: 50,
            decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Icon(Icons.folder, color: Colors.white70)),
          ),
          title: Text(p.basename(path), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          subtitle: Text('${folderCounts[path]} songs', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          trailing: IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF8E8E8E)), onPressed: (){}),
          onTap: () {
            ref.read(currentPathProvider.notifier).state = path;
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) => Center(child: Text(message, style: const TextStyle(color: Colors.grey)));
}

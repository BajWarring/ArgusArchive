import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../../presentation/debug_ui/providers.dart';
import '../../presentation/debug_ui/search_providers.dart';
import '../../providers/media_history_provider.dart';
import '../../presentation/debug_ui/file_thumbnail_debug.dart';
import 'media_folder_detail_screen.dart'; 

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
    final fallback = allFiles.where((f) => ['mp3','wav','aac','m4a','ogg'].contains(p.extension(f.path).toLowerCase().replaceAll('.',''))).toList();
    return {...results, ...fallback}.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // REMOVES BACK BUTTON
        title: const Text('Audio Player', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Color(0xFF4A4A4A)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Color(0xFF4A4A4A)), onPressed: () {}),
        ],
        bottom: TabBar(
          controller: _tabController, 
          isScrollable: true, 
          labelColor: const Color(0xFFFF5E00), 
          unselectedLabelColor: const Color(0xFF6B6B6B), 
          indicatorColor: const Color(0xFFFF5E00), 
          indicatorWeight: 3, 
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13, letterSpacing: 1.2),
          tabs: const [Tab(text: 'Tracks'), Tab(text: 'Playlists'), Tab(text: 'Albums'), Tab(text: 'Artists'), Tab(text: 'Folders')],
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF5E00),
        onRefresh: () async {
          ref.invalidate(searchDatabaseProvider);
          setState(() {});
        },
        child: FutureBuilder<List<FileEntry>>(
          future: _fetchAudio(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5E00)));
            final audios = snapshot.data ?? [];
            return TabBarView(
              controller: _tabController,
              children: [ _buildTracksList(audios), const Center(child: Text('Playlists not supported yet')), _buildGroupedList(audios, 'Albums', Icons.album), _buildGroupedList(audios, 'Artists', Icons.person), _buildAudioFolders(audios) ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildTracksList(List<FileEntry> audios) {
    if (audios.isEmpty) {
      return ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No audio files found.')))]);
    }
    return ListView.builder(
      itemCount: audios.length,
      itemBuilder: (context, index) {
        final audio = audios[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 48, height: 48, 
            decoration: BoxDecoration(color: const Color(0xFF2C3E50), borderRadius: BorderRadius.circular(6)), 
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FileThumbnailDebug(file: audio, adapter: ref.read(storageAdapterProvider), isDirectory: false),
                const Center(child: Icon(Icons.music_note, color: Colors.white70, size: 24)),
              ],
            ),
          ),
          title: Text(p.basename(audio.path), style: TextStyle(color: index == 0 ? const Color(0xFFFF5E00) : const Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(p.basename(p.dirname(audio.path)), style: TextStyle(color: index == 0 ? const Color(0xFFFF5E00) : const Color(0xFF8E8E8E), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            ref.read(mediaHistoryProvider.notifier).save(MediaHistoryItem(path: audio.path, title: p.basename(audio.path), type: 'audio', positionMs: 0, durationMs: 0, lastPlayed: DateTime.now()));
            ref.read(fileHandlerRegistryProvider).handlerFor(audio)?.open(context, audio, ref.read(storageAdapterProvider));
          },
        );
      },
    );
  }

  Widget _buildGroupedList(List<FileEntry> audios, String title, IconData icon) {
    final Map<String, int> groups = {};
    for (var a in audios) {
      groups[p.basename(p.dirname(a.path))] = (groups[p.basename(p.dirname(a.path))] ?? 0) + 1;
    }
    final keys = groups.keys.toList()..sort();
    return ListView.builder(
      itemCount: keys.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final key = keys[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(radius: 28, backgroundColor: const Color(0xFFE0E0E0), child: Icon(icon, size: 32, color: Colors.white)),
          title: Text(key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          subtitle: Text('${groups[key]} tracks', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
        );
      },
    );
  }

  Widget _buildAudioFolders(List<FileEntry> audios) {
    final Map<String, int> folderCounts = {};
    for (var a in audios) {
      folderCounts[p.dirname(a.path)] = (folderCounts[p.dirname(a.path)] ?? 0) + 1;
    }
    final paths = folderCounts.keys.toList()..sort();

    return ListView.builder(
      itemCount: paths.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final path = paths[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(width: 65, height: 50, decoration: BoxDecoration(color: const Color(0xFFE5E5E5), borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.folder, color: Colors.white70))),
          title: Text(p.basename(path), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          subtitle: Text('${folderCounts[path]} songs', style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaFolderDetailScreen(folderPath: path, isVideo: false))),
        );
      },
    );
  }
}

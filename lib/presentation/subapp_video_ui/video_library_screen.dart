import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui_theme.dart';
import 'views/video_grid_view.dart';
import 'views/browse_view.dart';
import 'views/video_settings_view.dart';

enum VideoTab { grid, browse, settings }

class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen> {
  VideoTab _currentTab = VideoTab.grid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTab == VideoTab.grid ? 'Video Library' : 
          _currentTab == VideoTab.browse ? 'Browse Videos' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (_currentTab != VideoTab.settings)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => setState(() => _currentTab = VideoTab.settings),
            )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (idx) => setState(() => _currentTab = VideoTab.values[idx]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view), label: 'Grid'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'Browse'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case VideoTab.grid: return const VideoGridView();
      case VideoTab.browse: return const BrowseView();
      case VideoTab.settings: return const VideoSettingsView();
    }
  }
}

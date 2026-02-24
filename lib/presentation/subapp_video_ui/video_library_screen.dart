import 'package:flutter/material.dart';
import '../ui_theme.dart';
import 'views/video_grid_view.dart';
import 'views/browse_view.dart';
import 'views/explorer_view.dart';
import 'widgets/video_bottom_nav.dart';

enum VideoTab { video, browse, explorer, settings }

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  VideoTab _currentTab = VideoTab.video;
  VideoTab _previousTab = VideoTab.video;

  void _switchTab(VideoTab tab) {
    setState(() {
      _previousTab = _currentTab;
      _currentTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showNav = _currentTab == VideoTab.video || _currentTab == VideoTab.browse;

    return Scaffold(
      backgroundColor: isDark ? ArgusColors.bgDark : ArgusColors.bgLight,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
          if (showNav)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: VideoBottomNav(
                currentTab: _currentTab,
                onTabSelected: _switchTab,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (_currentTab == VideoTab.explorer || _currentTab == VideoTab.settings) ...[
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _switchTab(_previousTab)),
                const SizedBox(width: 4),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTab == VideoTab.settings ? 'Settings' : (_currentTab == VideoTab.explorer ? 'Internal Storage' : 'Argus'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  Text(
                    _currentTab == VideoTab.settings ? 'Player Preferences' : 'VIDEO PLAYER',
                    style: TextStyle(fontSize: 11, color: _currentTab == VideoTab.settings ? Colors.grey : ArgusColors.primary, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
          if (_currentTab != VideoTab.settings)
            Row(
              children: [
                IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
                IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _switchTab(VideoTab.settings)),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case VideoTab.video: return const VideoGridView();
      case VideoTab.browse: return BrowseView(onOpenExplorer: () => _switchTab(VideoTab.explorer));
      case VideoTab.explorer: return const VideoExplorerView();
      case VideoTab.settings: return const Center(child: Text("Settings Stub"));
    }
  }
}

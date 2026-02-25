import 'package:flutter/material.dart';
import '../ui_theme.dart';
import 'views/video_grid_view.dart';
import 'views/browse_view.dart';
import 'views/explorer_view.dart';
import 'views/video_settings_view.dart';
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

  // REAL DATA: Path Tracking for the Video Explorer
  String _currentPath = '/storage/emulated/0';
  final List<String> _pathStack = ['/storage/emulated/0'];

  void _switchTab(VideoTab tab) {
    setState(() {
      _previousTab = _currentTab;
      _currentTab = tab;
    });
  }

  void _openFolder(String path) {
    setState(() {
      _currentPath = path;
      if (_pathStack.isEmpty || _pathStack.last != path) {
        _pathStack.add(path);
      }
      _currentTab = VideoTab.explorer;
    });
  }

  void _handleHardwareBack() {
    if (_currentTab == VideoTab.explorer) {
      if (_pathStack.length > 1) {
        setState(() {
          _pathStack.removeLast();
          _currentPath = _pathStack.last;
        });
      } else {
        _switchTab(VideoTab.browse);
      }
    } else if (_currentTab == VideoTab.settings) {
      _switchTab(_previousTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showNav = _currentTab == VideoTab.video || _currentTab == VideoTab.browse;

    return PopScope(
      canPop: _currentTab == VideoTab.video || _currentTab == VideoTab.browse,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _handleHardwareBack(); },
      child: Scaffold(
        backgroundColor: isDark ? ArgusColors.bgDark : ArgusColors.bgLight,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildBody()),
                ],
              ),
              if (showNav)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: VideoBottomNav(currentTab: _currentTab, onTabSelected: _switchTab),
                ),
            ],
          ),
        ),
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
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleHardwareBack),
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
      case VideoTab.browse: return BrowseView(onOpenExplorer: _openFolder);
      case VideoTab.explorer: return VideoExplorerView(currentPath: _currentPath, onFolderEnter: _openFolder);
      case VideoTab.settings: return const VideoSettingsView();
    }
  }
}

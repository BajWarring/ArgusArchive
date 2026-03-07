import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../ui_theme.dart';
import 'views/video_grid_view.dart';
import 'views/browse_view.dart';
import 'views/explorer_view.dart';
import 'views/video_settings_view.dart';
import '../../core/enums/file_type.dart';
import '../../core/models/file_entry.dart';
import '../debug_ui/search_providers.dart';
import '../debug_ui/providers.dart';
import '../../services/operations/video_thumbnail_service.dart';

enum VideoTab { videos, browse, explorer, settings }

class VideoLibraryScreen extends ConsumerStatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  ConsumerState<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends ConsumerState<VideoLibraryScreen>
    with TickerProviderStateMixin {
  VideoTab _currentTab = VideoTab.videos;
  VideoTab _previousTab = VideoTab.videos;

  String _currentPath = '/storage/emulated/0';
  final List<String> _pathStack = ['/storage/emulated/0'];

  // Search
  bool _searchActive = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _switchTab(VideoTab tab) {
    if (tab == _currentTab) return;
    setState(() { _previousTab = _currentTab; _currentTab = tab; });
    if (_searchActive) _closeSearch();
  }

  void _openFolder(String path) {
    setState(() {
      _currentPath = path;
      if (_pathStack.isEmpty || _pathStack.last != path) {
        _pathStack.add(path);
      }
      _currentTab = VideoTab.explorer;
      ref.read(currentPathProvider.notifier).state = path;
    });
  }

  void _handleBack() {
    if (_searchActive) { _closeSearch(); return; }
    if (_currentTab == VideoTab.explorer) {
      if (_pathStack.length > 1) {
        _pathStack.removeLast();
        final prev = _pathStack.last;
        setState(() => _currentPath = prev);
        ref.read(currentPathProvider.notifier).state = prev;
      } else {
        _switchTab(VideoTab.browse);
      }
    } else if (_currentTab == VideoTab.settings) {
      _switchTab(_previousTab);
    }
  }

  void _closeSearch() {
    setState(() { _searchActive = false; });
    _searchCtrl.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _searchFocus.unfocus();
  }

  void _openSearch() {
    setState(() => _searchActive = true);
    Future.delayed(const Duration(milliseconds: 50), () => _searchFocus.requestFocus());
  }

  bool get _canPop =>
      _currentTab == VideoTab.videos ||
      (_currentTab == VideoTab.browse && _pathStack.length <= 1);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ArgusColors.bgDark : ArgusColors.bgLight;
    final showBottomNav = _currentTab == VideoTab.videos || _currentTab == VideoTab.browse;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _handleBack(); },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(child: _buildBody()),
                ],
              ),
              // Bottom nav (floating over content)
              if (showBottomNav)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: _BottomNav(current: _currentTab, onSelect: _switchTab, isDark: isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    if (_searchActive) return _buildSearchHeader(isDark);

    final isInExplorer = _currentTab == VideoTab.explorer;
    final isInSettings = _currentTab == VideoTab.settings;
    final needsBack = isInExplorer || isInSettings;

    String title;
    String subtitle;
    if (isInSettings) {
      title = 'Settings';
      subtitle = 'Player Preferences';
    } else if (isInExplorer) {
      title = p.basename(_currentPath).isEmpty ? 'Storage' : p.basename(_currentPath);
      subtitle = _currentPath.replaceFirst('/storage/emulated/0', 'Internal');
    } else if (_currentTab == VideoTab.browse) {
      title = 'Browse';
      subtitle = 'Storage & Folders';
    } else {
      title = 'Videos';
      subtitle = 'All Videos';
    }

    return Container(
      color: isDark ? ArgusColors.bgDark : ArgusColors.bgLight,
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          if (needsBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: _handleBack,
            )
          else
            const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : ArgusColors.textDark,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: _currentTab == VideoTab.videos ? ArgusColors.primary : Colors.grey,
                      fontWeight: _currentTab == VideoTab.videos ? FontWeight.w700 : FontWeight.normal,
                      letterSpacing: _currentTab == VideoTab.videos ? 0.8 : 0,
                    )),
              ],
            ),
          ),

          // Search icon (not in settings)
          if (!isInSettings)
            IconButton(
              icon: const Icon(Icons.search, size: 22),
              onPressed: _openSearch,
            ),

          // Settings gear (not in settings)
          if (!isInSettings)
            IconButton(
              icon: Icon(
                Icons.settings_outlined,
                size: 22,
                color: _currentTab == VideoTab.settings ? ArgusColors.primary : null,
              ),
              onPressed: () => _switchTab(VideoTab.settings),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      color: isDark ? ArgusColors.surfaceDark : Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Search videos…',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_searchActive) return _buildSearchResults();

    switch (_currentTab) {
      case VideoTab.videos:    return const VideoGridView();
      case VideoTab.browse:    return BrowseView(onOpenExplorer: _openFolder);
      case VideoTab.explorer:  return VideoExplorerView(currentPath: _currentPath, onFolderEnter: _openFolder);
      case VideoTab.settings:  return const VideoSettingsView();
    }
  }

  Widget _buildSearchResults() {
    final query = ref.watch(searchQueryProvider);
    final dbAsync = ref.watch(searchDatabaseProvider);

    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('Type to search videos', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return dbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ArgusColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (db) {
        return FutureBuilder(
          future: db.search(query: query, filterType: FileType.video),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: ArgusColors.primary));
            }
            final results = snap.data ?? [];
            if (results.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('No videos found for "$query"',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: results.length,
              itemBuilder: (_, i) => _VideoListTileSearch(
                video: results[i],
                query: query,
                ref: ref,
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Bottom Navigation Bar ────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final VideoTab current;
  final void Function(VideoTab) onSelect;
  final bool isDark;

  const _BottomNav({required this.current, required this.onSelect, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: (isDark ? ArgusColors.surfaceDark : Colors.white).withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavItem(icon: Icons.movie_outlined, activeIcon: Icons.movie, label: 'Videos', tab: VideoTab.videos, current: current, onSelect: onSelect),
          _NavItem(icon: Icons.folder_outlined, activeIcon: Icons.folder, label: 'Browse', tab: VideoTab.browse, current: current, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VideoTab tab;
  final VideoTab current;
  final void Function(VideoTab) onSelect;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.tab,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == tab;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? ArgusColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? ArgusColors.primary : Colors.grey,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isActive ? ArgusColors.primary : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Search result tile ───────────────────────────────────────────────────────
class _VideoListTileSearch extends StatelessWidget {
  final FileEntry video;
  final String query;
  final WidgetRef ref;

  const _VideoListTileSearch({required this.video, required this.query, required this.ref});

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
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80, height: 50,
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
                        return const Center(child: Icon(Icons.movie, color: Colors.white24, size: 24));
                      },
                    ),
                    const Center(child: Icon(Icons.play_arrow, color: Colors.white60, size: 18)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HighlightText(
                    text: p.basenameWithoutExtension(video.path),
                    query: query,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtBytes(video.size)}  •  ${video.path}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText({required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    if (!lower.contains(lowerQ)) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

    final start = lower.indexOf(lowerQ);
    final end = start + lowerQ.length;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(color: ArgusColors.primary, fontWeight: FontWeight.bold),
        ),
        TextSpan(text: text.substring(end)),
      ]),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _fmtBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/explorer_provider.dart';
import '../widgets/file_tile.dart';
import '../widgets/breadcrumb_bar.dart';
import '../../viewer/thumbnail/services/thumbnail_visibility.dart';
import '../../viewer/thumbnail/services/thumbnail_queue.dart';

class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});

  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends ConsumerState<ExplorerScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final first = (_scrollController.offset / 70).floor();
    final last = first + 15; // approx visible count at 70px tile height
    ThumbnailVisibility.firstVisible = first;
    ThumbnailVisibility.lastVisible = last;

    // Cancel thumbnail tasks that have scrolled far off-screen
    ThumbnailQueue.refreshPriorities((task) {
      return ThumbnailVisibility.isNearVisible(task.index);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(explorerProvider);
    final notifier = ref.read(explorerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadFiles(),
          ),
        ],
      ),
      body: Column(
        children: [
          BreadcrumbBar(path: notifier.currentPath),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: ElevatedButton(
                      onPressed: () => notifier.loadFiles(),
                      child: const Text('Load Files'),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      return FileTile(
                        file: files[index],
                        index: index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

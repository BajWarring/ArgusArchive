
import 'package:collection/collection.dart';

class ThumbnailTask {
  final String path;
  final int index;
  int priority;

  ThumbnailTask(this.path, this.index, this.priority);
}

class ThumbnailQueue {
  static final PriorityQueue<ThumbnailTask> _queue =
      PriorityQueue((a, b) => b.priority.compareTo(a.priority));
  static final Set<String> _activePaths = {};

  /// Adjustable by PerfController
  static int maxConcurrent = 2;
  static int _running = 0;
  static Future<void> Function(ThumbnailTask)? _lastProcessor;

  static void add(
    ThumbnailTask task,
    Future<void> Function(ThumbnailTask) processor,
  ) {
    _lastProcessor = processor;
    _queue.add(task);
    _process(processor);
  }

  static void _process(Future<void> Function(ThumbnailTask) processor) {
    while (_queue.isNotEmpty && _running < maxConcurrent) {
      final task = _queue.removeFirst();
      if (_activePaths.contains(task.path)) continue;
      _running++;
      _activePaths.add(task.path);
      processor(task).whenComplete(() {
        _running--;
        _activePaths.remove(task.path);
        _process(processor);
      });
    }
  }

  /// Remove queued tasks for items no longer near the viewport.
  static void refreshPriorities(bool Function(ThumbnailTask) shouldKeep) {
  final kept = _queue.toList().where(shouldKeep).toList();
  _queue.clear();
  for (final task in kept) {
    _queue.add(task);
  }
}

  /// Called by PerfController to tune concurrency at runtime
  static void setConcurrency(int v) {
    maxConcurrent = v;
    if (_lastProcessor != null) _process(_lastProcessor!);
  }

  /// Used by PerfMonitor to measure queue pressure
  static int get length => _queue.length;
}

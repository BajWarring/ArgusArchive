import 'thumbnail_cache.dart';
import 'thumbnail_visibility.dart';
import '../isolate/isolate_pool.dart';
import '../isolate/isolate_task.dart';

class ThumbnailService {
  /// Maps file path → active task ID for deduplication + cancellation
  static final Map<String, String> _activeTasks = {};

  static Future<String?> getThumbnail(String path, int index) async {
    final key = path.hashCode.toString();

    // 1. Serve from cache if available
    final cached = await ThumbnailCache.get(key);
    if (cached != null) return cached.path;

    // 2. Skip items far off-screen
    final priority = ThumbnailVisibility.getPriority(index);
    if (priority == 0) return null;

    // 3. Cancel any stale task for the same path
    if (_activeTasks.containsKey(path)) {
      IsolatePool.cancel(_activeTasks[path]!);
    }

    // 4. Enqueue new task in the isolate pool
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeTasks[path] = taskId;

    IsolatePool.process(
      IsolateTask(
        id: taskId,
        path: path,
        onDone: (bytes) async {
          _activeTasks.remove(path);
          if (bytes == null) return;
          await ThumbnailCache.save(key, bytes);
        },
      ),
    );

    return null;
  }

  /// Cancel a pending/running task for [path] (called on widget dispose)
  static void cancel(String path) {
    final taskId = _activeTasks.remove(path);
    if (taskId != null) IsolatePool.cancel(taskId);
  }
}

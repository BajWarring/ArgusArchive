import 'dart:typed_data';
import 'isolate_task.dart';
import 'isolate_worker.dart';

/// Load-balanced isolate pool.
/// Distributes thumbnail tasks across multiple workers.
/// Supports runtime resizing via [resize] (called by PerfController).
class IsolatePool {
  static final List<Worker> _workers = [];
  static final Map<String, Worker> _taskMap = {};
  static final Map<String, Function(Uint8List?)> _callbacks = {};

  /// Initialise the pool with [size] workers.
  static Future<void> init({int size = 2}) async {
    for (int i = 0; i < size; i++) {
      final worker = Worker();
      await worker.init();
      worker.receivePort.listen(_handleMessage(worker));
      _workers.add(worker);
    }
  }

  static Function(dynamic) _handleMessage(Worker worker) {
    return (msg) {
      if (msg is! Map) return;
      final id = msg['id'] as String;
      final bytes = msg['bytes'] as Uint8List?;
      worker.activeTasks--;
      final callback = _callbacks.remove(id);
      _taskMap.remove(id);
      callback?.call(bytes);
    };
  }

  /// Pick the least-busy worker
  static Worker _getWorker() {
    _workers.sort((a, b) => a.activeTasks.compareTo(b.activeTasks));
    return _workers.first;
  }

  /// Dispatch a task to the pool
  static void process(IsolateTask task) {
    if (_workers.isEmpty) return;
    final worker = _getWorker();
    worker.activeTasks++;
    _taskMap[task.id] = worker;
    _callbacks[task.id] = task.onDone;
    worker.sendPort.send({
      'task': true,
      'id': task.id,
      'path': task.path,
    });
  }

  /// Cooperatively cancel a queued/running task
  static void cancel(String taskId) {
    final worker = _taskMap[taskId];
    if (worker == null) return;
    worker.sendPort.send({'cancel': true, 'id': taskId});
    _callbacks.remove(taskId);
    _taskMap.remove(taskId);
  }

  /// Current number of workers (read by PerfController)
  static int get size => _workers.length;

  /// Total active tasks across all workers (read by PerfMonitor)
  static int get activeTasks =>
      _workers.fold(0, (sum, w) => sum + w.activeTasks);

  /// Grow or shrink the pool at runtime (called by PerfController)
  static Future<void> resize(int newSize) async {
    if (newSize == _workers.length) return;
    if (newSize > _workers.length) {
      final toAdd = newSize - _workers.length;
      for (int i = 0; i < toAdd; i++) {
        final w = Worker();
        await w.init();
        w.receivePort.listen(_handleMessage(w));
        _workers.add(w);
      }
    } else {
      final toRemove = _workers.length - newSize;
      for (int i = 0; i < toRemove; i++) {
        final w = _workers.removeLast();
        w.dispose();
      }
    }
  }

  static void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    _workers.clear();
  }
}

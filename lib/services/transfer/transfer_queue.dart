import 'dart:async';
import 'transfer_task.dart';
import 'transfer_worker.dart';
import '../../core/interfaces/storage_adapter.dart';

/// Orchestrates multiple TransferTasks, managing concurrency and queue state.
class TransferQueue {
  final Map<String, TransferTask> _tasks = {};
  final Map<String, TransferWorker> _activeWorkers = {};
  final int maxConcurrent;

  // Broadcasts the entire queue state to listeners (UI/State Management)
  final _queueController = StreamController<List<TransferTask>>.broadcast();
  Stream<List<TransferTask>> get queueStream => _queueController.stream;

  TransferQueue({this.maxConcurrent = 2});

  /// Adds a new task to the queue and attempts to process it.
  void enqueue(TransferTask task, StorageAdapter source, StorageAdapter dest) {
    _tasks[task.id] = task;
    _broadcast();
    
    final worker = TransferWorker(
      sourceAdapter: source,
      destAdapter: dest,
      onProgress: _updateTaskState,
      onComplete: (t) {
        _updateTaskState(t);
        _activeWorkers.remove(t.id);
        _processQueue(); // Start next task
      },
      onError: (t, e) {
        _updateTaskState(t);
        _activeWorkers.remove(t.id);
        _processQueue();
      },
    );

    _activeWorkers[task.id] = worker;
    _processQueue();
  }

  /// Processes pending tasks up to the concurrency limit.
  void _processQueue() {
    final inProgressCount = _tasks.values.where((t) => t.status == TransferStatus.inProgress).length;
    
    if (inProgressCount >= maxConcurrent) return;

    final pendingTasks = _tasks.values.where((t) => t.status == TransferStatus.pending);
    
    for (var task in pendingTasks.take(maxConcurrent - inProgressCount)) {
      _activeWorkers[task.id]?.execute(task);
    }
  }

  void _updateTaskState(TransferTask updatedTask) {
    _tasks[updatedTask.id] = updatedTask;
    _broadcast();
  }

  void pause(String taskId) {
    _activeWorkers[taskId]?.pause();
    _updateTaskState(_tasks[taskId]!.copyWith(status: TransferStatus.paused));
  }

  void resume(String taskId) {
    _activeWorkers[taskId]?.resume();
    _updateTaskState(_tasks[taskId]!.copyWith(status: TransferStatus.inProgress));
  }

  void cancel(String taskId) async {
    await _activeWorkers[taskId]?.cancel(_tasks[taskId]!);
    _activeWorkers.remove(taskId);
    _processQueue();
  }

  void _broadcast() {
    _queueController.add(_tasks.values.toList());
  }

  void dispose() {
    _queueController.close();
  }
}

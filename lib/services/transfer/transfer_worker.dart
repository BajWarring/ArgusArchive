import 'dart:async';
import '../../core/interfaces/storage_adapter.dart';
import 'transfer_task.dart';

/// Worker that executes a TransferTask using a pair of StorageAdapters.
class TransferWorker {
  final StorageAdapter sourceAdapter;
  final StorageAdapter destAdapter;
  
  // Callbacks to notify the TransferQueue/UI of progress
  final void Function(TransferTask) onProgress;
  final void Function(TransferTask) onComplete;
  final void Function(TransferTask, Exception) onError;

  StreamSubscription<List<int>>? _subscription;
  bool _isPaused = false;
  bool _isCancelled = false;

  TransferWorker({
    required this.sourceAdapter,
    required this.destAdapter,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  /// Starts or resumes the transfer task.
  Future<void> execute(TransferTask task) async {
    _isPaused = false;
    _isCancelled = false;
    
    // 1. Reserve destination path with a .part marker
    final partPath = '${task.destPath}.part';
    
    try {
      // Notify starting state
      onProgress(task.copyWith(status: TransferStatus.inProgress));

      // 2. Open streams (resume from transferredBytes if applicable)
      final sourceStream = await sourceAdapter.openRead(
        task.sourcePath, 
        start: task.transferredBytes,
      );
      
      final destSink = await destAdapter.openWrite(
        partPath, 
        append: task.transferredBytes > 0,
      );

      int currentBytes = task.transferredBytes;

      // 3. Stream data and handle chunking
      _subscription = sourceStream.listen(
        (chunk) {
          if (_isPaused || _isCancelled) {
            _subscription?.pause();
            return;
          }

          destSink.add(chunk);
          currentBytes += chunk.length;

          // Note: In a production app, throttle this callback to avoid UI stutter
          onProgress(task.copyWith(
            transferredBytes: currentBytes,
            status: TransferStatus.inProgress,
          ));
        },
        onError: (e) async {
          await _handleFailure(task, destSink, Exception(e.toString()));
        },
        onDone: () async {
          if (_isCancelled) return; // Handled by cancel()
          
          await destSink.close();
          
          // 4. On success, atomically rename .part to final name
          await destAdapter.move(partPath, task.destPath);
          
          onComplete(task.copyWith(
            transferredBytes: currentBytes,
            status: TransferStatus.completed,
          ));
        },
        cancelOnError: true,
      );
    } catch (e) {
      await _handleFailure(task, null, Exception(e.toString()));
    }
  }

  Future<void> _handleFailure(TransferTask task, StreamSink<List<int>>? sink, Exception e) async {
    await sink?.close();
    
    if (task.retryCount < task.maxRetries) {
      // Retry policy hook could go here (e.g., exponential backoff)
      onError(task.copyWith(
        status: TransferStatus.failed, 
        retryCount: task.retryCount + 1,
        errorMessage: e.toString(),
      ), e);
    } else {
      // Max retries reached, mark as hard failure
      onError(task.copyWith(
        status: TransferStatus.failed,
        errorMessage: 'Max retries reached: ${e.toString()}'
      ), e);
    }
  }

  /// Pauses the current transfer without closing the worker.
  void pause() {
    _isPaused = true;
    _subscription?.pause();
  }

  /// Resumes a paused transfer.
  void resume() {
    _isPaused = false;
    _subscription?.resume();
  }

  /// Cancels the transfer and cleans up the partial file.
  Future<void> cancel(TransferTask task) async {
    _isCancelled = true;
    await _subscription?.cancel();
    
    // Cleanup the .part file
    final partPath = '${task.destPath}.part';
    try {
      await destAdapter.delete(partPath);
    } catch (_) {
      // Ignore cleanup errors on cancel
    }
    
    onProgress(task.copyWith(status: TransferStatus.cancelled));
  }
}

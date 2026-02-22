import 'dart:async';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/utils/path_utils.dart';
import 'transfer_task.dart';

class TransferWorker {
  final StorageAdapter sourceAdapter;
  final StorageAdapter destAdapter;
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

  Future<void> execute(TransferTask task) async {
    _isPaused = false;
    _isCancelled = false;

    try {
      onProgress(task.copyWith(status: TransferStatus.inProgress));

      switch (task.operation) {
        case TransferOperation.copy:
        case TransferOperation.move:
          await _handleTransfer(task);
          break;
        case TransferOperation.delete:
          await _handleDelete(task);
          break;
        case TransferOperation.compress:
          await _handleCompress(task);
          break;
        case TransferOperation.extract:
          await _handleExtract(task);
          break;
      }
    } catch (e) {
      await _handleFailure(task, null, Exception(e.toString()));
    }
  }

  Future<void> _handleTransfer(TransferTask task) async {
    final partPath = '${task.destPath}.part';
    final sourceStream = await sourceAdapter.openRead(task.sourcePath, start: task.transferredBytes);
    final destSink = await destAdapter.openWrite(partPath, append: task.transferredBytes > 0);

    int currentBytes = task.transferredBytes;

    _subscription = sourceStream.listen(
      (chunk) {
        if (_isPaused || _isCancelled) {
          _subscription?.pause();
          return;
        }
        destSink.add(chunk);
        currentBytes += chunk.length;
        onProgress(task.copyWith(transferredBytes: currentBytes, status: TransferStatus.inProgress));
      },
      onError: (e) async => await _handleFailure(task, destSink, Exception(e.toString())),
      onDone: () async {
        if (_isCancelled) return;
        await destSink.close();
        
        await destAdapter.move(partPath, task.destPath);
        if (task.operation == TransferOperation.move) {
          await sourceAdapter.delete(task.sourcePath);
        }
        
        onComplete(task.copyWith(transferredBytes: currentBytes, status: TransferStatus.completed));
      },
      cancelOnError: true,
    );
  }

  Future<void> _handleDelete(TransferTask task) async {
    await sourceAdapter.delete(task.sourcePath);
    onComplete(task.copyWith(transferredBytes: task.totalBytes, status: TransferStatus.completed));
  }

  Future<void> _handleCompress(TransferTask task) async {
    final stream = await sourceAdapter.openRead(task.sourcePath);
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    
    final archive = Archive();
    final fileName = PathUtils.getName(task.sourcePath);
    archive.addFile(ArchiveFile(fileName, builder.length, builder.toBytes()));

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception("Failed to compress");

    final sink = await destAdapter.openWrite(task.destPath);
    sink.add(zipBytes);
    await sink.close();

    onComplete(task.copyWith(transferredBytes: task.totalBytes, status: TransferStatus.completed));
  }

  Future<void> _handleExtract(TransferTask task) async {
    final stream = await sourceAdapter.openRead(task.sourcePath);
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }

    final archive = ZipDecoder().decodeBytes(builder.toBytes());
    
    for (final file in archive) {
      if (file.isFile) {
        final outPath = PathUtils.join(task.destPath, file.name);
        final sink = await destAdapter.openWrite(outPath);
        sink.add(file.content as List<int>);
        await sink.close();
      }
    }
    onComplete(task.copyWith(transferredBytes: task.totalBytes, status: TransferStatus.completed));
  }

  Future<void> _handleFailure(TransferTask task, StreamSink<List<int>>? sink, Exception e) async {
    await sink?.close();
    if (task.retryCount < task.maxRetries) {
      onError(task.copyWith(status: TransferStatus.failed, retryCount: task.retryCount + 1, errorMessage: e.toString()), e);
    } else {
      onError(task.copyWith(status: TransferStatus.failed, errorMessage: 'Max retries reached: ${e.toString()}'), e);
    }
  }

  void pause() {
    _isPaused = true;
    _subscription?.pause();
  }

  void resume() {
    _isPaused = false;
    _subscription?.resume();
  }

  Future<void> cancel(TransferTask task) async {
    _isCancelled = true;
    await _subscription?.cancel();
    if (task.operation == TransferOperation.copy || task.operation == TransferOperation.move) {
      try { await destAdapter.delete('${task.destPath}.part'); } catch (_) {}
    }
    onProgress(task.copyWith(status: TransferStatus.cancelled));
  }
}

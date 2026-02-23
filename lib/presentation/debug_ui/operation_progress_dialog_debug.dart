import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../services/transfer/transfer_task.dart';
import 'providers.dart';

class OperationProgressDialogDebug extends ConsumerStatefulWidget {
  final List<String> taskIds;

  const OperationProgressDialogDebug({
    super.key,
    required this.taskIds,
  });

  static Future<void> show(BuildContext context, List<String> taskIds) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OperationProgressDialogDebug(taskIds: taskIds),
    );
  }

  @override
  ConsumerState<OperationProgressDialogDebug> createState() => _OperationProgressDialogDebugState();
}

class _OperationProgressDialogDebugState extends ConsumerState<OperationProgressDialogDebug> {
  
  String _getOperationName(TransferOperation operation) {
    switch (operation) {
      case TransferOperation.copy: return 'Copying';
      case TransferOperation.move: return 'Moving';
      case TransferOperation.extract: return 'Extracting';
      case TransferOperation.compress: return 'Compressing';
      case TransferOperation.delete: return 'Deleting';
    }
  }

  IconData _getOperationIcon(TransferOperation operation) {
    switch (operation) {
      case TransferOperation.copy: return Icons.copy;
      case TransferOperation.move: return Icons.drive_file_move;
      case TransferOperation.extract: return Icons.unarchive;
      case TransferOperation.compress: return Icons.folder_zip;
      case TransferOperation.delete: return Icons.delete;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(queueTasksStreamProvider);

    return tasksAsync.when(
      loading: () => const AlertDialog(content: SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))),
      error: (err, stack) => AlertDialog(content: Text('Error: $err')),
      data: (allTasks) {
        // Filter the global queue to only show tasks relevant to this dialog's batch
        final myTasks = allTasks.where((t) => widget.taskIds.contains(t.id)).toList();

        if (myTasks.isEmpty) {
          return const AlertDialog(content: Text('Initializing...'));
        }

        // Check if the entire batch is finished
        final isComplete = myTasks.every((t) => 
            t.status == TransferStatus.completed || 
            t.status == TransferStatus.cancelled || 
            t.status == TransferStatus.failed);

        // Auto-close and refresh when done
        if (isComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
              ref.invalidate(directoryContentsProvider);
            }
          });
        }

        // Find the active task for the filename display
        final activeTask = myTasks.firstWhere(
          (t) => t.status == TransferStatus.inProgress,
          orElse: () => myTasks.firstWhere((t) => t.status == TransferStatus.pending, orElse: () => myTasks.last)
        );

        // Calculate cumulative progress for the batch
        final totalBytes = myTasks.fold<int>(0, (sum, t) => sum + t.totalBytes);
        final transferredBytes = myTasks.fold<int>(0, (sum, t) => sum + t.transferredBytes);
        final overallProgress = totalBytes == 0 ? 0.0 : transferredBytes / totalBytes;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Icon(_getOperationIcon(activeTask.operation), color: Colors.teal),
              const SizedBox(width: 8),
              Text('${_getOperationName(activeTask.operation)}...'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.basename(activeTask.sourcePath),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: overallProgress,
                backgroundColor: Colors.teal.withValues(alpha: 0.2),
                color: activeTask.status == TransferStatus.failed ? Colors.red : Colors.teal,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${myTasks.where((t) => t.status == TransferStatus.completed).length} / ${myTasks.length} files'),
                  Text('${(overallProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ],
          ),
          actions: [
            if (!isComplete)
              TextButton(
                onPressed: () {
                  // Cancel all tasks in this batch
                  final queue = ref.read(transferQueueProvider);
                  for (var task in myTasks) {
                    if (task.status == TransferStatus.pending || task.status == TransferStatus.inProgress) {
                      queue.cancel(task.id);
                    }
                  }
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              ),
          ],
        );
      }
    );
  }
}

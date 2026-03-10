import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../services/transfer/transfer_task.dart';
import '../debug_ui/providers.dart';
import 'operation_popup_card.dart';

class TransferQueuePopup extends ConsumerWidget {
  final List<String> taskIds;

  const TransferQueuePopup({super.key, required this.taskIds});

  static Future<void> show(BuildContext context, List<String> taskIds) {
    return showDialog(
      context: context,
      barrierColor: Colors.black45,
      barrierDismissible: false,
      builder: (context) => Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Material(
            color: Colors.transparent,
            child: TransferQueuePopup(taskIds: taskIds),
          ),
        ),
      ),
    );
  }

  String _getOperationName(TransferOperation operation) {
    switch (operation) {
      case TransferOperation.copy: return 'Copying';
      case TransferOperation.move: return 'Moving';
      case TransferOperation.extract: return 'Extracting';
      case TransferOperation.compress: return 'Compressing';
      case TransferOperation.delete: return 'Deleting';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(queueTasksStreamProvider);

    return tasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
      data: (allTasks) {
        final myTasks = allTasks.where((t) => taskIds.contains(t.id)).toList();
        if (myTasks.isEmpty) return const SizedBox.shrink();

        final isComplete = myTasks.every((t) => t.status == TransferStatus.completed || t.status == TransferStatus.cancelled || t.status == TransferStatus.failed);
        
        if (isComplete) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pop();
              ref.invalidate(directoryContentsProvider);
            }
          });
        }

        final activeTask = myTasks.firstWhere(
          (t) => t.status == TransferStatus.inProgress,
          orElse: () => myTasks.firstWhere((t) => t.status == TransferStatus.pending, orElse: () => myTasks.last)
        );

        final totalBytes = myTasks.fold<int>(0, (sum, t) => sum + t.totalBytes);
        final transferredBytes = myTasks.fold<int>(0, (sum, t) => sum + t.transferredBytes);
        final overallProgress = totalBytes == 0 ? 0.0 : transferredBytes / totalBytes;
        
        final completedItems = myTasks.where((t) => t.status == TransferStatus.completed).length;
        final mbTransferred = (transferredBytes / (1024 * 1024)).toStringAsFixed(1);
        final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        bool isCanceled = activeTask.status == TransferStatus.cancelled;

        return OperationPopupCard(
          title: isCanceled ? "Canceled" : _getOperationName(activeTask.operation),
          destination: "To: ${p.dirname(activeTask.destPath)}",
          currentFile: p.basename(activeTask.sourcePath),
          progress: overallProgress,
          currentItems: completedItems,
          totalItems: myTasks.length,
          speedText: "$mbTransferred / $mbTotal MB",
          isAnimating: !isComplete && !isCanceled && activeTask.status == TransferStatus.inProgress,
          isCanceled: isCanceled,
          onHide: () => Navigator.of(context).pop(),
          onCancel: () {
            final queue = ref.read(transferQueueProvider);
            for (var task in myTasks) queue.cancel(task.id);
          },
        );
      }
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/path_utils.dart';
import '../../services/transfer/transfer_task.dart';
import 'providers.dart';

class TransferDebugScreen extends ConsumerWidget {
  const TransferDebugScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(queueTasksStreamProvider);
    final queue = ref.read(transferQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Tasks'),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: Text('No active tasks in queue.')),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('Queue is empty.', style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${task.operation.name.toUpperCase()} - ${PathUtils.getName(task.sourcePath)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(task.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: task.totalBytes > 0 ? task.progress : null,
                        backgroundColor: Colors.grey[800],
                        color: task.status == TransferStatus.failed ? Colors.red : Colors.blueAccent,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            task.totalBytes > 0 
                                ? '${(task.transferredBytes / 1024 / 1024).toStringAsFixed(2)} MB / ${(task.totalBytes / 1024 / 1024).toStringAsFixed(2)} MB'
                                : 'Calculating...',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          _buildActionButtons(task, queue),
                        ],
                      ),
                      if (task.errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Error: ${task.errorMessage}',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(TransferStatus status) {
    Color color;
    switch (status) {
      case TransferStatus.inProgress: color = Colors.blue; break;
      case TransferStatus.completed: color = Colors.green; break;
      case TransferStatus.failed: color = Colors.red; break;
      case TransferStatus.paused: color = Colors.orange; break;
      case TransferStatus.cancelled: color = Colors.grey; break;
      case TransferStatus.pending: color = Colors.teal; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(status.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtons(TransferTask task, dynamic queue) {
    if (task.status == TransferStatus.completed || task.status == TransferStatus.cancelled) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (task.status == TransferStatus.inProgress)
          IconButton(
            icon: const Icon(Icons.pause, size: 20),
            onPressed: () => queue.pause(task.id),
          ),
        if (task.status == TransferStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            onPressed: () => queue.resume(task.id),
          ),
        IconButton(
          icon: const Icon(Icons.cancel, size: 20, color: Colors.redAccent),
          onPressed: () => queue.cancel(task.id),
        ),
      ],
    );
  }
}

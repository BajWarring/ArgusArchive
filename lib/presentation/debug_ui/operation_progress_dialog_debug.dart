import 'package:flutter/material.dart';

enum OperationType { copy, move, extract, compress }

class OperationProgressDialogDebug extends StatelessWidget {
  final OperationType operation;
  final String currentFile;
  final double progress; // 0.0 to 1.0

  const OperationProgressDialogDebug({
    super.key,
    required this.operation,
    required this.currentFile,
    required this.progress,
  });

  String get _operationName {
    switch (operation) {
      case OperationType.copy: return 'Copying';
      case OperationType.move: return 'Moving';
      case OperationType.extract: return 'Extracting';
      case OperationType.compress: return 'Compressing';
    }
  }

  IconData get _operationIcon {
    switch (operation) {
      case OperationType.copy: return Icons.copy;
      case OperationType.move: return Icons.drive_file_move;
      case OperationType.extract: return Icons.unarchive;
      case OperationType.compress: return Icons.folder_zip;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(_operationIcon, color: Colors.teal),
          const SizedBox(width: 8),
          Text('$_operationName...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentFile,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.teal.withvalues(alpha: 0.2),
            color: Colors.teal,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(progress * 100).toStringAsFixed(1)}%'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // TODO: Add cancellation logic
            Navigator.of(context).pop();
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // Helper method to easily show this dialog
  static Future<void> show(BuildContext context, OperationType operation, ValueNotifier<double> progressNotifier, ValueNotifier<String> currentFileNotifier) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            return ValueListenableBuilder<String>(
              valueListenable: currentFileNotifier,
              builder: (context, currentFile, _) {
                return OperationProgressDialogDebug(
                  operation: operation,
                  currentFile: currentFile,
                  progress: progress,
                );
              }
            );
          }
        );
      }
    );
  }
}

/// Represents the current state of a transfer task.
enum TransferStatus { pending, inProgress, paused, completed, failed, cancelled }

/// The type of operation this task represents.
enum TransferOperation { copy, move, delete, compress, extract }

/// Immutable domain object representing a single background operation.
class TransferTask {
  final String id;
  final String sourcePath;
  final String destPath;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final TransferOperation operation;
  final int retryCount;
  final int maxRetries;
  final String? errorMessage;

  const TransferTask({
    required this.id,
    required this.sourcePath,
    required this.destPath,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.operation = TransferOperation.copy,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.errorMessage,
  });

  /// Calculates progress as a percentage (0.0 to 1.0)
  double get progress => totalBytes == 0 ? 0 : transferredBytes / totalBytes;

  TransferTask copyWith({
    int? transferredBytes,
    TransferStatus? status,
    int? retryCount,
    String? errorMessage,
  }) {
    return TransferTask(
      id: id,
      sourcePath: sourcePath,
      destPath: destPath,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      operation: operation,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Represents the current state of a transfer task.
enum TransferStatus { pending, inProgress, paused, completed, failed, cancelled }

/// Immutable domain object representing a single file transfer operation.
class TransferTask {
  final String id;
  final String sourcePath;
  final String destPath;
  final int totalBytes;
  final int transferredBytes;
  final TransferStatus status;
  final int retryCount;
  final int maxRetries;
  final bool useChecksum;
  final String? errorMessage;

  const TransferTask({
    required this.id,
    required this.sourcePath,
    required this.destPath,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.useChecksum = true,
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
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries,
      useChecksum: useChecksum,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

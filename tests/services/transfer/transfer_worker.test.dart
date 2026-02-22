import 'package:test/test.dart';
import '../../../lib/adapters/mock/mock_storage_adapter.dart';
import '../../../lib/services/transfer/transfer_task.dart';
import '../../../lib/services/transfer/transfer_worker.dart';

void main() {
  group('TransferWorker Tests', () {
    late MockStorageAdapter sourceAdapter;
    late MockStorageAdapter destAdapter;

    setUp(() {
      sourceAdapter = MockStorageAdapter();
      destAdapter = MockStorageAdapter();
    });

    test('Successfully transfers a file and renames .part to final', () async {
      // 1. Arrange: Seed a 5-byte file in the source adapter
      final sourcePath = '/src/file.txt';
      final destPath = '/dst/file.txt';
      final fileData = [1, 2, 3, 4, 5];
      sourceAdapter.seedFile(sourcePath, fileData);

      final task = TransferTask(
        id: 'task_1',
        sourcePath: sourcePath,
        destPath: destPath,
        totalBytes: fileData.length,
      );

      TransferTask? finalState;

      final worker = TransferWorker(
        sourceAdapter: sourceAdapter,
        destAdapter: destAdapter,
        onProgress: (_) {}, // Ignore intermediate progress
        onComplete: (completedTask) {
          finalState = completedTask;
        },
        onError: (_, __) {
          fail('Transfer should not fail');
        },
      );

      // 2. Act
      await worker.execute(task);

      // 3. Assert
      expect(finalState, isNotNull);
      expect(finalState!.status, equals(TransferStatus.completed));
      expect(finalState!.transferredBytes, equals(5));

      // Ensure the file exists at destination and contents match
      expect(destAdapter.exists(destPath), isTrue);
      expect(destAdapter.getBytes(destPath), equals(fileData));

      // Ensure the temporary .part file was cleaned up/renamed
      expect(destAdapter.exists('$destPath.part'), isFalse);
    });

    test('Cancels a transfer and cleans up the .part file', () async {
      // 1. Arrange
      final sourcePath = '/src/big_file.txt';
      final destPath = '/dst/big_file.txt';
      sourceAdapter.seedFile(sourcePath, List.filled(1000, 0)); // 1000 bytes

      final task = TransferTask(
        id: 'task_2',
        sourcePath: sourcePath,
        destPath: destPath,
        totalBytes: 1000,
      );

      bool wasCancelled = false;

      final worker = TransferWorker(
        sourceAdapter: sourceAdapter,
        destAdapter: destAdapter,
        onProgress: (t) {
          if (t.status == TransferStatus.cancelled) {
            wasCancelled = true;
          }
        },
        onComplete: (_) => fail('Should not complete'),
        onError: (_, __) => fail('Should not error'),
      );

      // 2. Act
      // Start the transfer, but don't await it yet
      final future = worker.execute(task);
      
      // Cancel immediately
      await worker.cancel(task);
      await future; 

      // 3. Assert
      expect(wasCancelled, isTrue);
      expect(destAdapter.exists(destPath), isFalse, reason: 'Final file should not exist');
      expect(destAdapter.exists('$destPath.part'), isFalse, reason: 'Part file should be deleted on cancel');
    });
  });
}

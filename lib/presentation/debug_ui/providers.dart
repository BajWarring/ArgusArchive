import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';

/// 1. Make the adapter a StateProvider so we can swap it to a ZIP adapter at runtime
final storageAdapterProvider = StateProvider<StorageAdapter>((ref) {
  return LocalStorageAdapter();
});

/// 2. Track the "real" parent path so we know where to go back to when exiting a ZIP
final realParentPathProvider = StateProvider<String?>((ref) => null);

/// 3. Current path inside whatever adapter is active
final currentPathProvider = StateProvider<String>((ref) {
  return '/storage/emulated/0/Download'; // Default Android path for testing
});

/// 4. Asynchronously loads the directory contents
final directoryContentsProvider = FutureProvider.autoDispose<List<FileEntry>>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final path = ref.watch(currentPathProvider);
  
  try {
    return await adapter.list(path);
  } catch (e) {
    throw Exception('Failed to read directory: $e');
  }
});

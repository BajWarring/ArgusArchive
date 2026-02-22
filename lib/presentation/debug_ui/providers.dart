import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';

/// Provides the default storage adapter (Local for now, could be SAF on Android later)
final storageAdapterProvider = Provider<StorageAdapter>((ref) {
  return LocalStorageAdapter();
});

/// Manages the current directory path being viewed
final currentPathProvider = StateProvider<String>((ref) {
  // Default to a safe starting directory for testing
  return '/storage/emulated/0/Download'; // Standard Android path for testing
});

/// Asynchronously loads the directory contents whenever the path changes
final directoryContentsProvider = FutureProvider.autoDispose<List<FileEntry>>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final path = ref.watch(currentPathProvider);
  
  try {
    return await adapter.list(path);
  } catch (e) {
    // If permission denied or not found, return an empty list or throw
    throw Exception('Failed to read directory: $e');
  }
});

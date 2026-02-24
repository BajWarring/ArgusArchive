import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../features/file_handlers/file_handler_registry.dart';
import '../../features/file_handlers/image_handler.dart';
import '../../features/file_handlers/text_handler.dart';
import '../../features/file_handlers/svg_handler.dart';
import '../../features/file_handlers/pdf_handler.dart';
import '../../features/file_handlers/video_handler.dart';
import '../../services/indexer/index_service.dart';
import '../../services/transfer/transfer_queue.dart';
import '../../services/transfer/transfer_task.dart';
import '../../features/file_handlers/video_handler.dart';
import 'search_providers.dart'; // To access searchDatabaseProvider

// 1. Make the adapter a StateProvider so we can swap it to a ZIP adapter at runtime
final storageAdapterProvider = StateProvider<StorageAdapter>((ref) {
  return LocalStorageAdapter();
});

// 2. Track the "real" parent path so we know where to go back to when exiting a ZIP
final realParentPathProvider = StateProvider<String?>((ref) => null);

// 3. Current path inside whatever adapter is active
final currentPathProvider = StateProvider<String>((ref) {
  return '/storage/emulated/0'; // Internal Storage/Device Storage
});

// 4. Asynchronously loads the directory contents
final directoryContentsProvider = FutureProvider.autoDispose<List<FileEntry>>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final path = ref.watch(currentPathProvider);
  
  try {
    return await adapter.list(path);
  } catch (e) {
    throw Exception('Failed to read directory: $e');
  }
});

// 5. Global registry for handling different file types when tapped
final fileHandlerRegistryProvider = Provider<FileHandlerRegistry>((ref) {
  final registry = FileHandlerRegistry();
  
  registry.register(ImageHandler());
  registry.register(SvgHandler());
  registry.register(PdfHandler());
  registry.register(TextHandler());
  registry.register(VideoHandler());
  
  return registry;
});

// 6. Index Service Initialization (Now uses SearchDatabase!)
final indexServiceProvider = FutureProvider<IndexService>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final db = await ref.watch(searchDatabaseProvider.future);
  final service = IndexService(adapter: adapter, searchDb: db);
  
  // Kick off the auto-start in the background automatically
  service.autoStart('/storage/emulated/0');
  
  return service;
});


// 7. Global Transfer Queue Singleton
final transferQueueProvider = Provider<TransferQueue>((ref) {
  final queue = TransferQueue(maxConcurrent: 2);
  
  ref.onDispose(() {
    queue.dispose();
  });
  
  return queue;
});

// 8. Live stream of queue tasks for the UI
final queueTasksStreamProvider = StreamProvider<List<TransferTask>>((ref) {
  final queue = ref.watch(transferQueueProvider);
  return queue.queueStream;
});

// ==========================================
// FILE OPERATIONS STATE
// ==========================================

enum ClipboardAction { copy, cut, extract, none }

class ClipboardState {
  final List<String> paths;
  final ClipboardAction action;

  ClipboardState({this.paths = const [], this.action = ClipboardAction.none});
}

// 9. Holds the files the user currently has selected to move/copy.
final clipboardProvider = StateProvider<ClipboardState>((ref) {
  return ClipboardState();
});

// 10. Tracks which files the user has check-marked in the current folder
final selectedFilesProvider = StateProvider<Set<String>>((ref) => {});

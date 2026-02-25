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
import 'search_providers.dart'; 
import '../../services/storage/storage_volumes_service.dart';

final storageAdapterProvider = StateProvider<StorageAdapter>((ref) {
  return LocalStorageAdapter();
});

final realParentPathProvider = StateProvider<String?>((ref) => null);

final currentPathProvider = StateProvider<String>((ref) {
  return '/storage/emulated/0'; 
});

final directoryContentsProvider = FutureProvider.autoDispose<List<FileEntry>>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final path = ref.watch(currentPathProvider);
  
  try {
    return await adapter.list(path);
  } catch (e) {
    throw Exception('Failed to read directory: $e');
  }
});

final fileHandlerRegistryProvider = Provider<FileHandlerRegistry>((ref) {
  final registry = FileHandlerRegistry();
  
  registry.register(ImageHandler());
  registry.register(SvgHandler());
  registry.register(PdfHandler());
  registry.register(TextHandler());
  registry.register(VideoHandler());
  
  return registry;
});

final indexServiceProvider = FutureProvider<IndexService>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final db = await ref.watch(searchDatabaseProvider.future);
  final service = IndexService(adapter: adapter, searchDb: db);
  
  final roots = await StorageVolumesService.getStorageRoots();
  service.autoStart(roots);
  
  return service;
});

final transferQueueProvider = Provider<TransferQueue>((ref) {
  final queue = TransferQueue(maxConcurrent: 2);
  ref.onDispose(() { queue.dispose(); });
  return queue;
});

final queueTasksStreamProvider = StreamProvider<List<TransferTask>>((ref) {
  final queue = ref.watch(transferQueueProvider);
  return queue.queueStream;
});

enum ClipboardAction { copy, cut, extract, none }

class ClipboardState {
  final List<String> paths;
  final ClipboardAction action;
  ClipboardState({this.paths = const [], this.action = ClipboardAction.none});
}

final clipboardProvider = StateProvider<ClipboardState>((ref) {
  return ClipboardState();
});

final selectedFilesProvider = StateProvider<Set<String>>((ref) => {});

// ==========================================
// NEW: Global UI Mode Toggle (Safely placed here!)
// ==========================================
final useDebugUiProvider = StateProvider<bool>((ref) => false);

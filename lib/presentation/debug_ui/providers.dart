import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../adapters/local/local_storage_adapter.dart';
import '../../core/interfaces/storage_adapter.dart';
import '../../core/models/file_entry.dart';
import '../../features/file_handlers/file_handler_registry.dart';
import '../../features/file_handlers/image_handler.dart';
import '../../features/file_handlers/text_handler.dart';
import '../../features/file_handlers/svg_handler.dart';
import '../../features/file_handlers/pdf_handler.dart';

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

/// 5. Global registry for handling different file types when tapped
final fileHandlerRegistryProvider = Provider<FileHandlerRegistry>((ref) {
  final registry = FileHandlerRegistry();
  
  // Handlers registered first have priority.
  registry.register(ImageHandler());
  registry.register(SvgHandler());
  registry.register(PdfHandler());
  registry.register(TextHandler());
  
  return registry;
});

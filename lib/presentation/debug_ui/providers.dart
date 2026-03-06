import 'dart:io';
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
import '../../services/storage/bookmarks_service.dart';
import '../../services/storage/trash_service.dart';
import 'search_providers.dart';
import '../../services/storage/storage_volumes_service.dart';

// ─── STORAGE & NAVIGATION ────────────────────────────────────────────────────
final storageAdapterProvider = StateProvider<StorageAdapter>((ref) => LocalStorageAdapter());
final realParentPathProvider = StateProvider<String?>((ref) => null);
final currentPathProvider = StateProvider<String>((ref) => '/storage/emulated/0');

// ─── SETTINGS ─────────────────────────────────────────────────────────────────
final showHiddenFilesProvider = StateProvider<bool>((ref) => false);
final useGridViewProvider = StateProvider<bool>((ref) => false);
final useDebugUiProvider = StateProvider<bool>((ref) => false);

// ─── DIRECTORY CONTENTS ───────────────────────────────────────────────────────
final directoryContentsProvider = FutureProvider.autoDispose<List<FileEntry>>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final path = ref.watch(currentPathProvider);
  final showHidden = ref.watch(showHiddenFilesProvider);

  try {
    final all = await adapter.list(path);
    if (showHidden) return all;
    return all.where((e) => !e.path.split('/').last.startsWith('.')).toList();
  } catch (e) {
    throw Exception('Failed to read directory: $e');
  }
});

// ─── FOLDER SIZE ──────────────────────────────────────────────────────────────
final folderSizeProvider = FutureProvider.autoDispose.family<int, String>((ref, dirPath) async {
  int total = 0;
  try {
    await for (final entity in Directory(dirPath).list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final stat = await entity.stat();
        total += stat.size;
      }
    }
  } catch (_) {}
  return total;
});

// ─── FILE HANDLERS ────────────────────────────────────────────────────────────
final fileHandlerRegistryProvider = Provider<FileHandlerRegistry>((ref) {
  final registry = FileHandlerRegistry();
  registry.register(ImageHandler());
  registry.register(SvgHandler());
  registry.register(PdfHandler());
  registry.register(TextHandler());
  registry.register(VideoHandler());
  return registry;
});

// ─── INDEXER ──────────────────────────────────────────────────────────────────
final indexServiceProvider = FutureProvider<IndexService>((ref) async {
  final adapter = ref.watch(storageAdapterProvider);
  final db = await ref.watch(searchDatabaseProvider.future);
  final service = IndexService(adapter: adapter, searchDb: db);
  final roots = await StorageVolumesService.getStorageRoots();
  service.autoStart(roots);
  return service;
});

// ─── TRANSFER QUEUE ───────────────────────────────────────────────────────────
final transferQueueProvider = Provider<TransferQueue>((ref) {
  final queue = TransferQueue(maxConcurrent: 2);
  ref.onDispose(() { queue.dispose(); });
  return queue;
});

final queueTasksStreamProvider = StreamProvider<List<TransferTask>>((ref) {
  final queue = ref.watch(transferQueueProvider);
  return queue.queueStream;
});

// ─── CLIPBOARD ────────────────────────────────────────────────────────────────
enum ClipboardAction { copy, cut, extract, none }

class ClipboardState {
  final List<String> paths;
  final ClipboardAction action;
  ClipboardState({this.paths = const [], this.action = ClipboardAction.none});
}

final clipboardProvider = StateProvider<ClipboardState>((ref) => ClipboardState());
final selectedFilesProvider = StateProvider<Set<String>>((ref) => {});

// ─── BOOKMARKS ────────────────────────────────────────────────────────────────
final bookmarksProvider = FutureProvider.autoDispose<List<BookmarkEntry>>((ref) async {
  await BookmarksService.init();
  return BookmarksService.getAll();
});

// ─── TRASH ────────────────────────────────────────────────────────────────────
final trashItemsProvider = FutureProvider.autoDispose<List<TrashItem>>((ref) async {
  await TrashService.init();
  return TrashService.getItems();
});

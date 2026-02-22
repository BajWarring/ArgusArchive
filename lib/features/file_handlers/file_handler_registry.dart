import '../../core/models/file_entry.dart';
import 'file_handler.dart';

/// Central registry mapping file types/extensions to their implementations.
class FileHandlerRegistry {
  final List<FileHandler> _handlers = [];

  /// Registers a new handler into the pipeline.
  /// Handlers registered first have higher priority.
  void register(FileHandler handler) {
    if (!_handlers.contains(handler)) {
      _handlers.add(handler);
    }
  }

  /// Finds the first capable handler for a given file.
  FileHandler? handlerFor(FileEntry entry) {
    for (final handler in _handlers) {
      if (handler.canHandle(entry)) {
        return handler;
      }
    }
    return null; // Return null if no registered handler supports this file
  }

  /// Removes a handler from the registry.
  void unregister(FileHandler handler) {
    _handlers.remove(handler);
  }
}

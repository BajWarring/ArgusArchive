import 'package:flutter/material.dart';
import '../../core/models/file_entry.dart';
import '../../core/interfaces/storage_adapter.dart';

/// The abstract contract for any file type handler in the system.
abstract class FileHandler {
  /// Evaluates whether this handler knows how to process the given file.
  bool canHandle(FileEntry entry);

  /// Generates a lightweight preview widget (e.g., a thumbnail or snippet) for UI lists.
  Widget buildPreview(FileEntry entry, StorageAdapter adapter);

  /// Executes the primary 'open' action (e.g., launching a fullscreen viewer, audio player, or external intent).
  Future<void> open(BuildContext context, FileEntry entry, StorageAdapter adapter);
}

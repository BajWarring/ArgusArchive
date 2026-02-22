import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';
import 'providers.dart';

class SearchDebugScreen extends ConsumerWidget {
  const SearchDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final registry = ref.watch(fileHandlerRegistryProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search files instantly...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              ref.read(searchQueryProvider.notifier).state = '';
            },
          )
        ],
      ),
      body: searchResultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (results) {
          final query = ref.read(searchQueryProvider);
          if (query.isEmpty) {
            return const Center(child: Text('Type to search indexed files', style: TextStyle(color: Colors.grey)));
          }

          if (results.isEmpty) {
            return const Center(child: Text('No files found. Did you build the index?', style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final file = results[index];
              return ListTile(
                leading: Icon(
                  file.isDirectory ? Icons.folder : _getIconForType(file.type),
                  color: file.isDirectory ? Colors.amber : Colors.blueGrey,
                ),
                title: Text(PathUtils.getName(file.path)),
                subtitle: Text(file.path, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  if (!file.isDirectory) {
                    final handler = registry.handlerFor(file);
                    if (handler != null) {
                      handler.open(context, file, currentAdapter);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No handler found for: ${PathUtils.getName(file.path)}')),
                      );
                    }
                  } else {
                    ref.read(currentPathProvider.notifier).state = file.path;
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(FileType type) {
    switch (type) {
      case FileType.image: return Icons.image;
      case FileType.video: return Icons.movie;
      case FileType.audio: return Icons.audiotrack;
      case FileType.document: return Icons.description;
      case FileType.archive: return Icons.archive;
      default: return Icons.insert_drive_file;
    }
  }
}

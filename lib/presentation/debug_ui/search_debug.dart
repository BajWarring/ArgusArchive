import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/enums/file_type.dart';
import '../../core/utils/path_utils.dart';
import 'providers.dart';
import 'search_providers.dart';

class SearchDebugScreen extends ConsumerWidget {
  const SearchDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResultsAsync = ref.watch(liveSearchResultsProvider);
    final registry = ref.watch(fileHandlerRegistryProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);
    final activeFilter = ref.watch(searchTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'FTS5 Instant Search...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              ref.read(searchQueryProvider.notifier).state = '';
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(ref, 'All', null, activeFilter),
                _buildFilterChip(ref, 'Images', FileType.image, activeFilter),
                _buildFilterChip(ref, 'Videos', FileType.video, activeFilter),
                _buildFilterChip(ref, 'Documents', FileType.document, activeFilter),
                _buildFilterChip(ref, 'Archives', FileType.archive, activeFilter),
              ],
            ),
          ),
        ),
      ),
      body: searchResultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (results) {
          final query = ref.read(searchQueryProvider);
          if (query.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('Type to search indexed files', style: TextStyle(color: Colors.grey)),
                ],
              )
            );
          }

          if (results.isEmpty) {
            return const Center(child: Text('No files found matching your criteria.', style: TextStyle(color: Colors.grey)));
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
                // Highlight the matching text natively
                title: _buildHighlightedText(p.basename(file.path), query),
                subtitle: Text(file.path, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  if (!file.isDirectory) {
                    final handler = registry.handlerFor(file);
                    if (handler != null) {
                      handler.open(context, file, currentAdapter);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No handler found for: ${p.basename(file.path)}')));
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

  Widget _buildFilterChip(WidgetRef ref, String label, FileType? type, FileType? active) {
    final isSelected = active == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
        selected: isSelected,
        selectedColor: Colors.teal,
        backgroundColor: Colors.white10,
        onSelected: (_) => ref.read(searchTypeFilterProvider.notifier).state = type,
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);
    
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    
    if (!lowerText.contains(lowerQuery)) return Text(text);

    final startIndex = lowerText.indexOf(lowerQuery);
    final endIndex = startIndex + lowerQuery.length;

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
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

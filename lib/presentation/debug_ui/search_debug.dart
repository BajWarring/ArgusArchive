import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/enums/file_type.dart';
import 'providers.dart';
import 'search_providers.dart';

class SearchDebugScreen extends ConsumerStatefulWidget {
  const SearchDebugScreen({super.key});
  @override
  ConsumerState<SearchDebugScreen> createState() => _SearchDebugScreenState();
}

class _SearchDebugScreenState extends ConsumerState<SearchDebugScreen> {
  bool _showFilters = false;
  int? _minSizeKB;
  int? _maxSizeKB;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(liveSearchResultsProvider);
    final registry = ref.watch(fileHandlerRegistryProvider);
    final currentAdapter = ref.watch(storageAdapterProvider);
    final activeFilter = ref.watch(searchTypeFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Search files...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white54)),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
        ),
        actions: [
          IconButton(icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined, color: _showFilters ? Colors.tealAccent : Colors.white), onPressed: () => setState(() => _showFilters = !_showFilters)),
          IconButton(icon: const Icon(Icons.clear), onPressed: () => ref.read(searchQueryProvider.notifier).state = ''),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 120 : 52),
          child: Column(
            children: [
              // TYPE FILTER CHIPS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  _chip(ref, 'All', null, activeFilter),
                  _chip(ref, '🖼 Images', FileType.image, activeFilter),
                  _chip(ref, '🎬 Videos', FileType.video, activeFilter),
                  _chip(ref, '📄 Docs', FileType.document, activeFilter),
                  _chip(ref, '🗜 Archives', FileType.archive, activeFilter),
                  _chip(ref, '🎵 Audio', FileType.audio, activeFilter),
                ]),
              ),

              // ADVANCED FILTERS
              if (_showFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Min size (KB)', isDense: true, border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        onChanged: (v) => setState(() => _minSizeKB = int.tryParse(v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Max size (KB)', isDense: true, border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        onChanged: (v) => setState(() => _maxSizeKB = int.tryParse(v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(_dateRange == null ? 'Date' : '${_dateRange!.start.day}/${_dateRange!.start.month}', style: const TextStyle(fontSize: 11)),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          initialDateRange: _dateRange,
                        );
                        if (range != null) setState(() => _dateRange = range);
                      },
                    ),
                    if (_dateRange != null)
                      IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _dateRange = null)),
                  ]),
                ),
            ],
          ),
        ),
      ),
      body: searchResultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (results) {
          final query = ref.read(searchQueryProvider);
          if (query.isEmpty) {
            return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.search, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('Type to search indexed files', style: TextStyle(color: Colors.grey)),
            ]));
          }

          // Apply client-side size + date filters
          var filtered = results.where((f) {
            if (_minSizeKB != null && f.size < _minSizeKB! * 1024) return false;
            if (_maxSizeKB != null && f.size > _maxSizeKB! * 1024) return false;
            if (_dateRange != null) {
              if (f.modifiedAt.isBefore(_dateRange!.start) || f.modifiedAt.isAfter(_dateRange!.end.add(const Duration(days: 1)))) return false;
            }
            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.search_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('No results for "$query"', style: const TextStyle(color: Colors.grey)),
              if (_minSizeKB != null || _maxSizeKB != null || _dateRange != null)
                TextButton(
                  onPressed: () => setState(() { _minSizeKB = null; _maxSizeKB = null; _dateRange = null; }),
                  child: const Text('Clear Filters'),
                ),
            ]));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${filtered.length} results', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (_minSizeKB != null || _maxSizeKB != null || _dateRange != null)
                      TextButton(onPressed: () => setState(() { _minSizeKB = null; _maxSizeKB = null; _dateRange = null; }), child: const Text('Clear Filters', style: TextStyle(fontSize: 11))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final file = filtered[index];
                    final sizeStr = file.size < 1048576 ? '${(file.size / 1024).toStringAsFixed(1)} KB' : '${(file.size / 1048576).toStringAsFixed(1)} MB';
                    return ListTile(
                      leading: Icon(file.isDirectory ? Icons.folder : _iconForType(file.type), color: file.isDirectory ? Colors.amber : Colors.blueGrey),
                      title: _buildHighlight(p.basename(file.path), query),
                      subtitle: Text('${file.path}\n$sizeStr • ${file.modifiedAt.day}/${file.modifiedAt.month}/${file.modifiedAt.year}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      isThreeLine: true,
                      onTap: () {
                        if (!file.isDirectory) {
                          final handler = registry.handlerFor(file);
                          if (handler != null) {
                            handler.open(context, file, currentAdapter);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No handler for: ${p.extension(file.path)}')));
                          }
                        } else {
                          ref.read(currentPathProvider.notifier).state = file.path;
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(WidgetRef ref, String label, FileType? type, FileType? active) {
    final isSelected = active == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
        selected: isSelected,
        selectedColor: Colors.teal,
        backgroundColor: Colors.white10,
        onSelected: (_) => ref.read(searchTypeFilterProvider.notifier).state = type,
      ),
    );
  }

  Widget _buildHighlight(String text, String query) {
    if (query.isEmpty) return Text(text);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    if (!lower.contains(lowerQ)) return Text(text);
    final start = lower.indexOf(lowerQ);
    final end = start + lowerQ.length;
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(text: text.substring(start, end), style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }

  IconData _iconForType(FileType type) {
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

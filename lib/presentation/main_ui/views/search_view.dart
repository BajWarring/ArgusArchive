import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../ui_theme.dart';
import '../../../core/models/file_entry.dart';
import '../../../core/enums/file_type.dart';
import '../../debug_ui/search_providers.dart';
import '../../debug_ui/providers.dart';

class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  String _activeFilter = 'All';
  String _searchQuery = '';
  final List<String> _filters = ['All', 'Documents', 'Videos', 'Images', 'Archives', 'Directories'];

  FileType? _getFilterType() {
    switch (_activeFilter) {
      case 'Documents': return FileType.document;
      case 'Videos': return FileType.video;
      case 'Images': return FileType.image;
      case 'Archives': return FileType.archive;
      case 'Directories': return FileType.dir;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fake search bar to capture input since the real one is in the header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            autofocus: true,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Type to search...',
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark ? ArgusColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        _buildFilterChips(context),
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isActive = _activeFilter == filter;
          
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? ArgusColors.primary : (Theme.of(context).brightness == Brightness.dark ? ArgusColors.surfaceDark.withValues(alpha: 0.6) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? ArgusColors.primary : Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(filter, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade600)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    final dbAsync = ref.watch(searchDatabaseProvider);

    return dbAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
      data: (db) {
        return FutureBuilder<List<FileEntry>>(
          future: db.search(query: _searchQuery, filterType: _getFilterType()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final results = snapshot.data ?? [];
            if (results.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    const Text('No results found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final file = results[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: ArgusColors.primary.withValues(alpha: 0.1),
                    child: Icon(file.isDirectory ? Icons.folder : Icons.insert_drive_file, color: ArgusColors.primary),
                  ),
                  title: Text(p.basename(file.path), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(file.path, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  onTap: () async {
                    if (!file.isDirectory) {
                       final handlers = ref.read(fileHandlerRegistryProvider);
                       final adapter = ref.read(storageAdapterProvider);
                       for (var h in handlers) {
                         if (h.canHandle(file)) { h.open(context, file, adapter); break; }
                       }
                    }
                  },
                );
              },
            );
          }
        );
      }
    );
  }
}

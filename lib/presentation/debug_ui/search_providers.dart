import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/file_entry.dart';
import '../../core/enums/file_type.dart';
import '../../data/db/search_database.dart';

final searchDatabaseProvider = FutureProvider<SearchDatabase>((ref) async {
  final db = SearchDatabase();
  await db.init();
  return db;
});

final searchTypeFilterProvider = StateProvider<FileType?>((ref) => null);
final searchQueryProvider = StateProvider<String>((ref) => '');

// Debounced Search Engine Provider
final liveSearchResultsProvider = FutureProvider.autoDispose<List<FileEntry>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchTypeFilterProvider);
  
  if (query.trim().isEmpty) return [];

  // 300ms Debounce to prevent UI freezing while typing
  await Future.delayed(const Duration(milliseconds: 300));
  if (ref.state is AsyncLoading) {
    // Optional: Cancel logic could go here if implemented
  }

  final db = await ref.watch(searchDatabaseProvider.future);
  return await db.search(query: query, filterType: filter);
});

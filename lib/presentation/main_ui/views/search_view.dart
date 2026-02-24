import 'package:flutter/material.dart';
import '../../ui_theme.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Documents', 'Videos', 'Images', 'APKs', 'Directories'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
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
                border: Border.all(
                  color: isActive ? ArgusColors.primary : Colors.grey.withValues(alpha: 0.3),
                ),
                boxShadow: isActive ? [BoxShadow(color: ArgusColors.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))] : [],
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    // Stub for empty search state to match HTML
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
}

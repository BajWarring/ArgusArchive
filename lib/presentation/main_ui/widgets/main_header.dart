import 'package:flutter/material.dart';
import '../../ui_theme.dart';
import '../main_screen.dart';

class MainHeader extends StatelessWidget {
  final MainView currentView;
  final bool isSelectionMode;
  final int selectionCount;
  final VoidCallback onBack;
  final VoidCallback onSearchTap;
  final VoidCallback onCloseSearch;
  final VoidCallback onToggleSelection;

  const MainHeader({
    super.key, required this.currentView, required this.isSelectionMode,
    required this.selectionCount, required this.onBack, required this.onSearchTap,
    required this.onCloseSearch, required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelectionMode && currentView != MainView.search) {
      return _buildSelectionHeader(context);
    } else if (currentView == MainView.search) {
      return _buildSearchHeader(context);
    }
    return _buildNormalHeader(context);
  }

  Widget _buildNormalHeader(BuildContext context) {
    final isHome = currentView == MainView.home;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isHome) ...[
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
                const SizedBox(width: 4),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentView == MainView.settings ? 'Settings' : 'Argus',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  Text(
                    currentView == MainView.settings ? 'App Preferences' : (isHome ? 'Dashboard' : '/Internal Storage/Downloads'),
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          if (currentView != MainView.settings)
            Row(
              children: [
                IconButton(icon: const Icon(Icons.search), onPressed: onSearchTap),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.close), onPressed: onToggleSelection),
              Text('$selectionCount Selected', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.checklist, color: ArgusColors.primary), onPressed: () {}),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: onCloseSearch),
          Expanded(
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search files...',
                filled: true,
                fillColor: isDark ? ArgusColors.surfaceDark.withValues(alpha: 0.8) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: const Icon(Icons.close, size: 20),
              ),
            ),
          )
        ],
      ),
    );
  }
}

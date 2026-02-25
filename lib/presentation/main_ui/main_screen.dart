import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../ui_theme.dart';
import '../../presentation/debug_ui/providers.dart'; // Wires to original logic
import 'views/home_view.dart';
import 'views/browser_view.dart';
import 'views/search_view.dart';
import 'views/settings_view.dart';
import 'widgets/main_header.dart';
import 'widgets/operation_bar.dart';

enum MainView { home, browser, search, settings }

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  MainView _currentView = MainView.home;

  void _navigateTo(MainView view) {
    setState(() => _currentView = view);
  }

  void _handleHardwareBack() {
    final selectedFiles = ref.read(selectedFilesProvider);
    if (selectedFiles.isNotEmpty) {
      ref.read(selectedFilesProvider.notifier).state = {}; // Clear selection
      return;
    }
    
    if (_currentView == MainView.search || _currentView == MainView.settings) {
      _navigateTo(MainView.home);
      return;
    }
    
    if (_currentView == MainView.browser) {
      final currentPath = ref.read(currentPathProvider);
      if (currentPath == '/storage/emulated/0' || currentPath == '/') {
        _navigateTo(MainView.home);
      } else {
        ref.read(currentPathProvider.notifier).state = p.dirname(currentPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // REAL DATA: Listen to selection state natively
    final selectedFiles = ref.watch(selectedFilesProvider);
    final isSelectionMode = selectedFiles.isNotEmpty;
    
    // REAL DATA: Listen to clipboard for the Paste Bar
    final clipboard = ref.watch(clipboardProvider);
    final showOperationBar = clipboard.action != ClipboardAction.none && !isSelectionMode && _currentView == MainView.browser;

    return PopScope(
      canPop: _currentView == MainView.home && !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _handleHardwareBack(); },
      child: Scaffold(
        backgroundColor: isDark ? ArgusColors.bgDark : ArgusColors.bgLight,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  MainHeader(
                    currentView: _currentView,
                    isSelectionMode: isSelectionMode,
                    selectionCount: selectedFiles.length,
                    onBack: _handleHardwareBack,
                    onSearchTap: () => _navigateTo(MainView.search),
                    onCloseSearch: () => _navigateTo(MainView.home),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildCurrentView(),
                    ),
                  ),
                ],
              ),
              if (showOperationBar)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: OperationBar(
                    operationTitle: clipboard.action.name,
                    itemName: '${clipboard.paths.length} items',
                    icon: clipboard.action == ClipboardAction.cut ? Icons.content_cut : Icons.content_copy,
                    onCancel: () => ref.read(clipboardProvider.notifier).state = ClipboardState(),
                    onPaste: () {
                      // REAL DATA: Uses your existing debug_ui logic to paste!
                      import('../../presentation/debug_ui/file_action_handler_debug.dart').then((m) {
                         m.FileActionHandlerDebug.handleFabAction(context, ref, ref.read(currentPathProvider));
                      });
                    },
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case MainView.home: return HomeView(onOpenStorage: () => _navigateTo(MainView.browser));
      case MainView.browser: return const BrowserView();
      case MainView.search: return const SearchView();
      case MainView.settings: return const SettingsView();
    }
  }
}

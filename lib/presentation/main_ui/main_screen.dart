import 'package:flutter/material.dart';
import '../ui_theme.dart';
import 'views/home_view.dart';
import 'views/browser_view.dart';
import 'views/search_view.dart';
import 'views/settings_view.dart';
import 'widgets/main_header.dart';
import 'widgets/operation_bar.dart';

enum MainView { home, browser, search, settings }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  MainView _currentView = MainView.home;
  bool _isSelectionMode = false;
  final int _selectionCount = 0; // FIXED: Made final to satisfy the linter
  
  // Operation Bar State
  bool _isCopyingState = false;

  void _navigateTo(MainView view) {
    setState(() => _currentView = view);
  }

  void _handleHardwareBack() {
    if (_isSelectionMode) {
      setState(() => _isSelectionMode = false);
      return;
    }
    if (_currentView == MainView.search || _currentView == MainView.settings) {
      _navigateTo(MainView.home);
      return;
    }
    if (_currentView == MainView.browser) {
      _navigateTo(MainView.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentView == MainView.home && !_isSelectionMode,
      // FIXED: Replaced deprecated onPopInvoked with onPopInvokedWithResult
      onPopInvokedWithResult: (didPop, result) { 
        if (!didPop) _handleHardwareBack(); 
      },
      child: Scaffold(
        backgroundColor: isDark ? ArgusColors.bgDark : ArgusColors.bgLight,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  MainHeader(
                    currentView: _currentView,
                    isSelectionMode: _isSelectionMode,
                    selectionCount: _selectionCount,
                    onBack: _handleHardwareBack,
                    onSearchTap: () => _navigateTo(MainView.search),
                    onCloseSearch: () => _navigateTo(MainView.home),
                    onToggleSelection: () => setState(() => _isSelectionMode = !_isSelectionMode),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildCurrentView(),
                    ),
                  ),
                ],
              ),
              if (_isCopyingState)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: OperationBar(
                    operationTitle: 'Copying',
                    itemName: 'Selected Files',
                    icon: Icons.content_copy,
                    onCancel: () => setState(() => _isCopyingState = false),
                    onPaste: () {
                      setState(() => _isCopyingState = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pasted successfully!')));
                    },
                  ),
                )
            ],
          ),
        ),
        floatingActionButton: _currentView == MainView.browser ? FloatingActionButton(
          onPressed: () => setState(() => _isCopyingState = true),
          backgroundColor: ArgusColors.primary,
          child: const Icon(Icons.copy, color: Colors.white),
        ) : null,
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentView) {
      case MainView.home: return HomeView(onNavigateBrowser: () => _navigateTo(MainView.browser));
      case MainView.browser: return const BrowserView();
      case MainView.search: return const SearchView();
      case MainView.settings: return const SettingsView();
    }
  }
}

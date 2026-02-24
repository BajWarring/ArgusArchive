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
  int _selectionCount = 0;
  
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
      // Stub: Jump back to home if path stack is empty
      _navigateTo(MainView.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentView == MainView.home && !_isSelectionMode,
      onPopInvoked: (didPop) { if (!didPop) _handleHardwareBack(); },
      child: Scaffold(
        backgroundColor: isDark ? ArgusColors.bgDark : ArgusColors.bgLight,
        body: SafeArea(
          child: Stack(
            children: [
              // 1. The Main Content
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
              
              // 2. The Floating Operation Bar (Shows when copying/cutting)
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
        
        // TEMPORARY: A floating button to test the operation bar so you can see it working
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

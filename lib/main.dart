import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/splash_ui/root_navigator.dart';
import 'services/sub_app/shortcut_service.dart';
import 'presentation/subapp_video_ui/video_library_screen.dart';
import 'presentation/ui_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ArgusArchiveApp()));
}

class ArgusArchiveApp extends StatefulWidget {
  const ArgusArchiveApp({super.key});
  @override
  State<ArgusArchiveApp> createState() => _ArgusArchiveAppState();
}

class _ArgusArchiveAppState extends State<ArgusArchiveApp> {
  @override
  void initState() {
    super.initState();
    _initShortcuts();
  }

  Future<void> _initShortcuts() async {
    final initialRoute = await ShortcutService.getInitialRoute();
    if (initialRoute == '/video_library') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const VideoLibraryScreen()));
      });
    }
    ShortcutService.listenToRouteChanges((route) {
      if (route == '/video_library') {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const VideoLibraryScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Argus Archive',
      debugShowCheckedModeBanner: false,
      // SET TO LIGHT THEME TO MATCH HTML
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: ArgusColors.primary,
        scaffoldBackgroundColor: ArgusColors.bgLight,
        appBarTheme: const AppBarTheme(backgroundColor: ArgusColors.bgLight, elevation: 0, foregroundColor: ArgusColors.textDark),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: ArgusColors.primary,
        scaffoldBackgroundColor: ArgusColors.bgDark,
        appBarTheme: const AppBarTheme(backgroundColor: ArgusColors.bgDark, elevation: 0, foregroundColor: Colors.white),
      ),
      themeMode: ThemeMode.light, // Default to Light Mode
      home: const RootNavigator(),
    );
  }
}

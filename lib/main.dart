import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'presentation/splash_ui/root_navigator.dart';
import 'services/sub_app/shortcut_service.dart';
// FIXED: Points to the new folder!
import 'services/video_player_app/video_library_screen.dart'; 

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ArgusArchiveApp(),
    ),
  );
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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: const RootNavigator(),
    );
  }
}

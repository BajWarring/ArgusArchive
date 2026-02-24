import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/splash_ui/root_navigator.dart';
import 'services/sub_app/shortcut_service.dart';
import 'presentation/subapp_video_ui/video_library_screen.dart'; // Updated path to the new UI

// Global Key to allow navigation from outside the standard widget tree
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    // 1. Check if the app was launched FROM a shortcut
    final initialRoute = await ShortcutService.getInitialRoute();
    if (initialRoute == '/video_library') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const VideoLibraryScreen()));
      });
    }

    // 2. Listen for shortcut taps while the app is already open in the background
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
        scaffoldBackgroundColor: const Color(0xFF101622), // Matched to new HTML background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1D2636), // Matched to new HTML surface
          elevation: 0,
        ),
      ),
      home: const RootNavigator(),
    );
  }
}

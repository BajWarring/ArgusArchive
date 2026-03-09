import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/splash_ui/root_navigator.dart';
import 'services/sub_app/shortcut_service.dart';
import 'services/media_player_app/media_library_screen.dart'; 

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // FORCE APP INTO PORTRAIT BY DEFAULT
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
    if (initialRoute == '/video_library' || initialRoute == '/media_player') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const MediaLibraryScreen()));
      });
    }

    ShortcutService.listenToRouteChanges((route) {
      if (route == '/video_library' || route == '/media_player') {
        navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const MediaLibraryScreen()));
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

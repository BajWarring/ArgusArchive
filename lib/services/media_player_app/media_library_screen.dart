import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'video_library_screen.dart';
import 'audio_library_screen.dart';
import 'more_menu_screen.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const VideoLibraryScreen(),
    const AudioLibraryScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Wrapped in Theme to match your exact mockup colors without breaking main app
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFFFF5E00), 
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFF5E00),
          secondary: Color(0xFFFF5E00),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: const Color(0xFFFF5E00),
          unselectedItemColor: const Color(0xFF6B6B6B),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 16,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.movie_creation_outlined), activeIcon: Icon(Icons.movie_creation), label: 'Video'),
            BottomNavigationBarItem(icon: Icon(Icons.music_note_outlined), activeIcon: Icon(Icons.music_note), label: 'Audio'),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }
}

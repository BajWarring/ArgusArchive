import 'package:flutter/material.dart';
import '../main_ui/main_screen.dart';

class RootNavigator extends StatelessWidget {
  const RootNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    // This immediately launches the new File Manager UI you just pasted!
    return const MainScreen();
  }
}

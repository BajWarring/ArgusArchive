import 'package:flutter/material.dart';
import 'routes/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alle Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}

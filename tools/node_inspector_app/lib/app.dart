import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'screens/shell_screen.dart';

class NodeInspectorApp extends StatelessWidget {
  const NodeInspectorApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Node Inspector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF167D6A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Color(0xEAFBFCFB),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Color(0xE8FFFFFF),
        ),
      ),
      home: ShellScreen(controller: controller),
    );
  }
}

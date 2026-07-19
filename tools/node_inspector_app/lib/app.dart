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
        scaffoldBackgroundColor: const Color(0xFFF2F7F5),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: ShellScreen(controller: controller),
    );
  }
}

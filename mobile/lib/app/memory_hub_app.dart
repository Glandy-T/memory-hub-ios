import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../features/shell/memory_shell.dart';
import '../state/memory_controller.dart';

class MemoryHubApp extends StatelessWidget {
  const MemoryHubApp({super.key, required this.controller});

  final MemoryController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Hub',
      debugShowCheckedModeBanner: false,
      theme: buildMemoryTheme(),
      home: MemoryShell(controller: controller),
    );
  }
}

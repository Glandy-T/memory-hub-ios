import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../features/shell/memory_shell.dart';
import '../state/memory_controller.dart';

class MemoryHubApp extends StatefulWidget {
  const MemoryHubApp({super.key, required this.controller});

  final MemoryController controller;

  @override
  State<MemoryHubApp> createState() => _MemoryHubAppState();
}

class _MemoryHubAppState extends State<MemoryHubApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.intake.refresh(silent: true).catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Hub',
      debugShowCheckedModeBanner: false,
      theme: buildMemoryTheme(),
      builder: (context, child) =>
          PigmentBackground(child: child ?? const SizedBox.shrink()),
      home: MemoryShell(controller: widget.controller),
    );
  }
}

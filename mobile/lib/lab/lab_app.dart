import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../services/memory_update_service.dart';
import '../state/memory_controller.dart';
import 'lab_onboarding.dart';
import 'lab_shell.dart';
import 'lab_state.dart';

class MemoryHubLabApp extends StatefulWidget {
  const MemoryHubLabApp({
    super.key,
    required this.controller,
    required this.lab,
  });

  final MemoryController controller;
  final LabState lab;

  @override
  State<MemoryHubLabApp> createState() => _MemoryHubLabAppState();
}

class _MemoryHubLabAppState extends State<MemoryHubLabApp> {
  final _updates = MemoryUpdateService();

  @override
  void dispose() {
    _updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Hub 实验版',
      debugShowCheckedModeBanner: false,
      theme: buildMemoryTheme(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: PointerDeviceKind.values.toSet(),
      ),
      builder: (context, child) =>
          PigmentBackground(child: child ?? const SizedBox.shrink()),
      home: AnimatedBuilder(
        animation: widget.lab,
        builder: (context, _) => widget.lab.data.onboardingComplete
            ? LabShell(
                controller: widget.controller,
                lab: widget.lab,
                updates: _updates,
              )
            : LabOnboarding(lab: widget.lab),
      ),
    );
  }
}

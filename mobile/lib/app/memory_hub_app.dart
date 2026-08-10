import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/memory_theme.dart';
import '../core/widgets/memory_surfaces.dart';
import '../features/shell/memory_shell.dart';
import '../features/profile/app_update_screen.dart';
import '../services/memory_update_service.dart';
import '../state/memory_controller.dart';

class MemoryHubApp extends StatefulWidget {
  const MemoryHubApp({super.key, required this.controller, this.updateService});

  final MemoryController controller;
  final MemoryUpdateService? updateService;

  @override
  State<MemoryHubApp> createState() => _MemoryHubAppState();
}

class _MemoryHubAppState extends State<MemoryHubApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final MemoryUpdateService _updates;
  late final bool _ownsUpdateService;
  bool _announcedUpdate = false;

  @override
  void initState() {
    super.initState();
    _ownsUpdateService = widget.updateService == null;
    _updates = widget.updateService ?? MemoryUpdateService();
    _updates.addListener(_handleUpdateState);
    WidgetsBinding.instance.addObserver(this);
    if (kReleaseMode && defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updates.check(silent: true);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.intake.refresh(silent: true).catchError((_) {});
    });
  }

  void _handleUpdateState() {
    final update = _updates.available;
    if (update == null || _announcedUpdate || !mounted) return;
    _announcedUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Memory Hub ${update.versionName} 可以更新'),
          action: SnackBarAction(
            label: '查看',
            onPressed: () {
              final navigator = _navigatorKey.currentState;
              if (navigator == null) return;
              navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => AppUpdateScreen(updates: _updates),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.intake.refresh(silent: true).catchError((_) {});
      if (kReleaseMode && defaultTargetPlatform == TargetPlatform.android) {
        _updates.check(silent: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updates.removeListener(_handleUpdateState);
    if (_ownsUpdateService) _updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'Memory Hub',
      debugShowCheckedModeBanner: false,
      theme: buildMemoryTheme(),
      builder: (context, child) =>
          PigmentBackground(child: child ?? const SizedBox.shrink()),
      home: MemoryShell(controller: widget.controller, updates: _updates),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/memory_hub_app.dart';
import 'data/memory_repository.dart';
import 'services/memory_intake_service.dart';
import 'services/memory_notification_service.dart';
import 'state/memory_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _MemoryHubBootstrap());
}

class _MemoryHubBootstrap extends StatefulWidget {
  const _MemoryHubBootstrap();

  @override
  State<_MemoryHubBootstrap> createState() => _MemoryHubBootstrapState();
}

class _MemoryHubBootstrapState extends State<_MemoryHubBootstrap> {
  late Future<MemoryController> _initialization = _initialize();

  Future<MemoryController> _initialize() async {
    await initializeDateFormatting('zh_CN');
    final services = await Future.wait<Object>([
      LocalMemoryNotificationService.create(),
      MemoryIntakeService.create(),
    ]);
    return MemoryController.create(
      SharedPreferencesMemoryRepository(),
      notifications: services[0] as MemoryNotificationService,
      intake: services[1] as MemoryIntakeService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MemoryController>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return MemoryHubApp(controller: snapshot.requireData);
        }
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 36),
                        const SizedBox(height: 18),
                        const Text(
                          'Memory Hub 启动时遇到问题',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '数据没有被修改。请截图此页，便于定位具体原因。',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(() {
                            _initialization = _initialize();
                          }),
                          child: const Text('重新尝试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          ),
        );
      },
    );
  }
}

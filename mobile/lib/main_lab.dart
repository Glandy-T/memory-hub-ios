import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'lab/lab_app.dart';
import 'lab/lab_memory_repository.dart';
import 'lab/lab_state.dart';
import 'services/memory_intake_service.dart';
import 'services/memory_notification_service.dart';
import 'state/memory_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  final services = await Future.wait<Object>([
    LocalMemoryNotificationService.create(),
    MemoryIntakeService.create(refreshOnCreate: false),
    LabState.create(),
  ]);
  final controller = await MemoryController.create(
    LabMemoryRepository(),
    notifications: services[0] as MemoryNotificationService,
    intake: services[1] as MemoryIntakeService,
  );
  runApp(MemoryHubLabApp(controller: controller, lab: services[2] as LabState));
}

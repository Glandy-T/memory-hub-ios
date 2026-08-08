import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/memory_hub_app.dart';
import 'data/memory_repository.dart';
import 'state/memory_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  final controller = await MemoryController.create(
    SharedPreferencesMemoryRepository(),
  );
  runApp(MemoryHubApp(controller: controller));
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:memory_hub/app/memory_hub_app.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));

  testWidgets('home light visual baseline at iPhone-class size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          tasks: [
            MemoryTask(
              id: 'visual-task-1',
              title: '整理体检资料',
              note: '带上上次检查报告和用药清单',
              date: DateTime(today.year, today.month, today.day),
              minutesFromMidnight: 14 * 60,
              updatedAt: today,
            ),
            MemoryTask(
              id: 'visual-task-2',
              title: '给诊所打电话',
              date: DateTime(today.year, today.month, today.day),
              updatedAt: today,
            ),
            MemoryTask(
              id: 'visual-task-3',
              title: '取快递',
              date: DateTime(today.year, today.month, today.day),
              minutesFromMidnight: 18 * 60 + 30,
              updatedAt: today,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_light_430x932.png'),
    );
  }, tags: 'visual');
}

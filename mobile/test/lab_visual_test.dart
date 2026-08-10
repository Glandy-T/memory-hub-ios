import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memory_hub/core/theme/memory_theme.dart';
import 'package:memory_hub/core/widgets/memory_surfaces.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/lab/lab_models.dart';
import 'package:memory_hub/lab/lab_state.dart';
import 'package:memory_hub/lab/task_detail_screen.dart';
import 'package:memory_hub/lab/timeline_screen.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('lab task detail follows approved light hierarchy', (
    tester,
  ) async {
    _size(tester);
    final fixture = await _fixture();
    await tester.pumpWidget(
      _app(
        LabTaskDetailScreen(
          controller: fixture.controller,
          lab: fixture.lab,
          taskId: 'task-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/lab_task_detail_430x932.png'),
    );
  }, tags: 'visual');

  testWidgets('lab timeline preserves readable time grouping', (tester) async {
    _size(tester);
    final fixture = await _fixture();
    await tester.pumpWidget(
      _app(
        TimelineScreen(
          controller: fixture.controller,
          lab: fixture.lab,
          date: DateTime(2026, 8, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/lab_timeline_430x932.png'),
    );
  }, tags: 'visual');
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildMemoryTheme(),
  builder: (context, child) => PigmentBackground(child: child!),
  home: home,
);

Future<({MemoryController controller, LabState lab})> _fixture() async {
  final now = DateTime(2026, 8, 10, 11, 20);
  final initial = MemoryData(
    categories: [
      ...MemoryData.initial().categories,
      const MemoryCategory(
        id: 'health',
        name: '健康',
        colorValue: 0xFF41C7BE,
        order: 1,
      ),
    ],
    tasks: [
      MemoryTask(
        id: 'task-0',
        title: '整理邮件',
        date: DateTime(2026, 8, 10),
        minutesFromMidnight: 9 * 60 + 30,
        status: MemoryTaskStatus.completed,
        updatedAt: now,
      ),
      MemoryTask(
        id: 'task-1',
        title: '整理体检资料',
        note: '带上次检查报告和用药清单',
        date: DateTime(2026, 8, 10),
        minutesFromMidnight: 14 * 60,
        updatedAt: now,
      ),
      MemoryTask(
        id: 'task-2',
        title: '取快递',
        date: DateTime(2026, 8, 10),
        updatedAt: now,
      ),
    ],
    documents: [
      MemoryDocument(
        id: 'doc-1',
        categoryId: 'health',
        title: '体检记录',
        updatedAt: now,
      ),
    ],
    locatedItems: [
      LocatedItem(
        id: 'item-1',
        name: '蓝色文件夹',
        location: '书桌右侧抽屉',
        quantity: '1',
        updatedAt: now,
      ),
    ],
    deadlines: [
      MemoryDeadline(
        id: 'deadline-1',
        title: '提交体检资料',
        date: DateTime(2026, 8, 14),
        updatedAt: now,
      ),
    ],
  );
  final controller = await MemoryController.create(
    InMemoryRepository(initial),
    clock: now,
  );
  final lab = await LabState.create();
  await lab.savePlan(
    const LabTaskPlan(
      taskId: 'task-1',
      durationMinutes: 30,
      linkedDocumentId: 'doc-1',
      linkedItemId: 'item-1',
      linkedDeadlineId: 'deadline-1',
      steps: [
        LabStep(id: 'step-1', title: '打开医院文件夹', minutes: 2),
        LabStep(id: 'step-2', title: '找到上次体检报告', minutes: 5),
      ],
    ),
  );
  await lab.savePlan(const LabTaskPlan(taskId: 'task-2', durationMinutes: 15));
  return (controller: controller, lab: lab);
}

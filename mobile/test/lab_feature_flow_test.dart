import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memory_hub/core/theme/memory_theme.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/lab/lab_models.dart';
import 'package:memory_hub/lab/lab_onboarding.dart';
import 'package:memory_hub/lab/lab_state.dart';
import 'package:memory_hub/lab/pending_capture_screen.dart';
import 'package:memory_hub/lab/task_detail_screen.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onboarding completes without a diagnostic questionnaire', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lab = await LabState.create();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMemoryTheme(),
        home: LabOnboarding(lab: lab),
      ),
    );

    expect(find.text('先记下来'), findsOneWidget);
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    expect(find.text('选择常用功能'), findsOneWidget);
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('保存方式'), findsOneWidget);
    await tester.tap(find.text('进入首页'));
    await tester.pumpAndSettle();

    expect(lab.data.onboardingComplete, isTrue);
  });

  testWidgets('task detail creates editable five-step plan', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await MemoryController.create(InMemoryRepository());
    await controller.addTask(title: '整理体检资料', date: DateTime(2026, 8, 10));
    final task = controller.data.tasks.single;
    final lab = await LabState.create();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMemoryTheme(),
        home: LabTaskDetailScreen(
          controller: controller,
          lab: lab,
          taskId: task.id,
        ),
      ),
    );
    await tester.tap(find.text('拆成几步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刚刚好'));
    await tester.pumpAndSettle();

    expect(find.text('整理步骤'), findsOneWidget);
    expect(lab.planFor(task.id).steps, hasLength(5));
    expect(find.text('当前下一步'), findsOneWidget);
  });

  testWidgets(
    'pending purchase enters the isolated app database after review',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await MemoryController.create(InMemoryRepository());
      final lab = await LabState.create();
      await lab.addCapture('买牛奶', LabCaptureKind.purchase);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildMemoryTheme(),
          home: PendingCaptureScreen(controller: controller, lab: lab),
        ),
      );
      await tester.tap(find.text('买牛奶'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认收录'));
      await tester.pumpAndSettle();

      expect(controller.data.shoppingItems.single.name, '买牛奶');
      expect(lab.data.captures, isEmpty);
    },
  );
}

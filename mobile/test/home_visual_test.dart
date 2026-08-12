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

    final today = DateTime(2026, 8, 8, 12);
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
      clock: today,
    );

    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();
    // Let the large pigment asset finish decoding outside the fake clock;
    // otherwise the first material frame can capture its white placeholder.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 220)),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_light_430x932.png'),
    );

    final card = find.byKey(
      ValueKey('task-card-motion-${controller.todayTasks[1].id}'),
    );
    final resting = List<double>.of(
      tester.widget<AnimatedContainer>(card).transform!.storage,
    );
    final bounds = tester.getRect(card);
    final gesture = await tester.startGesture(
      bounds.center + const Offset(-70, -100),
    );
    await gesture.moveBy(const Offset(105, -96));
    await tester.pump();
    expect(
      tester.widget<AnimatedContainer>(card).transform!.storage,
      isNot(equals(resting)),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_card_tilt_430x932.png'),
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }, tags: 'visual');

  testWidgets(
    'category light visual follows the independent glass-row layout',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = await MemoryController.create(
        InMemoryRepository(
          MemoryData(
            categories: [
              ...MemoryData.initial().categories,
              const MemoryCategory(
                id: 'documents',
                name: '证件',
                colorValue: 0xFFFFCA3A,
                order: 1,
              ),
              const MemoryCategory(
                id: 'health',
                name: '健康',
                colorValue: 0xFF41C7BE,
                order: 2,
              ),
              const MemoryCategory(
                id: 'study',
                name: '学习',
                colorValue: 0xFF5C8CFF,
                order: 3,
              ),
              const MemoryCategory(
                id: 'ideas',
                name: '灵感',
                colorValue: 0xFF8F7CF6,
                order: 4,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(MemoryHubApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('分类'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/categories_light_430x932.png'),
      );
    },
    tags: 'visual',
  );

  testWidgets('calendar light visual aligns deadlines and daily tasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime(2026, 8, 8, 12);
    final today = DateTime(now.year, now.month, now.day);
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          deadlines: [
            MemoryDeadline(
              id: 'calendar-deadline-1',
              title: '提交体检资料',
              date: today,
              minutesFromMidnight: 17 * 60,
              updatedAt: now,
            ),
          ],
          tasks: [
            MemoryTask(
              id: 'calendar-visual-1',
              title: '给诊所打电话',
              date: today,
              minutesFromMidnight: 9 * 60 + 30,
              updatedAt: now,
            ),
          ],
        ),
      ),
      clock: now,
    );
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('日历'));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text('＋ 新增事项')).dy,
      lessThan(840),
      reason: '内联新增行不应被底部导航遮挡',
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/calendar_light_430x932.png'),
    );
  }, tags: 'visual');
}

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/app/memory_hub_app.dart';
import 'package:memory_hub/core/widgets/memory_surfaces.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));

  testWidgets('shows the empty home and four primary destinations', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('今日事项'), findsOneWidget);
    expect(find.text('今天暂时没有待处理事项'), findsOneWidget);
    expect(find.bySemanticsLabel('首页'), findsOneWidget);
    expect(find.bySemanticsLabel('日历'), findsOneWidget);
    expect(find.bySemanticsLabel('分类'), findsOneWidget);
    expect(find.bySemanticsLabel('我的'), findsOneWidget);
  });

  testWidgets('keeps the shared pigment background behind life routes', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('冰箱'));
    await tester.pumpAndSettle();

    expect(find.text('冰箱'), findsWidgets);
    expect(
      find.ancestor(
        of: find.text('冰箱').last,
        matching: find.byType(PigmentBackground),
      ),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('物品位置'));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('物品位置').last,
        matching: find.byType(PigmentBackground),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the shared background through category document routes', (
    tester,
  ) async {
    final seed = MemoryData(
      categories: MemoryData.initial().categories,
      documents: [
        MemoryDocument(
          id: 'document-route-test',
          categoryId: 'memory-hub-default-category',
          title: '旅行证件放在哪里',
          updatedAt: DateTime(2026, 8, 8),
        ),
      ],
    );
    final controller = await MemoryController.create(InMemoryRepository(seed));
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未分类'));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('未分类').last,
        matching: find.byType(PigmentBackground),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('旅行证件放在哪里'));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('旅行证件放在哪里').last,
        matching: find.byType(PigmentBackground),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'category rows are independent glass buttons with long-press manage',
    (tester) async {
      final controller = await MemoryController.create(InMemoryRepository());
      await controller.addCategory('证件', 0xFFFFCA3A);
      await tester.pumpWidget(MemoryHubApp(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('分类'));
      await tester.pumpAndSettle();

      expect(find.text('全部分类'), findsOneWidget);
      expect(find.text('搜索文档和分类'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('未分类'),
          matching: find.byType(OpticalGlass),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: find.text('证件'), matching: find.byType(OpticalGlass)),
        findsOneWidget,
      );

      await tester.longPress(find.text('证件'));
      await tester.pumpAndSettle();
      expect(find.text('管理分类'), findsOneWidget);
      expect(find.text('新增分类'), findsOneWidget);
    },
  );

  testWidgets('calendar uses inline add row and can soft delete a task', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    final today = controller.effectiveToday();
    await controller.addTask(title: '给诊所打电话', date: today);
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('日历'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    expect(find.text('＋ 新增事项'), findsOneWidget);

    await tester.tap(find.text('给诊所打电话'));
    await tester.pumpAndSettle();
    expect(find.text('编辑事项'), findsOneWidget);
    await tester.tap(find.text('删除事项'));
    await tester.pumpAndSettle();
    expect(find.text('删除这个事项？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(find.text('给诊所打电话'), findsNothing);
    expect(controller.data.tasks.single.status, MemoryTaskStatus.deleted);
  });
}

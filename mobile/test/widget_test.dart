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
}

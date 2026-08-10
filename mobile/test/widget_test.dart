import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/app/memory_hub_app.dart';
import 'package:memory_hub/core/widgets/memory_surfaces.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/features/calendar/deadline_screen.dart';
import 'package:memory_hub/features/life/life_screens.dart';
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

  testWidgets(
    'assembles the selected navigation icon without changing targets',
    (tester) async {
      final controller = await MemoryController.create(InMemoryRepository());
      await tester.pumpWidget(MemoryHubApp(controller: controller));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('nav-color-首页')))
            .opacity,
        1,
      );
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('nav-color-日历')))
            .opacity,
        0,
      );
      expect(tester.getSize(find.bySemanticsLabel('日历')), const Size(48, 48));

      await tester.tap(find.bySemanticsLabel('日历'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      final calendarProgress = tester
          .widget<Opacity>(find.byKey(const ValueKey('nav-color-日历')))
          .opacity;
      expect(calendarProgress, greaterThan(0));
      expect(calendarProgress, lessThan(1));

      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('nav-color-日历')))
            .opacity,
        1,
      );
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('nav-color-首页')))
            .opacity,
        0,
      );
    },
  );

  testWidgets('switches navigation instantly when animations are disabled', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final controller = await MemoryController.create(InMemoryRepository());
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('分类'));
    await tester.pump();

    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('nav-color-分类')))
          .opacity,
      1,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('nav-color-首页')))
          .opacity,
      0,
    );
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

  testWidgets('calendar period entry opens real rule management', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('日历'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('周期事项'));
    await tester.pumpAndSettle();

    expect(find.text('还没有周期事项'), findsOneWidget);
    expect(find.byTooltip('新增周期事项'), findsOneWidget);
  });

  testWidgets('completed calendar entries can return to pending', (
    tester,
  ) async {
    final today = DateTime(2026, 8, 10, 12);
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          tasks: [
            MemoryTask(
              id: 'completed-task',
              title: '重新处理事项',
              date: today,
              updatedAt: today,
              status: MemoryTaskStatus.completed,
            ),
          ],
        ),
      ),
      clock: today,
    );
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('日历'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('重新处理事项'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('重新处理事项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新设为待处理'));
    await tester.pumpAndSettle();

    expect(controller.data.tasks.single.status, MemoryTaskStatus.active);
  });

  testWidgets('completed deadline can return to pending', (tester) async {
    final today = DateTime(2026, 8, 10);
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          deadlines: [
            MemoryDeadline(
              id: 'completed-deadline',
              title: '重新处理截止日',
              date: today,
              updatedAt: today,
              status: MemoryDeadlineStatus.completed,
            ),
          ],
        ),
      ),
      clock: today,
    );
    await tester.pumpWidget(
      MaterialApp(home: DeadlineScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新处理截止日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新设为待处理'));
    await tester.pumpAndSettle();

    expect(
      controller.data.deadlines.single.status,
      MemoryDeadlineStatus.active,
    );
  });

  testWidgets('document edit mode exposes a working soft delete action', (
    tester,
  ) async {
    final seed = MemoryData(
      categories: MemoryData.initial().categories,
      documents: [
        MemoryDocument(
          id: 'delete-document-test',
          categoryId: 'memory-hub-default-category',
          title: '需要删除的文档',
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
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('文档操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除文档'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(controller.data.documents.single.deleted, isTrue);
    expect(find.text('需要删除的文档'), findsNothing);
  });

  testWidgets('document can move to another category from edit mode', (
    tester,
  ) async {
    final seed = MemoryData(
      categories: [
        ...MemoryData.initial().categories,
        const MemoryCategory(
          id: 'health-category',
          name: '健康',
          colorValue: 0xFF41C7BE,
          order: 1,
        ),
      ],
      documents: [
        MemoryDocument(
          id: 'move-document-test',
          categoryId: 'memory-hub-default-category',
          title: '复诊资料',
          updatedAt: DateTime(2026, 8, 10),
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
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('文档操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动到分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('健康').last);
    await tester.pumpAndSettle();

    expect(controller.data.documents.single.categoryId, 'health-category');
    expect(find.text('复诊资料'), findsNothing);
  });

  testWidgets('home reminder can be hidden for the current effective day', (
    tester,
  ) async {
    final seed = MemoryData(
      categories: MemoryData.initial().categories,
      documents: [
        MemoryDocument(
          id: 'reminder-action-test',
          categoryId: 'memory-hub-default-category',
          title: '偶尔回看这篇文档',
          updatedAt: DateTime.now(),
          inReminderPool: true,
        ),
      ],
    );
    final controller = await MemoryController.create(InMemoryRepository(seed));
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('偶尔回看这篇文档'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('提醒操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今天隐藏'));
    await tester.pumpAndSettle();

    expect(controller.data.documents.single.reminderMutedUntil, isNotNull);
    expect(find.text('偶尔回看这篇文档'), findsNothing);
  });

  testWidgets('global search finds records and life information', (
    tester,
  ) async {
    final seed = MemoryData(
      categories: MemoryData.initial().categories,
      documents: [
        MemoryDocument(
          id: 'search-document',
          categoryId: 'memory-hub-default-category',
          title: '旅行证件',
          updatedAt: DateTime(2026, 8, 8),
          records: [
            MemoryRecord(
              id: 'search-record',
              body: '护照复印件放在蓝色文件夹里',
              createdAt: DateTime(2026, 8, 8),
            ),
          ],
        ),
      ],
      locatedItems: [
        LocatedItem(
          id: 'search-item',
          name: '备用钥匙',
          location: '玄关蓝色盒子',
          quantity: '1 把',
          updatedAt: DateTime(2026, 8, 8),
        ),
      ],
    );
    final controller = await MemoryController.create(InMemoryRepository(seed));
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SearchBar).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchBar).last, '蓝色');
    await tester.pumpAndSettle();

    expect(find.textContaining('护照复印件'), findsOneWidget);
    expect(find.text('备用钥匙'), findsOneWidget);
  });

  testWidgets('fridge history can restore a removed item', (tester) async {
    final removedAt = DateTime(2026, 8, 8, 12);
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          fridgeItems: [
            FridgeItem(
              id: 'removed-milk',
              name: '牛奶',
              quantity: '1 盒',
              storage: FridgeStorage.chilled,
              updatedAt: removedAt,
              deleted: true,
              deletedAt: removedAt,
              removalReason: FridgeRemovalReason.eaten,
            ),
          ],
        ),
      ),
      clock: removedAt,
    );
    await tester.pumpWidget(
      MaterialApp(home: FridgeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('15天历史'));
    await tester.pumpAndSettle();
    expect(find.text('牛奶'), findsOneWidget);
    expect(find.textContaining('已用完'), findsOneWidget);
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();
    expect(controller.data.fridgeItems.single.deleted, isFalse);
    expect(find.text('最近 15 天没有移除记录'), findsOneWidget);
  });

  testWidgets('purchased shopping item offers an immediate undo', (
    tester,
  ) async {
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          shoppingItems: const [ShoppingItem(id: 'milk', name: '牛奶')],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: FridgeScreen(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('待采购'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(controller.data.shoppingItems.single.bought, isTrue);
    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(controller.data.shoppingItems.single.bought, isFalse);
    expect(find.text('牛奶'), findsOneWidget);
  });

  testWidgets('located item editor preserves free text and shows history', (
    tester,
  ) async {
    final controller = await MemoryController.create(
      InMemoryRepository(
        MemoryData(
          categories: MemoryData.initial().categories,
          locatedItems: [
            LocatedItem(
              id: 'keys',
              name: '备用钥匙',
              location: '书房第二层抽屉',
              quantity: '1 把',
              updatedAt: DateTime(2026, 8, 8),
              locationHistory: [
                LocationHistoryEntry(
                  location: '玄关蓝色盒子',
                  changedAt: DateTime(2026, 8, 7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: LocatedItemsScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('位置历史'));
    await tester.pumpAndSettle();
    expect(find.text('现在：书房第二层抽屉'), findsOneWidget);
    expect(find.text('玄关蓝色盒子'), findsOneWidget);
  });

  testWidgets('profile recycle bin restores a deleted task', (tester) async {
    final seed = MemoryData(
      categories: MemoryData.initial().categories,
      tasks: [
        MemoryTask(
          id: 'recycle-task',
          title: '恢复这条事项',
          date: DateTime(2026, 8, 8),
          updatedAt: DateTime(2026, 8, 8),
          status: MemoryTaskStatus.deleted,
        ),
      ],
    );
    final controller = await MemoryController.create(InMemoryRepository(seed));
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('回收站'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('回收站'));
    await tester.pumpAndSettle();
    expect(find.text('恢复这条事项'), findsOneWidget);
    await tester.tap(find.byTooltip('回收站操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(controller.data.tasks.single.status, MemoryTaskStatus.active);
    expect(find.text('回收站是空的'), findsOneWidget);
  });

  testWidgets('profile opens real notification settings', (tester) async {
    final controller = await MemoryController.create(InMemoryRepository());
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每日检查提醒'));
    await tester.pumpAndSettle();

    expect(find.text('通知设置'), findsOneWidget);
    expect(find.text('强提醒间隔'), findsOneWidget);
    expect(find.text('15 分钟'), findsOneWidget);
    expect(find.text('发送测试通知'), findsOneWidget);
    expect(find.textContaining('不申请精确闹钟'), findsOneWidget);
  });

  testWidgets('disconnected intake offers QR pairing with file fallback', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('待收录'));
    await tester.pumpAndSettle();

    expect(find.text('扫码连接'), findsOneWidget);
    expect(find.text('选择备用配对文件'), findsOneWidget);
    expect(find.textContaining('连接只需进行一次'), findsOneWidget);
  });

  testWidgets('primary shell survives narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = await MemoryController.create(InMemoryRepository());

    await tester.pumpWidget(MemoryHubApp(controller: controller));
    await tester.pumpAndSettle();
    for (final label in ['日历', '分类', '我的', '首页']) {
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

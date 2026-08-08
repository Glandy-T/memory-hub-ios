import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/app/memory_hub_app.dart';
import 'package:memory_hub/data/memory_repository.dart';
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
}

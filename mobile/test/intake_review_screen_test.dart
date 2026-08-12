import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/features/profile/intake_review_screen.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/services/memory_intake_service.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  setUpAll(() => initializeDateFormatting('zh_CN'));

  testWidgets(
    'reviewed schedule can become all-day and document selects category',
    (tester) async {
      final service = await MemoryIntakeService.create(
        store: _FakeSecretStore(),
        refreshOnCreate: false,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'calendar-review',
                  'target': 'calendar',
                  'title': '下午复诊',
                  'payload': {'scheduledAt': '2026-08-12T14:30:00+09:00'},
                  'source': {'label': 'Codex'},
                  'receivedAt': '2026-08-10T10:00:00.000Z',
                },
                {
                  'id': 'document-review',
                  'target': 'document',
                  'title': '复诊准备',
                  'payload': <String, Object?>{},
                  'source': {'label': 'Codex'},
                  'receivedAt': '2026-08-10T10:00:00.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await service.connectFromJson(
        jsonEncode({
          'schemaVersion': 1,
          'baseUrl': 'https://memory.example.test',
          'deviceToken': 'device-token-123456789012345678901234',
          'siteBypassToken': 'site-token-12345678901234567890123456',
        }),
      );
      final seed = MemoryData(
        categories: [
          ...MemoryData.initial().categories,
          const MemoryCategory(
            id: 'health',
            name: '健康',
            colorValue: 0xFF41C7BE,
            order: 1,
          ),
        ],
      );
      final controller = await MemoryController.create(
        InMemoryRepository(seed),
        intake: service,
      );
      await tester.pumpWidget(
        MaterialApp(home: IntakeReviewScreen(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('编辑待收录内容').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('改为全天'));
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();
      expect(find.textContaining('全天'), findsOneWidget);

      // An uncategorized document cannot silently fall into the default
      // category. Its primary action first asks where it should be saved.
      await tester.tap(find.widgetWithText(FilledButton, '收录').last);
      await tester.pumpAndSettle();
      expect(find.text('保存到分类'), findsOneWidget);
      expect(find.text('保存并收录'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text('保存并收录'), findsNothing);

      // The category target is also a visible 48dp action on the candidate,
      // rather than being available only behind the edit icon.
      await tester.tap(
        find.byKey(const ValueKey('intake-document-category-document-review')),
      );
      await tester.pumpAndSettle();
      expect(find.text('保存修改'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('编辑待收录内容').last);
      await tester.pumpAndSettle();
      expect(find.text('保存到分类'), findsOneWidget);
      await tester.tap(find.text('未分类').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('健康').last);
      final saveButton = find.widgetWithText(FilledButton, '保存修改');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('保存到「健康」'), findsOneWidget);
    },
  );
}

class _FakeSecretStore implements MemorySecretStore {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

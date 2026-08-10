import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memory_hub/services/memory_intake_service.dart';

void main() {
  const deviceToken = 'device-token-123456789012345678901234';
  const siteToken = 'site-token-12345678901234567890123456';
  const connection = {
    'schemaVersion': 1,
    'baseUrl': 'https://memory.example.test',
    'deviceToken': deviceToken,
    'siteBypassToken': siteToken,
  };

  test('imports a secure connection and reads pending candidates', () async {
    late http.Request captured;
    final service = await MemoryIntakeService.create(
      store: _FakeSecretStore(),
      refreshOnCreate: false,
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'candidate-1',
                'target': 'calendar',
                'title': '牙科复诊',
                'note': '带保险证',
                'payload': {'date': '2026-08-12'},
                'source': {'label': 'Codex'},
                'receivedAt': '2026-08-09T12:00:00.000Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await service.connectFromJson(jsonEncode(connection));

    expect(service.connected, isTrue);
    expect(service.items.single.title, '牙科复诊');
    expect(captured.headers['authorization'], 'Bearer $deviceToken');
    expect(captured.headers['oai-sites-authorization'], 'Bearer $siteToken');
  });

  test('posts reviewed content and removes the decided candidate', () async {
    var calls = 0;
    late http.Request decision;
    final service = await MemoryIntakeService.create(
      store: _FakeSecretStore(),
      refreshOnCreate: false,
      client: MockClient((request) async {
        calls += 1;
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'candidate-1',
                  'target': 'document',
                  'title': '原始标题',
                  'payload': <String, Object?>{},
                  'source': {'label': 'Codex'},
                  'receivedAt': '2026-08-09T12:00:00.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        decision = request;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await service.connectFromJson(jsonEncode(connection));
    final edited = service.items.single.copyWith(title: '审核后的标题');

    await service.decide(edited, accept: true);

    expect(calls, 2);
    expect(service.items, isEmpty);
    final body = jsonDecode(decision.body) as Map<String, Object?>;
    expect(body['action'], 'accept');
    expect((body['item'] as Map<String, Object?>)['title'], '审核后的标题');
  });

  test('clears credentials if initial verification fails', () async {
    final store = _FakeSecretStore();
    final service = await MemoryIntakeService.create(
      store: store,
      refreshOnCreate: false,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': '拒绝连接'}),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      service.connectFromJson(jsonEncode(connection)),
      throwsA(isA<MemoryIntakeException>()),
    );
    expect(service.connected, isFalse);
    expect(store.values, isEmpty);
  });

  test(
    'restores a saved connection without blocking startup on refresh',
    () async {
      final store = _FakeSecretStore();
      final connected = await MemoryIntakeService.create(
        store: store,
        refreshOnCreate: false,
        client: MockClient((_) async => http.Response('{"items":[]}', 200)),
      );
      await connected.connectFromJson(jsonEncode(connection));

      var requests = 0;
      final restored = await MemoryIntakeService.create(
        store: store,
        refreshOnCreate: false,
        client: MockClient((_) async {
          requests += 1;
          return http.Response('{"items":[]}', 200);
        }),
      );

      expect(restored.connected, isTrue);
      expect(requests, 0);
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

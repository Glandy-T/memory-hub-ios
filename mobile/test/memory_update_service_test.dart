import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:memory_hub/services/memory_update_service.dart';

void main() {
  final api = Uri.parse('https://updates.example.test/latest');
  final manifest = Uri.parse('https://updates.example.test/update.json');
  const checksum =
      '0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF';

  test('finds a newer signed release and delegates installation', () async {
    final platform = _FakeUpdatePlatform(currentBuild: 1003);
    final service = MemoryUpdateService(
      latestReleaseApi: api,
      platform: platform,
      client: MockClient((request) async {
        if (request.url == api) {
          return http.Response(
            jsonEncode({
              'assets': [
                {
                  'name': 'memory-hub-update.json',
                  'browser_download_url': manifest.toString(),
                },
              ],
            }),
            200,
          );
        }
        expect(request.url, manifest);
        return http.Response(
          jsonEncode({
            'schemaVersion': 1,
            'versionCode': 1004,
            'versionName': '1.0.4',
            'apkUrl':
                'https://github.com/Glandy-T/memory-hub-ios/releases/download/android-v1.0.4/memory-hub-android.apk',
            'sha256': checksum,
            'notes': '覆盖安装验收通过',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final update = await service.check();

    expect(update?.versionCode, 1004);
    expect(service.available?.versionName, '1.0.4');
    expect(service.error, isNull);
    expect(
      await service.installAvailable(),
      UpdateInstallResult.installerOpened,
    );
    expect(platform.installed?.sha256, checksum);
    service.dispose();
  });

  test('treats the same build as already current', () async {
    final service = MemoryUpdateService(
      latestReleaseApi: api,
      platform: _FakeUpdatePlatform(currentBuild: 1004),
      client: _releaseClient(
        api: api,
        manifest: manifest,
        checksum: checksum,
        versionCode: 1004,
      ),
    );

    expect(await service.check(), isNull);
    expect(service.checked, isTrue);
    expect(service.available, isNull);
    service.dispose();
  });

  test(
    'rejects a manifest whose APK is not from the project release',
    () async {
      final service = MemoryUpdateService(
        latestReleaseApi: api,
        platform: _FakeUpdatePlatform(currentBuild: 1003),
        client: MockClient((request) async {
          if (request.url == api) {
            return http.Response(
              jsonEncode({
                'assets': [
                  {
                    'name': 'memory-hub-update.json',
                    'browser_download_url': manifest.toString(),
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'schemaVersion': 1,
              'versionCode': 1004,
              'versionName': '1.0.4',
              'apkUrl': 'https://example.test/untrusted.apk',
              'sha256': checksum,
              'notes': '',
            }),
            200,
          );
        }),
      );

      await expectLater(
        service.check(),
        throwsA(
          isA<MemoryUpdateException>().having(
            (error) => error.message,
            'message',
            '更新信息无法识别',
          ),
        ),
      );
      expect(service.available, isNull);
      service.dispose();
    },
  );
}

MockClient _releaseClient({
  required Uri api,
  required Uri manifest,
  required String checksum,
  required int versionCode,
}) => MockClient((request) async {
  if (request.url == api) {
    return http.Response(
      jsonEncode({
        'assets': [
          {
            'name': 'memory-hub-update.json',
            'browser_download_url': manifest.toString(),
          },
        ],
      }),
      200,
    );
  }
  return http.Response(
    jsonEncode({
      'schemaVersion': 1,
      'versionCode': versionCode,
      'versionName': '1.0.4',
      'apkUrl':
          'https://github.com/Glandy-T/memory-hub-ios/releases/download/android-v1.0.4/memory-hub-android.apk',
      'sha256': checksum,
      'notes': '',
    }),
    200,
  );
});

class _FakeUpdatePlatform implements MemoryUpdatePlatform {
  _FakeUpdatePlatform({required this.currentBuild});

  final int currentBuild;
  MemoryUpdateInfo? installed;

  @override
  Future<int> currentBuildNumber() async => currentBuild;

  @override
  Future<UpdateInstallResult> downloadAndInstall(
    MemoryUpdateInfo update,
  ) async {
    installed = update;
    return UpdateInstallResult.installerOpened;
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const _defaultLatestReleaseApi =
    'https://api.github.com/repos/Glandy-T/memory-hub-ios/releases/latest';
const _manifestAssetName = 'memory-hub-update.json';

enum UpdateInstallResult { installerOpened, permissionRequired }

class MemoryUpdateException implements Exception {
  const MemoryUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MemoryUpdateInfo {
  const MemoryUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
  });

  final int versionCode;
  final String versionName;
  final Uri apkUrl;
  final String sha256;
  final String notes;

  factory MemoryUpdateInfo.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final versionCode = json['versionCode'];
    final versionName = json['versionName'];
    final apkUrl = Uri.tryParse(json['apkUrl'] as String? ?? '');
    final sha256 = (json['sha256'] as String? ?? '').trim().toUpperCase();
    final notes = (json['notes'] as String? ?? '').trim();
    if (schemaVersion != 1 ||
        versionCode is! int ||
        versionCode < 1 ||
        versionName is! String ||
        versionName.trim().isEmpty ||
        apkUrl == null ||
        apkUrl.scheme != 'https' ||
        apkUrl.host != 'github.com' ||
        !apkUrl.path.startsWith(
          '/Glandy-T/memory-hub-ios/releases/download/',
        ) ||
        !RegExp(r'^[0-9A-F]{64}$').hasMatch(sha256)) {
      throw const FormatException('更新清单格式无效');
    }
    return MemoryUpdateInfo(
      versionCode: versionCode,
      versionName: versionName.trim(),
      apkUrl: apkUrl,
      sha256: sha256,
      notes: notes,
    );
  }
}

abstract interface class MemoryUpdatePlatform {
  Future<int> currentBuildNumber();
  Future<UpdateInstallResult> downloadAndInstall(MemoryUpdateInfo update);
}

class AndroidMemoryUpdatePlatform implements MemoryUpdatePlatform {
  const AndroidMemoryUpdatePlatform();

  static const _channel = MethodChannel('com.glandy.memoryhub/update');

  @override
  Future<int> currentBuildNumber() async {
    final value = await _channel.invokeMethod<int>('currentBuildNumber');
    if (value == null || value < 1) {
      throw const MemoryUpdateException('无法读取当前应用版本');
    }
    return value;
  }

  @override
  Future<UpdateInstallResult> downloadAndInstall(
    MemoryUpdateInfo update,
  ) async {
    try {
      final value = await _channel.invokeMethod<String>('downloadAndInstall', {
        'url': update.apkUrl.toString(),
        'sha256': update.sha256,
      });
      return switch (value) {
        'installerOpened' => UpdateInstallResult.installerOpened,
        'permissionRequired' => UpdateInstallResult.permissionRequired,
        _ => throw const MemoryUpdateException('系统没有返回有效的安装状态'),
      };
    } on PlatformException catch (error) {
      throw MemoryUpdateException(error.message ?? '更新下载或校验失败');
    }
  }
}

class MemoryUpdateService extends ChangeNotifier {
  MemoryUpdateService({
    http.Client? client,
    MemoryUpdatePlatform? platform,
    Uri? latestReleaseApi,
  }) : _client = client ?? http.Client(),
       _platform = platform ?? const AndroidMemoryUpdatePlatform(),
       _latestReleaseApi =
           latestReleaseApi ?? Uri.parse(_defaultLatestReleaseApi);

  final http.Client _client;
  final MemoryUpdatePlatform _platform;
  final Uri _latestReleaseApi;

  MemoryUpdateInfo? _available;
  bool _checking = false;
  bool _installing = false;
  bool _checked = false;
  String? _error;
  DateTime? _lastCheckedAt;

  MemoryUpdateInfo? get available => _available;
  bool get checking => _checking;
  bool get installing => _installing;
  bool get checked => _checked;
  String? get error => _error;

  Future<MemoryUpdateInfo?> check({bool silent = false}) async {
    if (_checking) return _available;
    final lastCheckedAt = _lastCheckedAt;
    if (silent &&
        lastCheckedAt != null &&
        DateTime.now().difference(lastCheckedAt) < const Duration(hours: 1)) {
      return _available;
    }
    _checking = true;
    if (!silent) _error = null;
    notifyListeners();
    try {
      final currentBuild = await _platform.currentBuildNumber();
      final releaseResponse = await _client
          .get(
            _latestReleaseApi,
            headers: const {
              'accept': 'application/vnd.github+json',
              'user-agent': 'MemoryHubAndroidUpdater/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (releaseResponse.statusCode == 404) {
        _available = null;
        _error = null;
        _checked = true;
        _lastCheckedAt = DateTime.now();
        return null;
      }
      if (releaseResponse.statusCode != 200) {
        throw const MemoryUpdateException('暂时无法检查更新');
      }
      final release = _decodeObject(utf8.decode(releaseResponse.bodyBytes));
      final assets = release['assets'];
      if (assets is! List) {
        throw const MemoryUpdateException('更新发布信息不完整');
      }
      Uri? manifestUrl;
      for (final value in assets) {
        if (value is! Map) continue;
        final asset = Map<String, Object?>.from(value);
        if (asset['name'] == _manifestAssetName) {
          manifestUrl = Uri.tryParse(
            asset['browser_download_url'] as String? ?? '',
          );
          break;
        }
      }
      if (manifestUrl == null || manifestUrl.scheme != 'https') {
        throw const MemoryUpdateException('更新清单尚未发布');
      }
      final manifestResponse = await _client
          .get(
            manifestUrl,
            headers: const {'user-agent': 'MemoryHubAndroidUpdater/1.0'},
          )
          .timeout(const Duration(seconds: 15));
      if (manifestResponse.statusCode != 200) {
        throw const MemoryUpdateException('更新清单下载失败');
      }
      final update = MemoryUpdateInfo.fromJson(
        _decodeObject(utf8.decode(manifestResponse.bodyBytes)),
      );
      _available = update.versionCode > currentBuild ? update : null;
      _error = null;
      _checked = true;
      _lastCheckedAt = DateTime.now();
      return _available;
    } on TimeoutException {
      _error = '检查更新超时，请稍后重试';
      if (!silent) throw MemoryUpdateException(_error!);
      return null;
    } on MemoryUpdateException catch (error) {
      _error = error.message;
      if (!silent) rethrow;
      return null;
    } on FormatException {
      _error = '更新信息无法识别';
      if (!silent) throw MemoryUpdateException(_error!);
      return null;
    } on Object {
      _error = '暂时无法检查更新';
      if (!silent) throw MemoryUpdateException(_error!);
      return null;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<UpdateInstallResult> installAvailable() async {
    final update = _available;
    if (update == null) {
      throw const MemoryUpdateException('当前没有可安装的新版本');
    }
    if (_installing) {
      throw const MemoryUpdateException('更新正在下载');
    }
    _installing = true;
    _error = null;
    notifyListeners();
    try {
      return await _platform.downloadAndInstall(update);
    } on MemoryUpdateException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  Map<String, Object?> _decodeObject(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('expected object');
    return Map<String, Object?>.from(decoded);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

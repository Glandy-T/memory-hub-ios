import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/intake_candidate.dart';

abstract interface class MemorySecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureMemorySecretStore implements MemorySecretStore {
  const SecureMemorySecretStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class IntakeConnectionFilePicker {
  Future<String?> pick();
}

class SystemIntakeConnectionFilePicker implements IntakeConnectionFilePicker {
  const SystemIntakeConnectionFilePicker();

  @override
  Future<String?> pick() async {
    final path = await FlutterFileDialog.pickFile(
      params: const OpenFileDialogParams(
        dialogType: OpenFileDialogType.document,
        allowedUtiTypes: ['public.json', 'public.text'],
        fileExtensionsFilter: ['json'],
        mimeTypesFilter: ['application/json', 'text/plain'],
        copyFileToCacheDir: true,
      ),
    );
    if (path == null) return null;
    final file = File(path);
    if (await file.length() > 16 * 1024) {
      throw const FormatException('连接文件异常过大');
    }
    return file.readAsString();
  }
}

class MemoryIntakeException implements Exception {
  const MemoryIntakeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MemoryIntakeService extends ChangeNotifier {
  MemoryIntakeService._(this._store, this._client);

  static const _baseUrlKey = 'memory-hub-intake-base-url';
  static const _deviceTokenKey = 'memory-hub-intake-device-token';
  static const _siteTokenKey = 'memory-hub-intake-site-token';

  final MemorySecretStore _store;
  final http.Client _client;
  IntakeConnection? _connection;
  List<IntakeCandidate> _items = const [];
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdatedAt;

  bool get connected => _connection != null;
  bool get refreshing => _refreshing;
  String? get error => _error;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  List<IntakeCandidate> get items => List.unmodifiable(_items);
  int get pendingCount => _items.length;

  static Future<MemoryIntakeService> create({
    MemorySecretStore? store,
    http.Client? client,
    bool refreshOnCreate = true,
  }) async {
    final service = MemoryIntakeService._(
      store ?? const SecureMemorySecretStore(),
      client ?? http.Client(),
    );
    await service._loadConnection();
    if (refreshOnCreate && service.connected) {
      await service.refresh(silent: true);
    }
    return service;
  }

  static MemoryIntakeService disabled() =>
      MemoryIntakeService._(_MemoryOnlySecretStore(), http.Client());

  Future<void> _loadConnection() async {
    final baseUrl = await _store.read(_baseUrlKey);
    final deviceToken = await _store.read(_deviceTokenKey);
    final siteToken = await _store.read(_siteTokenKey);
    if (baseUrl == null || deviceToken == null || siteToken == null) return;
    _connection = IntakeConnection(
      baseUrl: baseUrl,
      deviceToken: deviceToken,
      siteBypassToken: siteToken,
    );
  }

  Future<void> connectFromJson(String raw) async {
    late final IntakeConnection connection;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('连接文件格式无效');
      }
      connection = IntakeConnection.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('连接文件格式无效');
    }
    await _store.write(_baseUrlKey, connection.baseUrl);
    await _store.write(_deviceTokenKey, connection.deviceToken);
    await _store.write(_siteTokenKey, connection.siteBypassToken);
    _connection = connection;
    _error = null;
    notifyListeners();
    try {
      await refresh();
    } on Object {
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await Future.wait([
      _store.delete(_baseUrlKey),
      _store.delete(_deviceTokenKey),
      _store.delete(_siteTokenKey),
    ]);
    _connection = null;
    _items = const [];
    _error = null;
    _lastUpdatedAt = null;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    final connection = _connection;
    if (connection == null || _refreshing) return;
    _refreshing = true;
    if (!silent) _error = null;
    notifyListeners();
    try {
      final response = await _client
          .get(
            Uri.parse('${connection.baseUrl}/api/device/intake'),
            headers: _headers(connection),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decodeObject(response.body);
      if (response.statusCode != 200) {
        throw MemoryIntakeException(body['message'] as String? ?? '待收录同步失败');
      }
      final rawItems = body['items'];
      if (rawItems is! List<Object?>) {
        throw const MemoryIntakeException('云端返回了无法识别的内容');
      }
      _items =
          rawItems
              .map(
                (value) => IntakeCandidate.fromJson(
                  Map<String, Object?>.from(value! as Map),
                ),
              )
              .toList()
            ..sort(
              (left, right) => right.receivedAt.compareTo(left.receivedAt),
            );
      _error = null;
      _lastUpdatedAt = DateTime.now();
    } on TimeoutException {
      _error = '连接超时，请检查网络后重试';
      throw MemoryIntakeException(_error!);
    } on MemoryIntakeException catch (error) {
      _error = error.message;
      rethrow;
    } on FormatException catch (error) {
      _error = '待收录内容格式异常：${error.message}';
      throw MemoryIntakeException(_error!);
    } on Object {
      _error = '暂时无法连接待收录服务';
      throw MemoryIntakeException(_error!);
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> decide(IntakeCandidate candidate, {required bool accept}) async {
    final connection = _connection;
    if (connection == null) {
      throw const MemoryIntakeException('Android 尚未连接待收录服务');
    }
    try {
      final response = await _client
          .post(
            Uri.parse('${connection.baseUrl}/api/device/intake'),
            headers: {
              ..._headers(connection),
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'id': candidate.id,
              'action': accept ? 'accept' : 'ignore',
              if (accept) 'item': candidate.reviewJson(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decodeObject(response.body);
      if (response.statusCode != 200) {
        throw MemoryIntakeException(body['message'] as String? ?? '审核结果没有同步');
      }
      _items = _items.where((item) => item.id != candidate.id).toList();
      _error = null;
      _lastUpdatedAt = DateTime.now();
      notifyListeners();
    } on TimeoutException {
      throw const MemoryIntakeException('连接超时，审核结果尚未同步');
    } on MemoryIntakeException {
      rethrow;
    } on Object {
      throw const MemoryIntakeException('审核结果尚未同步，请重试');
    }
  }

  Map<String, String> _headers(IntakeConnection connection) => {
    'authorization': 'Bearer ${connection.deviceToken}',
    'OAI-Sites-Authorization': 'Bearer ${connection.siteBypassToken}',
    'accept': 'application/json',
  };

  Map<String, Object?> _decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } on FormatException {
      // Converted into a stable product error below.
    }
    throw const MemoryIntakeException('云端返回了无法识别的内容');
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _MemoryOnlySecretStore implements MemorySecretStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

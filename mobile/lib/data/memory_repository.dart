import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_data.dart';

abstract interface class MemoryRepository {
  Future<MemoryData> load();
  Future<void> save(MemoryData data);
}

class MemoryDataCorruptionException implements Exception {
  const MemoryDataCorruptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MemoryPersistenceException implements Exception {
  const MemoryPersistenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SharedPreferencesMemoryRepository implements MemoryRepository {
  static const _databaseKey = 'memory-hub-mobile-database-v1';
  static const _backupKey = 'memory-hub-mobile-database-backup-v1';
  static const _quarantineKey = 'memory-hub-mobile-database-damaged-v1';

  @override
  Future<MemoryData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_databaseKey);
    if (raw == null || raw.isEmpty) {
      final backup = preferences.getString(_backupKey);
      if (backup == null || backup.isEmpty) return MemoryData.initial();
      final recovered = _decode(backup);
      await _writeChecked(preferences, _databaseKey, backup);
      return recovered;
    }
    try {
      return _decode(raw);
    } on Object {
      await preferences.setString(_quarantineKey, raw);
      final backup = preferences.getString(_backupKey);
      if (backup != null && backup.isNotEmpty) {
        MemoryData? recovered;
        try {
          recovered = _decode(backup);
        } on Object {
          // The primary copy remains quarantined and neither source is replaced.
        }
        if (recovered != null) {
          await _writeChecked(preferences, _databaseKey, backup);
          return recovered;
        }
      }
      throw const MemoryDataCorruptionException(
        '本地数据无法读取，应用已停止写入以保护原始内容。请先导出损坏数据或从备份恢复。',
      );
    }
  }

  @override
  Future<void> save(MemoryData data) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(_databaseKey);
    final encoded = jsonEncode(data.toJson());
    if (current != null && current.isNotEmpty) {
      var currentIsValid = false;
      try {
        _decode(current);
        currentIsValid = true;
      } on Object {
        await preferences.setString(_quarantineKey, current);
      }
      if (currentIsValid) {
        await _writeChecked(preferences, _backupKey, current);
      }
    }
    await _writeChecked(preferences, _databaseKey, encoded);
    if (preferences.getString(_backupKey) == null) {
      await _writeChecked(preferences, _backupKey, encoded);
    }
  }

  MemoryData _decode(String raw) =>
      MemoryData.fromJson(jsonDecode(raw) as Map<String, Object?>);

  Future<void> _writeChecked(
    SharedPreferences preferences,
    String key,
    String value,
  ) async {
    final written = await preferences.setString(key, value);
    if (!written || preferences.getString(key) != value) {
      throw const MemoryPersistenceException('本地数据没有安全写入，请重试。');
    }
  }
}

class InMemoryRepository implements MemoryRepository {
  InMemoryRepository([MemoryData? seed]) : _data = seed ?? MemoryData.initial();

  MemoryData _data;

  @override
  Future<MemoryData> load() async => _data;

  @override
  Future<void> save(MemoryData data) async => _data = data;
}

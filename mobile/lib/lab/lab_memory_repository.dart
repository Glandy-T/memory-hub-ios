import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/memory_repository.dart';
import '../models/memory_data.dart';

class LabMemoryRepository implements MemoryRepository {
  static const _primaryKey = 'memory-hub-lab-database-v1';
  static const _backupKey = 'memory-hub-lab-database-backup-v1';

  @override
  Future<MemoryData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_primaryKey);
    if (raw == null || raw.isEmpty) return MemoryData.initial();
    try {
      return MemoryData.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      final backup = preferences.getString(_backupKey);
      if (backup == null || backup.isEmpty) {
        throw const MemoryDataCorruptionException('实验版本地数据无法读取。');
      }
      return MemoryData.fromJson(jsonDecode(backup) as Map<String, Object?>);
    }
  }

  @override
  Future<void> save(MemoryData data) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(_primaryKey);
    if (current != null && current.isNotEmpty) {
      await preferences.setString(_backupKey, current);
    }
    final written = await preferences.setString(
      _primaryKey,
      jsonEncode(data.toJson()),
    );
    if (!written) throw const MemoryPersistenceException('实验版数据没有安全写入。');
  }
}

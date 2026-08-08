import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/memory_data.dart';

abstract interface class MemoryRepository {
  Future<MemoryData> load();
  Future<void> save(MemoryData data);
}

class SharedPreferencesMemoryRepository implements MemoryRepository {
  static const _databaseKey = 'memory-hub-mobile-database-v1';

  @override
  Future<MemoryData> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_databaseKey);
    if (raw == null || raw.isEmpty) return MemoryData.initial();
    try {
      return MemoryData.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return MemoryData.initial();
    }
  }

  @override
  Future<void> save(MemoryData data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_databaseKey, jsonEncode(data.toJson()));
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

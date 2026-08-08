import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/core/theme/memory_theme.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/features/profile/profile_tools_screens.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/services/memory_backup_file_service.dart';
import 'package:memory_hub/state/memory_controller.dart';

void main() {
  testWidgets('exports a complete backup through the system file service', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    final files = _FakeBackupFileService();
    await _pumpBackupScreen(tester, controller, files);

    await tester.tap(find.text('保存备份文件'));
    await tester.pumpAndSettle();

    expect(files.savedContents, contains('"schemaVersion":8'));
    expect(find.text('备份文件已保存'), findsOneWidget);
  });

  testWidgets('validates and confirms a picked backup before replacement', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    final incoming = MemoryData(
      tasks: [
        MemoryTask(
          id: 'imported-task',
          title: '从文件导入的事项',
          date: DateTime(2026, 8, 8),
          updatedAt: DateTime(2026, 8, 8),
        ),
      ],
    );
    final files = _FakeBackupFileService(
      picked: BackupFileSelection(
        name: 'memory-hub-backup.json',
        contents: jsonEncode(incoming.toJson()),
      ),
    );
    await _pumpBackupScreen(tester, controller, files);

    await tester.tap(find.text('从文件恢复'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('替换当前数据？'), findsOneWidget);
    expect(find.textContaining('memory-hub-backup.json'), findsOneWidget);
    expect(controller.data.tasks, isEmpty);

    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(controller.data.tasks.single.title, '从文件导入的事项');
    expect(find.text('备份已恢复'), findsOneWidget);
  });

  testWidgets('rejects invalid JSON without showing replacement confirmation', (
    tester,
  ) async {
    final controller = await MemoryController.create(InMemoryRepository());
    final files = _FakeBackupFileService(
      picked: const BackupFileSelection(
        name: 'broken.json',
        contents: '{broken',
      ),
    );
    await _pumpBackupScreen(tester, controller, files);

    await tester.tap(find.text('从文件恢复'));
    await tester.pumpAndSettle();

    expect(find.text('替换当前数据？'), findsNothing);
    expect(find.text('无法恢复：文件内容不是有效的 JSON'), findsOneWidget);
  });
}

Future<void> _pumpBackupScreen(
  WidgetTester tester,
  MemoryController controller,
  MemoryBackupFileService files,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMemoryTheme(),
      home: BackupScreen(controller: controller, fileService: files),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBackupFileService extends MemoryBackupFileService {
  _FakeBackupFileService({this.picked});

  final BackupFileSelection? picked;
  String? savedContents;

  @override
  Future<BackupFileSelection?> pick() async => picked;

  @override
  Future<bool> save(String contents) async {
    savedContents = contents;
    return true;
  }
}

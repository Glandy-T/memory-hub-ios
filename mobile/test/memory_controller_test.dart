import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/state/memory_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MemoryController', () {
    test('uses a 4am boundary for the effective home date', () async {
      final controller = await MemoryController.create(InMemoryRepository());

      expect(
        controller.effectiveToday(DateTime(2026, 8, 8, 3, 59)),
        DateTime(2026, 8, 7),
      );
      expect(
        controller.effectiveToday(DateTime(2026, 8, 8, 4)),
        DateTime(2026, 8, 8),
      );
    });

    test(
      'persists task status and keeps skipped items in calendar history',
      () async {
        final repository = InMemoryRepository();
        final controller = await MemoryController.create(repository);
        final date = DateTime(2026, 8, 8);

        await controller.addTask(title: '给诊所打电话', date: date);
        final id = controller.tasksFor(date).single.id;
        await controller.setTaskStatus(id, MemoryTaskStatus.skipped);

        final restored = await MemoryController.create(repository);
        expect(restored.tasksFor(date), hasLength(1));
        expect(restored.tasksFor(date).single.status, MemoryTaskStatus.skipped);
        expect(restored.tasksFor(date, activeOnly: true), isEmpty);
      },
    );

    test('edits and soft deletes a calendar task', () async {
      final repository = InMemoryRepository();
      final controller = await MemoryController.create(repository);
      final originalDate = DateTime(2026, 8, 8);

      await controller.addTask(title: '旧标题', date: originalDate);
      final id = controller.tasksFor(originalDate).single.id;
      await controller.updateTask(
        id: id,
        title: '新标题',
        note: '带材料',
        date: DateTime(2026, 8, 9),
        minutesFromMidnight: 9 * 60 + 30,
      );

      expect(controller.tasksFor(originalDate), isEmpty);
      expect(controller.tasksFor(DateTime(2026, 8, 9)).single.title, '新标题');
      await controller.setTaskStatus(id, MemoryTaskStatus.deleted);
      expect(controller.tasksFor(DateTime(2026, 8, 9)), isEmpty);

      final restored = await MemoryController.create(repository);
      expect(restored.data.tasks.single.status, MemoryTaskStatus.deleted);
    });

    test(
      'projects period rules by date and persists only operated instances',
      () async {
        final repository = InMemoryRepository();
        final controller = await MemoryController.create(repository);
        final monday = DateTime(2026, 8, 10);
        await controller.addPeriodRule(
          title: '每周整理药盒',
          startDate: monday,
          weekdays: {DateTime.monday},
        );

        final projected = controller.tasksFor(monday).single;
        expect(projected.title, '每周整理药盒');
        expect(controller.data.tasks, isEmpty);
        await controller.setTaskStatus(
          projected.id,
          MemoryTaskStatus.completed,
        );

        expect(controller.data.tasks.single.status, MemoryTaskStatus.completed);
        expect(controller.tasksFor(monday), hasLength(1));
        final nextMonday = monday.add(const Duration(days: 7));
        expect(
          controller.tasksFor(nextMonday).single.status,
          MemoryTaskStatus.active,
        );

        await controller.deletePeriodRule(
          controller.data.periodRules.single.id,
        );
        expect(controller.tasksFor(nextMonday), isEmpty);
        expect(
          controller.tasksFor(monday).single.status,
          MemoryTaskStatus.completed,
        );
      },
    );

    test(
      'creates a document, reminder membership, and formal record',
      () async {
        final controller = await MemoryController.create(InMemoryRepository());
        const categoryId = 'memory-hub-default-category';

        await controller.addDocument(categoryId, '旅行证件放在哪里');
        final document = controller.data.documents.single;
        await controller.toggleDocumentReminder(document.id, true);
        await controller.addRecord(document.id, '复印件在书桌抽屉的蓝色文件夹里。');

        final updated = controller.data.documents.single;
        expect(updated.inReminderPool, isTrue);
        expect(updated.records.single.body, contains('蓝色文件夹'));
      },
    );

    test(
      'renames and soft deletes documents and keeps record history',
      () async {
        final controller = await MemoryController.create(InMemoryRepository());
        const categoryId = 'memory-hub-default-category';

        await controller.addDocument(categoryId, '旧标题');
        final documentId = controller.data.documents.single.id;
        await controller.addRecord(documentId, '第一版内容');
        final recordId = controller.data.documents.single.records.single.id;
        await controller.updateRecord(documentId, recordId, '第二版内容');

        final editedRecord = controller.data.documents.single.records.single;
        expect(editedRecord.body, '第二版内容');
        expect(editedRecord.previousBodies, ['第一版内容']);

        await controller.renameDocument(documentId, '新标题');
        expect(controller.data.documents.single.title, '新标题');
        await controller.deleteRecord(documentId, recordId);
        expect(controller.data.documents.single.records.single.deleted, isTrue);
        await controller.deleteDocument(documentId);
        expect(controller.data.documents.single.deleted, isTrue);
        expect(controller.data.documents.single.inReminderPool, isFalse);
      },
    );

    test(
      'persists an unfinished record draft and clears it on publish',
      () async {
        final repository = InMemoryRepository();
        final controller = await MemoryController.create(repository);
        await controller.addDocument('memory-hub-default-category', '草稿测试');
        final documentId = controller.data.documents.single.id;

        await controller.setDocumentDraft(documentId, '还没有写完的内容');
        final restored = await MemoryController.create(repository);
        expect(restored.data.documents.single.draftBody, '还没有写完的内容');

        await restored.addRecord(documentId, '正式发布的内容');
        expect(restored.data.documents.single.draftBody, isNull);
        expect(restored.data.documents.single.records.single.body, '正式发布的内容');
      },
    );

    test('does not present an unsaved mutation as committed', () async {
      final controller = await MemoryController.create(_FailingRepository());

      await controller.addTask(title: '不能丢失的事项', date: DateTime(2026, 8, 8));

      expect(controller.data.tasks, isEmpty);
      expect(controller.persistenceError, isNotNull);
    });

    test(
      'reorders categories and safely migrates documents on deletion',
      () async {
        final controller = await MemoryController.create(InMemoryRepository());
        await controller.addCategory('证件', 0xFFFFCA3A);
        await controller.addCategory('健康', 0xFF41C7BE);
        final categories = controller.data.categories
            .where((category) => !category.isDefault)
            .toList();
        final documentsId = categories.first.id;
        await controller.addDocument(documentsId, '护照放在哪里');

        await controller.reorderCategories([
          categories.last.id,
          categories.first.id,
          'memory-hub-default-category',
        ]);
        expect(
          controller.data.categories
              .where((category) => category.id == categories.last.id)
              .single
              .order,
          0,
        );

        await controller.deleteCategory(documentsId, deleteDocuments: false);
        expect(
          controller.data.documents.single.categoryId,
          'memory-hub-default-category',
        );
        expect(controller.data.documents.single.deleted, isFalse);
      },
    );

    test(
      'restores cascade-deleted categories with their reminder documents',
      () async {
        final controller = await MemoryController.create(InMemoryRepository());
        await controller.addCategory('证件', 0xFFFFCA3A);
        final category = controller.data.categories.firstWhere(
          (value) => value.name == '证件',
        );
        await controller.addDocument(category.id, '护照信息');
        final documentId = controller.data.documents.single.id;
        await controller.toggleDocumentReminder(documentId, true);

        await controller.deleteCategory(category.id, deleteDocuments: true);
        expect(controller.data.documents.single.deleted, isTrue);
        expect(
          controller.data.documents.single.deletedWithCategoryId,
          category.id,
        );
        await controller.restoreCategory(category.id);

        expect(
          controller.data.categories
              .firstWhere((value) => value.id == category.id)
              .deleted,
          isFalse,
        );
        expect(controller.data.documents.single.deleted, isFalse);
        expect(controller.data.documents.single.inReminderPool, isTrue);
        expect(controller.data.documents.single.categoryId, category.id);
      },
    );

    test('persists fridge, shopping, and freely located items', () async {
      final repository = InMemoryRepository();
      final controller = await MemoryController.create(repository);

      await controller.addFridgeItem(
        name: '牛奶',
        quantity: '1 盒',
        storage: FridgeStorage.chilled,
      );
      await controller.removeFridgeItem(
        controller.data.fridgeItems.single.id,
        addToShopping: true,
      );
      await controller.addLocatedItem(
        name: '备用钥匙',
        location: '玄关右侧蓝色盒子',
        quantity: '1 把',
      );

      final restored = await MemoryController.create(repository);
      expect(restored.data.fridgeItems.single.deleted, isTrue);
      expect(restored.data.shoppingItems.single.name, '牛奶');
      expect(restored.data.locatedItems.single.location, contains('蓝色盒子'));
    });
  });

  test('migrates schema 1 data with empty life collections', () {
    final migrated = MemoryData.fromJson(const {
      'schemaVersion': 1,
      'tasks': <Object?>[],
      'categories': <Object?>[],
      'documents': <Object?>[],
    });

    expect(migrated.fridgeItems, isEmpty);
    expect(migrated.shoppingItems, isEmpty);
    expect(migrated.locatedItems, isEmpty);
    expect(migrated.categories.single.isDefault, isTrue);
  });

  test('rejects a future database schema', () {
    expect(
      () => MemoryData.fromJson(const {'schemaVersion': 99}),
      throwsFormatException,
    );
  });

  group('SharedPreferencesMemoryRepository', () {
    const primaryKey = 'memory-hub-mobile-database-v1';
    const backupKey = 'memory-hub-mobile-database-backup-v1';

    test('rotates the last valid primary copy into backup', () async {
      final initial = jsonEncode(MemoryData.initial().toJson());
      SharedPreferences.setMockInitialValues({primaryKey: initial});
      final repository = SharedPreferencesMemoryRepository();
      final next = MemoryData.initial().copyWith(
        tasks: [
          MemoryTask(
            id: 'task-1',
            title: '备份测试',
            date: DateTime(2026, 8, 8),
            updatedAt: DateTime(2026, 8, 8),
          ),
        ],
      );

      await repository.save(next);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(backupKey), initial);
      expect((await repository.load()).tasks.single.title, '备份测试');
    });

    test('recovers a damaged primary copy from the valid backup', () async {
      final backup = jsonEncode(MemoryData.initial().toJson());
      SharedPreferences.setMockInitialValues({
        primaryKey: '{damaged',
        backupKey: backup,
      });
      final repository = SharedPreferencesMemoryRepository();

      final recovered = await repository.load();

      expect(recovered.categories.single.isDefault, isTrue);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(primaryKey), backup);
    });

    test('stops before replacing data when both copies are damaged', () async {
      SharedPreferences.setMockInitialValues({
        primaryKey: '{damaged-primary',
        backupKey: '{damaged-backup',
      });
      final repository = SharedPreferencesMemoryRepository();

      expect(repository.load, throwsA(isA<MemoryDataCorruptionException>()));
    });
  });
}

class _FailingRepository implements MemoryRepository {
  @override
  Future<MemoryData> load() async => MemoryData.initial();

  @override
  Future<void> save(MemoryData data) async {
    throw const MemoryPersistenceException('测试写入失败');
  }
}

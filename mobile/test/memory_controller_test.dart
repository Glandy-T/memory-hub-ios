import 'package:flutter_test/flutter_test.dart';
import 'package:memory_hub/data/memory_repository.dart';
import 'package:memory_hub/models/memory_data.dart';
import 'package:memory_hub/state/memory_controller.dart';

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
}

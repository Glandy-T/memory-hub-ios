import 'package:flutter/foundation.dart';

import '../data/memory_repository.dart';
import '../models/memory_data.dart';

class MemoryController extends ChangeNotifier {
  MemoryController._(this._repository, this._data);

  final MemoryRepository _repository;
  MemoryData _data;

  MemoryData get data => _data;

  static Future<MemoryController> create(MemoryRepository repository) async {
    return MemoryController._(repository, await repository.load());
  }

  DateTime effectiveToday([DateTime? clock]) {
    final now = clock ?? DateTime.now();
    final shifted = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  List<MemoryTask> tasksFor(DateTime date, {bool activeOnly = false}) {
    final tasks = _data.tasks.where((task) {
      return sameCalendarDay(task.date, date) &&
          task.status != MemoryTaskStatus.deleted &&
          (!activeOnly || task.status == MemoryTaskStatus.active);
    }).toList();
    tasks.sort((left, right) {
      final leftTime = left.minutesFromMidnight ?? 24 * 60;
      final rightTime = right.minutesFromMidnight ?? 24 * 60;
      return leftTime.compareTo(rightTime);
    });
    return tasks;
  }

  List<MemoryTask> get todayTasks =>
      tasksFor(effectiveToday(), activeOnly: true);

  Future<void> addTask({
    required String title,
    required DateTime date,
    String? note,
    int? minutesFromMidnight,
  }) async {
    final trimmedNote = note?.trim();
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        tasks: [
          ..._data.tasks,
          MemoryTask(
            id: newMemoryId('task'),
            title: title.trim(),
            note: trimmedNote == null || trimmedNote.isEmpty
                ? null
                : trimmedNote,
            date: DateTime(date.year, date.month, date.day),
            minutesFromMidnight: minutesFromMidnight,
            updatedAt: now,
          ),
        ],
      ),
    );
  }

  Future<void> updateTask({
    required String id,
    required String title,
    required DateTime date,
    String? note,
    int? minutesFromMidnight,
  }) async {
    final trimmedNote = note?.trim();
    await _commit(
      _data.copyWith(
        tasks: [
          for (final task in _data.tasks)
            if (task.id == id)
              task.copyWith(
                title: title.trim(),
                note: trimmedNote == null || trimmedNote.isEmpty
                    ? null
                    : trimmedNote,
                clearNote: trimmedNote == null || trimmedNote.isEmpty,
                date: DateTime(date.year, date.month, date.day),
                minutesFromMidnight: minutesFromMidnight,
                clearTime: minutesFromMidnight == null,
                updatedAt: DateTime.now(),
              )
            else
              task,
        ],
      ),
    );
  }

  Future<void> setTaskStatus(String id, MemoryTaskStatus status) async {
    await _commit(
      _data.copyWith(
        tasks: [
          for (final task in _data.tasks)
            if (task.id == id)
              task.copyWith(status: status, updatedAt: DateTime.now())
            else
              task,
        ],
      ),
    );
  }

  Future<void> addCategory(String name, int colorValue) async {
    final active = _data.categories.where((category) => !category.deleted);
    await _commit(
      _data.copyWith(
        categories: [
          ..._data.categories,
          MemoryCategory(
            id: newMemoryId('category'),
            name: name.trim(),
            colorValue: colorValue,
            order: active.length,
          ),
        ],
      ),
    );
  }

  Future<void> renameCategory(String id, String name) async {
    await _commit(
      _data.copyWith(
        categories: [
          for (final category in _data.categories)
            if (category.id == id)
              category.copyWith(name: name.trim())
            else
              category,
        ],
      ),
    );
  }

  Future<void> updateCategory(
    String id, {
    required String name,
    required int colorValue,
  }) async {
    await _commit(
      _data.copyWith(
        categories: [
          for (final category in _data.categories)
            if (category.id == id)
              category.copyWith(name: name.trim(), colorValue: colorValue)
            else
              category,
        ],
      ),
    );
  }

  Future<void> reorderCategories(List<String> orderedIds) async {
    final orderById = <String, int>{
      for (var index = 0; index < orderedIds.length; index++)
        orderedIds[index]: index,
    };
    await _commit(
      _data.copyWith(
        categories: [
          for (final category in _data.categories)
            category.copyWith(order: orderById[category.id] ?? category.order),
        ],
      ),
    );
  }

  Future<void> deleteCategory(
    String id, {
    required bool deleteDocuments,
  }) async {
    final category = _data.categories
        .where((value) => value.id == id)
        .firstOrNull;
    if (category == null || category.isDefault) return;
    final defaultCategory = _data.categories.firstWhere(
      (value) => value.isDefault,
      orElse: () => MemoryData.initial().categories.single,
    );
    await _commit(
      _data.copyWith(
        categories: [
          for (final value in _data.categories)
            if (value.id == id) value.copyWith(deleted: true) else value,
        ],
        documents: [
          for (final document in _data.documents)
            if (document.categoryId == id)
              document.copyWith(
                categoryId: deleteDocuments
                    ? document.categoryId
                    : defaultCategory.id,
                deleted: deleteDocuments ? true : document.deleted,
                inReminderPool: deleteDocuments
                    ? false
                    : document.inReminderPool,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> addDocument(String categoryId, String title) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        documents: [
          ..._data.documents,
          MemoryDocument(
            id: newMemoryId('document'),
            categoryId: categoryId,
            title: title.trim(),
            updatedAt: now,
          ),
        ],
      ),
    );
  }

  Future<void> toggleDocumentReminder(String id, bool selected) async {
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == id)
              document.copyWith(
                inReminderPool: selected,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> addRecord(String documentId, String body) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == documentId)
              document.copyWith(
                records: [
                  ...document.records,
                  MemoryRecord(
                    id: newMemoryId('record'),
                    body: body.trim(),
                    createdAt: now,
                  ),
                ],
                updatedAt: now,
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> addFridgeItem({
    required String name,
    required String quantity,
    required FridgeStorage storage,
    DateTime? expiryDate,
    String? note,
  }) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        fridgeItems: [
          ..._data.fridgeItems,
          FridgeItem(
            id: newMemoryId('fridge'),
            name: name.trim(),
            quantity: quantity.trim().isEmpty ? '1' : quantity.trim(),
            storage: storage,
            expiryDate: expiryDate,
            note: _optionalText(note),
            updatedAt: now,
          ),
        ],
      ),
    );
  }

  Future<void> removeFridgeItem(String id, {bool addToShopping = false}) async {
    final item = _data.fridgeItems.where((value) => value.id == id).firstOrNull;
    if (item == null) return;
    await _commit(
      _data.copyWith(
        fridgeItems: [
          for (final value in _data.fridgeItems)
            if (value.id == id)
              value.copyWith(deleted: true, updatedAt: DateTime.now())
            else
              value,
        ],
        shoppingItems: addToShopping
            ? [
                ..._data.shoppingItems,
                ShoppingItem(id: newMemoryId('shopping'), name: item.name),
              ]
            : _data.shoppingItems,
      ),
    );
  }

  Future<void> addShoppingItem(String name) async => _commit(
    _data.copyWith(
      shoppingItems: [
        ..._data.shoppingItems,
        ShoppingItem(id: newMemoryId('shopping'), name: name.trim()),
      ],
    ),
  );

  Future<void> setShoppingBought(String id, bool bought) async => _commit(
    _data.copyWith(
      shoppingItems: [
        for (final item in _data.shoppingItems)
          if (item.id == id) item.copyWith(bought: bought) else item,
      ],
    ),
  );

  Future<void> addLocatedItem({
    required String name,
    required String location,
    required String quantity,
    String? note,
  }) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        locatedItems: [
          ..._data.locatedItems,
          LocatedItem(
            id: newMemoryId('item'),
            name: name.trim(),
            location: location.trim(),
            quantity: quantity.trim().isEmpty ? '1' : quantity.trim(),
            note: _optionalText(note),
            updatedAt: now,
          ),
        ],
      ),
    );
  }

  Future<void> deleteLocatedItem(String id) async => _commit(
    _data.copyWith(
      locatedItems: [
        for (final item in _data.locatedItems)
          if (item.id == id)
            item.copyWith(deleted: true, updatedAt: DateTime.now())
          else
            item,
      ],
    ),
  );

  Future<void> _commit(MemoryData next) async {
    _data = next;
    notifyListeners();
    await _repository.save(next);
  }
}

String? _optionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

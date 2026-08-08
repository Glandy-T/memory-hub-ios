import 'package:flutter/foundation.dart';

import '../data/memory_repository.dart';
import '../models/memory_data.dart';

class MemoryController extends ChangeNotifier {
  MemoryController._(this._repository, this._data);

  final MemoryRepository _repository;
  MemoryData _data;
  MemoryData? _pendingData;
  String? _persistenceError;

  MemoryData get data => _data;
  String? get persistenceError => _persistenceError;

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
    for (final rule in _data.periodRules) {
      final applies =
          rule.active &&
          !rule.deleted &&
          !date.isBefore(rule.startDate) &&
          (rule.endDate == null || !date.isAfter(rule.endDate!)) &&
          rule.weekdays.contains(date.weekday);
      final hasInstance = _data.tasks.any(
        (task) =>
            task.periodRuleId == rule.id && sameCalendarDay(task.date, date),
      );
      if (applies && !hasInstance) {
        tasks.add(
          MemoryTask(
            id: _periodInstanceId(rule.id, date),
            title: rule.title,
            date: DateTime(date.year, date.month, date.day),
            periodRuleId: rule.id,
            updatedAt: rule.updatedAt,
          ),
        );
      }
    }
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
    final existing = _data.tasks.any((task) => task.id == id);
    final virtualParts = existing ? null : _periodInstanceParts(id);
    final virtualRuleId = virtualParts?.$1;
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
          if (!existing && virtualRuleId != null)
            MemoryTask(
              id: newMemoryId('task'),
              title: title.trim(),
              note: trimmedNote == null || trimmedNote.isEmpty
                  ? null
                  : trimmedNote,
              date:
                  virtualParts?.$2 ?? DateTime(date.year, date.month, date.day),
              minutesFromMidnight: minutesFromMidnight,
              periodRuleId: virtualRuleId,
              updatedAt: DateTime.now(),
            ),
        ],
      ),
    );
  }

  Future<void> setTaskStatus(String id, MemoryTaskStatus status) async {
    final existing = _data.tasks.any((task) => task.id == id);
    final virtual = existing ? null : _periodInstanceParts(id);
    await _commit(
      _data.copyWith(
        tasks: [
          for (final task in _data.tasks)
            if (task.id == id)
              task.copyWith(status: status, updatedAt: DateTime.now())
            else
              task,
          if (!existing && virtual != null)
            MemoryTask(
              id: newMemoryId('task'),
              title:
                  _data.periodRules
                      .where((rule) => rule.id == virtual.$1)
                      .map((rule) => rule.title)
                      .firstOrNull ??
                  '周期事项',
              date: virtual.$2,
              status: status,
              periodRuleId: virtual.$1,
              updatedAt: DateTime.now(),
            ),
        ],
      ),
    );
  }

  Future<void> addPeriodRule({
    required String title,
    required DateTime startDate,
    DateTime? endDate,
    required Set<int> weekdays,
  }) async {
    await _commit(
      _data.copyWith(
        periodRules: [
          ..._data.periodRules,
          PeriodRule(
            id: newMemoryId('period'),
            title: title.trim(),
            startDate: DateTime(startDate.year, startDate.month, startDate.day),
            endDate: endDate == null
                ? null
                : DateTime(endDate.year, endDate.month, endDate.day),
            weekdays: weekdays,
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    );
  }

  Future<void> updatePeriodRule(
    String id, {
    required String title,
    required DateTime startDate,
    DateTime? endDate,
    required Set<int> weekdays,
    required bool active,
  }) async {
    await _commit(
      _data.copyWith(
        periodRules: [
          for (final rule in _data.periodRules)
            if (rule.id == id)
              rule.copyWith(
                title: title.trim(),
                startDate: startDate,
                endDate: endDate,
                clearEndDate: endDate == null,
                weekdays: weekdays,
                active: active,
                updatedAt: DateTime.now(),
              )
            else
              rule,
        ],
      ),
    );
  }

  Future<void> deletePeriodRule(String id) async {
    await _commit(
      _data.copyWith(
        periodRules: [
          for (final rule in _data.periodRules)
            if (rule.id == id)
              rule.copyWith(
                deleted: true,
                active: false,
                updatedAt: DateTime.now(),
              )
            else
              rule,
        ],
      ),
    );
  }

  Future<void> restorePeriodRule(String id) async {
    await _commit(
      _data.copyWith(
        periodRules: [
          for (final rule in _data.periodRules)
            if (rule.id == id)
              rule.copyWith(
                deleted: false,
                active: true,
                updatedAt: DateTime.now(),
              )
            else
              rule,
        ],
      ),
    );
  }

  Future<void> permanentlyDeletePeriodRule(String id) async {
    await _commit(
      _data.copyWith(
        periodRules: _data.periodRules.where((rule) => rule.id != id).toList(),
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
                deletedWithCategoryId: deleteDocuments ? id : null,
                clearCategoryDeletion: !deleteDocuments,
                reminderPoolBeforeDelete: deleteDocuments
                    ? document.inReminderPool
                    : document.reminderPoolBeforeDelete,
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
                clearReminderMute: !selected,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> setDocumentReminderMutedUntil(
    String id,
    DateTime? mutedUntil,
  ) async {
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == id)
              document.copyWith(
                reminderMutedUntil: mutedUntil,
                clearReminderMute: mutedUntil == null,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> renameDocument(String id, String title) async {
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == id)
              document.copyWith(title: title.trim(), updatedAt: DateTime.now())
            else
              document,
        ],
      ),
    );
  }

  Future<void> setDocumentArchived(String id, bool archived) async {
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == id)
              document.copyWith(
                archived: archived,
                inReminderPool: archived ? false : document.inReminderPool,
                clearReminderMute: archived,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> deleteDocument(String id) async {
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == id)
              document.copyWith(
                deleted: true,
                inReminderPool: false,
                clearReminderMute: true,
                clearCategoryDeletion: true,
                reminderPoolBeforeDelete: document.inReminderPool,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> restoreTask(String id) async =>
      setTaskStatus(id, MemoryTaskStatus.active);

  Future<void> permanentlyDeleteTask(String id) async {
    await _commit(
      _data.copyWith(
        tasks: _data.tasks.where((task) => task.id != id).toList(),
      ),
    );
  }

  Future<void> restoreCategory(String id) async {
    await _commit(
      _data.copyWith(
        categories: [
          for (final category in _data.categories)
            if (category.id == id)
              category.copyWith(deleted: false)
            else
              category,
        ],
        documents: [
          for (final document in _data.documents)
            if (document.deletedWithCategoryId == id)
              document.copyWith(
                deleted: false,
                inReminderPool: document.reminderPoolBeforeDelete,
                clearCategoryDeletion: true,
                reminderPoolBeforeDelete: false,
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> permanentlyDeleteCategory(String id) async {
    await _commit(
      _data.copyWith(
        categories: _data.categories
            .where((category) => category.id != id)
            .toList(),
        documents: _data.documents
            .where((document) => document.deletedWithCategoryId != id)
            .toList(),
      ),
    );
  }

  Future<void> restoreDocument(String id) async {
    final document = _data.documents
        .where((value) => value.id == id)
        .firstOrNull;
    if (document == null) return;
    final activeCategory = _data.categories.any(
      (category) => category.id == document.categoryId && !category.deleted,
    );
    final defaultCategory = _data.categories.firstWhere(
      (category) => category.isDefault,
      orElse: () => MemoryData.initial().categories.single,
    );
    await _commit(
      _data.copyWith(
        documents: [
          for (final value in _data.documents)
            if (value.id == id)
              value.copyWith(
                categoryId: activeCategory
                    ? value.categoryId
                    : defaultCategory.id,
                deleted: false,
                inReminderPool: value.reminderPoolBeforeDelete,
                clearCategoryDeletion: true,
                reminderPoolBeforeDelete: false,
                updatedAt: DateTime.now(),
              )
            else
              value,
        ],
      ),
    );
  }

  Future<void> permanentlyDeleteDocument(String id) async {
    await _commit(
      _data.copyWith(
        documents: _data.documents
            .where((document) => document.id != id)
            .toList(),
      ),
    );
  }

  Future<void> restoreRecord(String documentId, String recordId) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == documentId)
              document.copyWith(
                records: [
                  for (final record in document.records)
                    if (record.id == recordId)
                      record.copyWith(deleted: false, updatedAt: now)
                    else
                      record,
                ],
                updatedAt: now,
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> permanentlyDeleteRecord(
    String documentId,
    String recordId,
  ) async {
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == documentId)
              document.copyWith(
                records: document.records
                    .where((record) => record.id != recordId)
                    .toList(),
                updatedAt: DateTime.now(),
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> restoreLocatedItem(String id) async {
    await _commit(
      _data.copyWith(
        locatedItems: [
          for (final item in _data.locatedItems)
            if (item.id == id)
              item.copyWith(deleted: false, updatedAt: DateTime.now())
            else
              item,
        ],
      ),
    );
  }

  Future<void> permanentlyDeleteLocatedItem(String id) async {
    await _commit(
      _data.copyWith(
        locatedItems: _data.locatedItems
            .where((item) => item.id != id)
            .toList(),
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
                clearDraft: true,
                updatedAt: now,
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> setDocumentDraft(String documentId, String? body) async {
    final trimmed = body?.trim();
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == documentId)
              document.copyWith(
                draftBody: trimmed == null || trimmed.isEmpty ? null : body,
                clearDraft: trimmed == null || trimmed.isEmpty,
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> updateRecord(
    String documentId,
    String recordId,
    String body,
  ) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == documentId)
              document.copyWith(
                records: [
                  for (final record in document.records)
                    if (record.id == recordId)
                      record.copyWith(
                        body: body.trim(),
                        updatedAt: now,
                        previousBodies: [...record.previousBodies, record.body],
                      )
                    else
                      record,
                ],
                updatedAt: now,
              )
            else
              document,
        ],
      ),
    );
  }

  Future<void> deleteRecord(String documentId, String recordId) async {
    final now = DateTime.now();
    await _commit(
      _data.copyWith(
        documents: [
          for (final document in _data.documents)
            if (document.id == documentId)
              document.copyWith(
                records: [
                  for (final record in document.records)
                    if (record.id == recordId)
                      record.copyWith(deleted: true, updatedAt: now)
                    else
                      record,
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
    try {
      await _repository.save(next);
      _data = next;
      _pendingData = null;
      _persistenceError = null;
      notifyListeners();
    } on Object {
      _pendingData = next;
      _persistenceError = '刚才的修改没有安全保存。请重试后再退出应用。';
      notifyListeners();
    }
  }

  Future<void> retryPersistence() async {
    final pending = _pendingData;
    if (pending == null) return;
    await _commit(pending);
  }
}

String? _optionalText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _periodInstanceId(String ruleId, DateTime date) =>
    'period-instance|$ruleId|${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

(String, DateTime)? _periodInstanceParts(String id) {
  final parts = id.split('|');
  if (parts.length != 3 || parts.first != 'period-instance') return null;
  final date = DateTime.tryParse(parts[2]);
  if (date == null) return null;
  return (parts[1], date);
}

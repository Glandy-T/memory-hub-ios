enum MemoryTaskStatus { active, completed, skipped, deleted }

class MemoryTask {
  const MemoryTask({
    required this.id,
    required this.title,
    required this.date,
    required this.updatedAt,
    this.note,
    this.minutesFromMidnight,
    this.status = MemoryTaskStatus.active,
    this.periodRuleId,
  });

  final String id;
  final String title;
  final String? note;
  final DateTime date;
  final int? minutesFromMidnight;
  final MemoryTaskStatus status;
  final DateTime updatedAt;
  final String? periodRuleId;

  MemoryTask copyWith({
    String? title,
    String? note,
    bool clearNote = false,
    DateTime? date,
    int? minutesFromMidnight,
    bool clearTime = false,
    MemoryTaskStatus? status,
    DateTime? updatedAt,
    String? periodRuleId,
  }) {
    return MemoryTask(
      id: id,
      title: title ?? this.title,
      note: clearNote ? null : note ?? this.note,
      date: date ?? this.date,
      minutesFromMidnight: clearTime
          ? null
          : minutesFromMidnight ?? this.minutesFromMidnight,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      periodRuleId: periodRuleId ?? this.periodRuleId,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'date': _dateKey(date),
    'minutesFromMidnight': minutesFromMidnight,
    'status': status.name,
    'updatedAt': updatedAt.toIso8601String(),
    'periodRuleId': periodRuleId,
  };

  factory MemoryTask.fromJson(Map<String, Object?> json) {
    return MemoryTask(
      id: json['id']! as String,
      title: json['title']! as String,
      note: json['note'] as String?,
      date: DateTime.parse(json['date']! as String),
      minutesFromMidnight: json['minutesFromMidnight'] as int?,
      status: MemoryTaskStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => MemoryTaskStatus.active,
      ),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
      periodRuleId: json['periodRuleId'] as String?,
    );
  }
}

class PeriodRule {
  const PeriodRule({
    required this.id,
    required this.title,
    required this.startDate,
    required this.weekdays,
    required this.updatedAt,
    this.endDate,
    this.active = true,
    this.deleted = false,
  });

  final String id;
  final String title;
  final DateTime startDate;
  final DateTime? endDate;
  final Set<int> weekdays;
  final DateTime updatedAt;
  final bool active;
  final bool deleted;

  PeriodRule copyWith({
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    Set<int>? weekdays,
    DateTime? updatedAt,
    bool? active,
    bool? deleted,
  }) => PeriodRule(
    id: id,
    title: title ?? this.title,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    weekdays: weekdays ?? this.weekdays,
    updatedAt: updatedAt ?? this.updatedAt,
    active: active ?? this.active,
    deleted: deleted ?? this.deleted,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'startDate': _dateKey(startDate),
    'endDate': endDate == null ? null : _dateKey(endDate!),
    'weekdays': weekdays.toList()..sort(),
    'updatedAt': updatedAt.toIso8601String(),
    'active': active,
    'deleted': deleted,
  };

  factory PeriodRule.fromJson(Map<String, Object?> json) => PeriodRule(
    id: json['id']! as String,
    title: json['title']! as String,
    startDate: DateTime.parse(json['startDate']! as String),
    endDate: json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate']! as String),
    weekdays:
        (json['weekdays'] as List<Object?>? ?? const [1, 2, 3, 4, 5, 6, 7])
            .whereType<int>()
            .toSet(),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    active: json['active'] as bool? ?? true,
    deleted: json['deleted'] as bool? ?? false,
  );
}

class MemoryCategory {
  const MemoryCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.order,
    this.isDefault = false,
    this.deleted = false,
  });

  final String id;
  final String name;
  final int colorValue;
  final int order;
  final bool isDefault;
  final bool deleted;

  MemoryCategory copyWith({
    String? name,
    int? colorValue,
    int? order,
    bool? deleted,
  }) {
    return MemoryCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      isDefault: isDefault,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'order': order,
    'isDefault': isDefault,
    'deleted': deleted,
  };

  factory MemoryCategory.fromJson(Map<String, Object?> json) => MemoryCategory(
    id: json['id']! as String,
    name: json['name']! as String,
    colorValue: json['colorValue']! as int,
    order: json['order']! as int,
    isDefault: json['isDefault'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
  );
}

class MemoryRecord {
  const MemoryRecord({
    required this.id,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.previousBodies = const [],
    this.deleted = false,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> previousBodies;
  final bool deleted;

  MemoryRecord copyWith({
    String? body,
    DateTime? updatedAt,
    List<String>? previousBodies,
    bool? deleted,
  }) => MemoryRecord(
    id: id,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    previousBodies: previousBodies ?? this.previousBodies,
    deleted: deleted ?? this.deleted,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'previousBodies': previousBodies,
    'deleted': deleted,
  };

  factory MemoryRecord.fromJson(Map<String, Object?> json) => MemoryRecord(
    id: json['id']! as String,
    body: json['body']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt']! as String),
    previousBodies: (json['previousBodies'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toList(),
    deleted: json['deleted'] as bool? ?? false,
  );
}

class MemoryDocument {
  const MemoryDocument({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.updatedAt,
    this.records = const [],
    this.inReminderPool = false,
    this.archived = false,
    this.deleted = false,
    this.reminderMutedUntil,
    this.deletedWithCategoryId,
    this.reminderPoolBeforeDelete = false,
    this.draftBody,
  });

  final String id;
  final String categoryId;
  final String title;
  final DateTime updatedAt;
  final List<MemoryRecord> records;
  final bool inReminderPool;
  final bool archived;
  final bool deleted;
  final DateTime? reminderMutedUntil;
  final String? deletedWithCategoryId;
  final bool reminderPoolBeforeDelete;
  final String? draftBody;

  MemoryDocument copyWith({
    String? categoryId,
    String? title,
    DateTime? updatedAt,
    List<MemoryRecord>? records,
    bool? inReminderPool,
    bool? archived,
    bool? deleted,
    DateTime? reminderMutedUntil,
    bool clearReminderMute = false,
    String? deletedWithCategoryId,
    bool clearCategoryDeletion = false,
    bool? reminderPoolBeforeDelete,
    String? draftBody,
    bool clearDraft = false,
  }) => MemoryDocument(
    id: id,
    categoryId: categoryId ?? this.categoryId,
    title: title ?? this.title,
    updatedAt: updatedAt ?? this.updatedAt,
    records: records ?? this.records,
    inReminderPool: inReminderPool ?? this.inReminderPool,
    archived: archived ?? this.archived,
    deleted: deleted ?? this.deleted,
    reminderMutedUntil: clearReminderMute
        ? null
        : reminderMutedUntil ?? this.reminderMutedUntil,
    deletedWithCategoryId: clearCategoryDeletion
        ? null
        : deletedWithCategoryId ?? this.deletedWithCategoryId,
    reminderPoolBeforeDelete:
        reminderPoolBeforeDelete ?? this.reminderPoolBeforeDelete,
    draftBody: clearDraft ? null : draftBody ?? this.draftBody,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'title': title,
    'updatedAt': updatedAt.toIso8601String(),
    'records': records.map((record) => record.toJson()).toList(),
    'inReminderPool': inReminderPool,
    'archived': archived,
    'deleted': deleted,
    'reminderMutedUntil': reminderMutedUntil?.toIso8601String(),
    'deletedWithCategoryId': deletedWithCategoryId,
    'reminderPoolBeforeDelete': reminderPoolBeforeDelete,
    'draftBody': draftBody,
  };

  factory MemoryDocument.fromJson(Map<String, Object?> json) => MemoryDocument(
    id: json['id']! as String,
    categoryId: json['categoryId']! as String,
    title: json['title']! as String,
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    records: (json['records'] as List<Object?>? ?? const [])
        .map((value) => MemoryRecord.fromJson(value! as Map<String, Object?>))
        .toList(),
    inReminderPool: json['inReminderPool'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
    reminderMutedUntil: json['reminderMutedUntil'] == null
        ? null
        : DateTime.parse(json['reminderMutedUntil']! as String),
    deletedWithCategoryId: json['deletedWithCategoryId'] as String?,
    reminderPoolBeforeDelete:
        json['reminderPoolBeforeDelete'] as bool? ?? false,
    draftBody: json['draftBody'] as String?,
  );
}

enum FridgeStorage { chilled, frozen }

enum FridgeRemovalReason { eaten, discarded, removed }

class FridgeItem {
  const FridgeItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.storage,
    required this.updatedAt,
    this.expiryDate,
    this.note,
    this.opened = false,
    this.deleted = false,
    this.deletedAt,
    this.removalReason,
  });

  final String id;
  final String name;
  final String quantity;
  final FridgeStorage storage;
  final DateTime? expiryDate;
  final String? note;
  final bool opened;
  final DateTime updatedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final FridgeRemovalReason? removalReason;

  FridgeItem copyWith({
    String? name,
    String? quantity,
    FridgeStorage? storage,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    String? note,
    bool clearNote = false,
    bool? opened,
    bool? deleted,
    DateTime? deletedAt,
    FridgeRemovalReason? removalReason,
    bool clearRemoval = false,
    DateTime? updatedAt,
  }) => FridgeItem(
    id: id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    storage: storage ?? this.storage,
    expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
    note: clearNote ? null : note ?? this.note,
    opened: opened ?? this.opened,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: clearRemoval ? null : deletedAt ?? this.deletedAt,
    removalReason: clearRemoval ? null : removalReason ?? this.removalReason,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'storage': storage.name,
    'expiryDate': expiryDate == null ? null : _dateKey(expiryDate!),
    'note': note,
    'opened': opened,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'removalReason': removalReason?.name,
  };

  factory FridgeItem.fromJson(Map<String, Object?> json) => FridgeItem(
    id: json['id']! as String,
    name: json['name']! as String,
    quantity: json['quantity'] as String? ?? '1',
    storage: FridgeStorage.values.firstWhere(
      (value) => value.name == json['storage'],
      orElse: () => FridgeStorage.chilled,
    ),
    expiryDate: json['expiryDate'] == null
        ? null
        : DateTime.parse(json['expiryDate']! as String),
    note: json['note'] as String?,
    opened: json['opened'] as bool? ?? false,
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    deleted: json['deleted'] as bool? ?? false,
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.parse(json['deletedAt']! as String),
    removalReason: FridgeRemovalReason.values
        .where((value) => value.name == json['removalReason'])
        .firstOrNull,
  );
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.bought = false,
  });

  final String id;
  final String name;
  final bool bought;

  ShoppingItem copyWith({bool? bought}) =>
      ShoppingItem(id: id, name: name, bought: bought ?? this.bought);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'bought': bought};

  factory ShoppingItem.fromJson(Map<String, Object?> json) => ShoppingItem(
    id: json['id']! as String,
    name: json['name']! as String,
    bought: json['bought'] as bool? ?? false,
  );
}

enum LocatedItemStatus { stored, inUse, lentOut, missing }

class LocationHistoryEntry {
  const LocationHistoryEntry({required this.location, required this.changedAt});

  final String location;
  final DateTime changedAt;

  Map<String, Object?> toJson() => {
    'location': location,
    'changedAt': changedAt.toIso8601String(),
  };

  factory LocationHistoryEntry.fromJson(Map<String, Object?> json) =>
      LocationHistoryEntry(
        location: json['location']! as String,
        changedAt: DateTime.parse(json['changedAt']! as String),
      );
}

class LocatedItem {
  const LocatedItem({
    required this.id,
    required this.name,
    required this.location,
    required this.quantity,
    required this.updatedAt,
    this.note,
    this.container,
    this.status = LocatedItemStatus.stored,
    this.locationHistory = const [],
    this.deleted = false,
  });

  final String id;
  final String name;
  final String location;
  final String quantity;
  final String? note;
  final String? container;
  final LocatedItemStatus status;
  final List<LocationHistoryEntry> locationHistory;
  final DateTime updatedAt;
  final bool deleted;

  LocatedItem copyWith({
    String? name,
    String? location,
    String? quantity,
    String? note,
    bool clearNote = false,
    String? container,
    bool clearContainer = false,
    LocatedItemStatus? status,
    List<LocationHistoryEntry>? locationHistory,
    bool? deleted,
    DateTime? updatedAt,
  }) => LocatedItem(
    id: id,
    name: name ?? this.name,
    location: location ?? this.location,
    quantity: quantity ?? this.quantity,
    note: clearNote ? null : note ?? this.note,
    container: clearContainer ? null : container ?? this.container,
    status: status ?? this.status,
    locationHistory: locationHistory ?? this.locationHistory,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'quantity': quantity,
    'note': note,
    'container': container,
    'status': status.name,
    'locationHistory': locationHistory.map((entry) => entry.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  factory LocatedItem.fromJson(Map<String, Object?> json) => LocatedItem(
    id: json['id']! as String,
    name: json['name']! as String,
    location: json['location']! as String,
    quantity: json['quantity'] as String? ?? '1',
    note: json['note'] as String?,
    container: json['container'] as String?,
    status: LocatedItemStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => LocatedItemStatus.stored,
    ),
    locationHistory: (json['locationHistory'] as List<Object?>? ?? const [])
        .map(
          (value) =>
              LocationHistoryEntry.fromJson(value! as Map<String, Object?>),
        )
        .toList(),
    updatedAt: DateTime.parse(json['updatedAt']! as String),
    deleted: json['deleted'] as bool? ?? false,
  );
}

class MemoryData {
  const MemoryData({
    this.schemaVersion = 7,
    this.tasks = const [],
    this.periodRules = const [],
    this.categories = const [],
    this.documents = const [],
    this.fridgeItems = const [],
    this.shoppingItems = const [],
    this.locatedItems = const [],
  });

  final int schemaVersion;
  final List<MemoryTask> tasks;
  final List<PeriodRule> periodRules;
  final List<MemoryCategory> categories;
  final List<MemoryDocument> documents;
  final List<FridgeItem> fridgeItems;
  final List<ShoppingItem> shoppingItems;
  final List<LocatedItem> locatedItems;

  factory MemoryData.initial() => const MemoryData(
    categories: [
      MemoryCategory(
        id: 'memory-hub-default-category',
        name: '未分类',
        colorValue: 0xFF8F7CF6,
        order: 0,
        isDefault: true,
      ),
    ],
  );

  MemoryData copyWith({
    List<MemoryTask>? tasks,
    List<PeriodRule>? periodRules,
    List<MemoryCategory>? categories,
    List<MemoryDocument>? documents,
    List<FridgeItem>? fridgeItems,
    List<ShoppingItem>? shoppingItems,
    List<LocatedItem>? locatedItems,
  }) => MemoryData(
    schemaVersion: schemaVersion,
    tasks: tasks ?? this.tasks,
    periodRules: periodRules ?? this.periodRules,
    categories: categories ?? this.categories,
    documents: documents ?? this.documents,
    fridgeItems: fridgeItems ?? this.fridgeItems,
    shoppingItems: shoppingItems ?? this.shoppingItems,
    locatedItems: locatedItems ?? this.locatedItems,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'periodRules': periodRules.map((rule) => rule.toJson()).toList(),
    'categories': categories.map((category) => category.toJson()).toList(),
    'documents': documents.map((document) => document.toJson()).toList(),
    'fridgeItems': fridgeItems.map((item) => item.toJson()).toList(),
    'shoppingItems': shoppingItems.map((item) => item.toJson()).toList(),
    'locatedItems': locatedItems.map((item) => item.toJson()).toList(),
  };

  factory MemoryData.fromJson(Map<String, Object?> json) {
    if ((json['schemaVersion'] as int? ?? 0) > 7) {
      throw const FormatException('数据版本高于当前应用支持范围');
    }
    final data = MemoryData(
      tasks: (json['tasks'] as List<Object?>? ?? const [])
          .map((value) => MemoryTask.fromJson(value! as Map<String, Object?>))
          .toList(),
      periodRules: (json['periodRules'] as List<Object?>? ?? const [])
          .map((value) => PeriodRule.fromJson(value! as Map<String, Object?>))
          .toList(),
      categories: (json['categories'] as List<Object?>? ?? const [])
          .map(
            (value) => MemoryCategory.fromJson(value! as Map<String, Object?>),
          )
          .toList(),
      documents: (json['documents'] as List<Object?>? ?? const [])
          .map(
            (value) => MemoryDocument.fromJson(value! as Map<String, Object?>),
          )
          .toList(),
      fridgeItems: (json['fridgeItems'] as List<Object?>? ?? const [])
          .map((value) => FridgeItem.fromJson(value! as Map<String, Object?>))
          .toList(),
      shoppingItems: (json['shoppingItems'] as List<Object?>? ?? const [])
          .map((value) => ShoppingItem.fromJson(value! as Map<String, Object?>))
          .toList(),
      locatedItems: (json['locatedItems'] as List<Object?>? ?? const [])
          .map((value) => LocatedItem.fromJson(value! as Map<String, Object?>))
          .toList(),
    );
    if (data.categories.any((category) => category.isDefault)) return data;
    return data.copyWith(
      categories: [...data.categories, ...MemoryData.initial().categories],
    );
  }
}

int _memoryIdSequence = 0;

String newMemoryId(String prefix) {
  _memoryIdSequence += 1;
  return '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_memoryIdSequence.toRadixString(36)}';
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

bool sameCalendarDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

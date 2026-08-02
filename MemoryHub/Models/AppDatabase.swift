import Foundation

struct AppDatabase: Codable {
    static let currentSchemaVersion = 5

    var schemaVersion = currentSchemaVersion
    var categories: [MemoryCategory] = []
    var documents: [MemoryDocument] = []
    var records: [MemoryRecord] = []
    var calendarItems: [CalendarItem] = []
    var recurringRules: [RecurringRule] = []
    var fridgeItems: [FridgeItem] = []
    var purchaseItems: [PurchaseItem] = []
    var homeItems: [HomeItem] = []

    init(
        schemaVersion: Int = currentSchemaVersion,
        categories: [MemoryCategory] = [],
        documents: [MemoryDocument] = [],
        records: [MemoryRecord] = [],
        calendarItems: [CalendarItem] = [],
        recurringRules: [RecurringRule] = [],
        fridgeItems: [FridgeItem] = [],
        purchaseItems: [PurchaseItem] = [],
        homeItems: [HomeItem] = []
    ) {
        self.schemaVersion = schemaVersion
        self.categories = categories
        self.documents = documents
        self.records = records
        self.calendarItems = calendarItems
        self.recurringRules = recurringRules
        self.fridgeItems = fridgeItems
        self.purchaseItems = purchaseItems
        self.homeItems = homeItems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        categories = try container.decodeIfPresent([MemoryCategory].self, forKey: .categories) ?? []
        documents = try container.decodeIfPresent([MemoryDocument].self, forKey: .documents) ?? []
        records = try container.decodeIfPresent([MemoryRecord].self, forKey: .records) ?? []
        calendarItems = try container.decodeIfPresent([CalendarItem].self, forKey: .calendarItems) ?? []
        recurringRules = try container.decodeIfPresent([RecurringRule].self, forKey: .recurringRules) ?? []
        fridgeItems = try container.decodeIfPresent([FridgeItem].self, forKey: .fridgeItems) ?? []
        purchaseItems = try container.decodeIfPresent([PurchaseItem].self, forKey: .purchaseItems) ?? []
        homeItems = try container.decodeIfPresent([HomeItem].self, forKey: .homeItems) ?? []
    }

    static func initial() -> AppDatabase {
        AppDatabase(categories: [
            MemoryCategory(
                stableKey: MemoryCategory.defaultStableKey,
                name: "未分类",
                colorHex: "8F7CF6",
                sortOrder: 0
            )
        ])
    }
}

struct MemoryCategory: Identifiable, Codable, Hashable {
    static let defaultStableKey = "system.default"

    var id = UUID()
    var stableKey: String? = nil
    var name: String
    var colorHex: String
    var sortOrder: Int
    var deletedAt: Date? = nil

    var isDefault: Bool { stableKey == Self.defaultStableKey }
    var isDeleted: Bool { deletedAt != nil }
}

struct MemoryDocument: Identifiable, Codable, Hashable {
    var id = UUID()
    var categoryID: UUID
    var title: String
    var createdAt = Date()
    var updatedAt = Date()
    var isPinned = false
    var isInReminderPool = false
    var reminderHiddenOn: Date? = nil
    var reminderSnoozedUntil: Date? = nil
    var archivedAt: Date? = nil
    var deletedAt: Date? = nil
    var deletedByCategoryID: UUID? = nil

    var isArchived: Bool { archivedAt != nil }
    var isDeleted: Bool { deletedAt != nil }
}

struct MemoryRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var documentID: UUID
    var publishedContent: String?
    var draftContent: String?
    var createdAt = Date()
    var updatedAt = Date()
    var deletedAt: Date? = nil
    var deletedByDocumentID: UUID? = nil
    var versions: [RecordVersion] = []

    var isDraft: Bool { draftContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    var isNewDraft: Bool { publishedContent == nil && isDraft }
    var isDeleted: Bool { deletedAt != nil }
}

struct RecordVersion: Identifiable, Codable, Hashable {
    var id = UUID()
    var content: String
    var savedAt = Date()
}

enum CalendarItemStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case skipped
}

struct CalendarItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var date: Date
    var time: Date? = nil
    var status = CalendarItemStatus.pending
    var deletedAt: Date? = nil
    var recurringRuleID: UUID? = nil
}

struct RecurringRule: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startDate: Date
    var endDate: Date? = nil
    var weekdays: Set<Int> = []
    var stoppedAt: Date? = nil
    var deletedAt: Date? = nil

    var isDeleted: Bool { deletedAt != nil }
    var isStopped: Bool { stoppedAt != nil }
}

enum FridgeRemovalReason: String, Codable, CaseIterable {
    case eaten
    case discarded
    case removed

    var title: String {
        switch self {
        case .eaten: "已吃完"
        case .discarded: "已丢弃"
        case .removed: "已移除"
        }
    }
}

struct FridgeItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var storage: String? = nil
    var quantity: String? = nil
    var expiryDate: Date? = nil
    var isOpened = false
    var notes: String? = nil
    var createdAt = Date()
    var removedAt: Date? = nil
    var removalReason: FridgeRemovalReason? = nil

    var isActive: Bool { removedAt == nil }
}

struct PurchaseItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var createdAt = Date()
}

enum HomeItemStockStatus: String, Codable, CaseIterable, Identifiable {
    case enough
    case low
    case empty

    var id: String { rawValue }
    var title: String {
        switch self {
        case .enough: "充足"
        case .low: "少量"
        case .empty: "用完"
        }
    }
}

struct ItemLocationChange: Identifiable, Codable, Hashable {
    var id = UUID()
    var location: String
    var changedAt = Date()
}

struct HomeItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var location: String? = nil
    var quantity: String? = nil
    var status: HomeItemStockStatus? = nil
    var notes: String? = nil
    var accessory: String? = nil
    var createdAt = Date()
    var updatedAt = Date()
    var deletedAt: Date? = nil
    var locationHistory: [ItemLocationChange] = []

    var isDeleted: Bool { deletedAt != nil }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .dark: "深色"
        case .light: "浅色"
        }
    }
}

import Combine
import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var database: AppDatabase
    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    @Published var lastErrorMessage: String?

    private static let appearanceKey = "memoryHub.appearance"
    private let fileManager: FileManager
    private let databaseURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let rawAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
        appearance = AppAppearance(rawValue: rawAppearance ?? "") ?? .system
        lastErrorMessage = nil

        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("MemoryHub", isDirectory: true)
        databaseURL = directory.appendingPathComponent("memory-hub-v1.json")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: databaseURL.path) {
                let data = try Data(contentsOf: databaseURL)
                database = try Self.decoder.decode(AppDatabase.self, from: data)
            } else {
                database = .initial()
                try Self.write(database, to: databaseURL)
            }
        } catch {
            database = .initial()
            lastErrorMessage = "本地数据读取失败，已使用空白数据启动：\(error.localizedDescription)"
        }
        migrateDatabaseIfNeeded()
        repairDefaultCategoryIfNeeded()
    }

    var activeCategories: [MemoryCategory] {
        database.categories.filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var defaultCategoryID: UUID? {
        database.categories.first { $0.stableKey == MemoryCategory.defaultStableKey && !$0.isDeleted }?.id
    }

    func category(id: UUID) -> MemoryCategory? {
        database.categories.first { $0.id == id }
    }

    func renameCategory(id: UUID, name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, let index = database.categories.firstIndex(where: { $0.id == id }) else { return }
        database.categories[index].name = cleanName
        persist()
    }

    func updateCategoryColor(id: UUID, colorHex: String) {
        guard let index = database.categories.firstIndex(where: { $0.id == id }) else { return }
        database.categories[index].colorHex = colorHex
        persist()
    }

    func reorderCategories(ids: [UUID]) {
        for (order, id) in ids.enumerated() {
            guard let index = database.categories.firstIndex(where: { $0.id == id }) else { continue }
            database.categories[index].sortOrder = order
        }
        persist()
    }

    func softDeleteCategory(id: UUID, moveDocumentsToDefault: Bool) {
        guard let categoryIndex = database.categories.firstIndex(where: { $0.id == id }),
              !database.categories[categoryIndex].isDefault else { return }
        let now = Date()

        if moveDocumentsToDefault, let defaultID = defaultCategoryID {
            for index in database.documents.indices where database.documents[index].categoryID == id && !database.documents[index].isDeleted {
                database.documents[index].categoryID = defaultID
                database.documents[index].updatedAt = now
            }
        } else {
            let documentIDs = database.documents
                .filter { $0.categoryID == id && !$0.isDeleted }
                .map(\.id)
            for documentID in documentIDs {
                softDeleteDocument(id: documentID, deletedByCategoryID: id, persistAfter: false)
            }
        }

        database.categories[categoryIndex].deletedAt = now
        persist()
    }

    func documents(in categoryID: UUID) -> [MemoryDocument] {
        database.documents
            .filter { $0.categoryID == categoryID && !$0.isDeleted && !$0.isArchived }
            .sorted {
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                return $0.updatedAt > $1.updatedAt
            }
    }

    func document(id: UUID) -> MemoryDocument? {
        database.documents.first { $0.id == id }
    }

    func records(in documentID: UUID) -> [MemoryRecord] {
        database.records
            .filter { $0.documentID == documentID && !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func hasDraft(in documentID: UUID) -> Bool {
        records(in: documentID).contains(where: \.isDraft)
    }

    @discardableResult
    func createCategory(name: String, colorHex: String = "41C7BE") -> UUID? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        let nextOrder = (activeCategories.map(\.sortOrder).max() ?? -1) + 1
        let category = MemoryCategory(name: cleanName, colorHex: colorHex, sortOrder: nextOrder)
        database.categories.append(category)
        persist()
        return category.id
    }

    @discardableResult
    func createDocument(title: String, categoryID: UUID) -> UUID? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, category(id: categoryID)?.isDeleted == false else { return nil }
        let document = MemoryDocument(categoryID: categoryID, title: cleanTitle)
        database.documents.append(document)
        persist()
        return document.id
    }

    func renameDocument(id: UUID, title: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let index = database.documents.firstIndex(where: { $0.id == id }) else { return }
        database.documents[index].title = cleanTitle
        database.documents[index].updatedAt = Date()
        persist()
    }

    func toggleReminderPool(documentID: UUID) {
        guard let index = database.documents.firstIndex(where: { $0.id == documentID }) else { return }
        database.documents[index].isInReminderPool.toggle()
        if database.documents[index].isInReminderPool {
            database.documents[index].reminderHiddenOn = nil
            database.documents[index].reminderSnoozedUntil = nil
        }
        database.documents[index].updatedAt = Date()
        persist()
    }

    func hideDocumentReminderToday(documentID: UUID) {
        guard let index = database.documents.firstIndex(where: { $0.id == documentID }) else { return }
        database.documents[index].reminderHiddenOn = Date()
        database.documents[index].reminderSnoozedUntil = nil
        persist()
    }

    func snoozeDocumentReminder(documentID: UUID, until: Date) {
        guard let index = database.documents.firstIndex(where: { $0.id == documentID }) else { return }
        let limit = Date().addingTimeInterval(24 * 60 * 60)
        database.documents[index].reminderSnoozedUntil = min(until, limit)
        database.documents[index].reminderHiddenOn = nil
        persist()
    }

    func removeDocumentFromReminderPool(documentID: UUID) {
        guard let index = database.documents.firstIndex(where: { $0.id == documentID }) else { return }
        database.documents[index].isInReminderPool = false
        database.documents[index].reminderHiddenOn = nil
        database.documents[index].reminderSnoozedUntil = nil
        persist()
    }

    func softDeleteDocument(id: UUID) {
        softDeleteDocument(id: id, deletedByCategoryID: nil, persistAfter: true)
    }

    private func softDeleteDocument(id: UUID, deletedByCategoryID: UUID?, persistAfter: Bool) {
        guard let index = database.documents.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        database.documents[index].deletedAt = now
        database.documents[index].deletedByCategoryID = deletedByCategoryID
        database.documents[index].isInReminderPool = false
        for recordIndex in database.records.indices where database.records[recordIndex].documentID == id && !database.records[recordIndex].isDeleted {
            database.records[recordIndex].deletedAt = now
            database.records[recordIndex].deletedByDocumentID = id
        }
        if persistAfter { persist() }
    }

    @discardableResult
    func createRecordDraft(documentID: UUID) -> UUID {
        let record = MemoryRecord(documentID: documentID, publishedContent: nil, draftContent: "")
        database.records.append(record)
        persist()
        return record.id
    }

    func beginEditingRecord(id: UUID) {
        guard let index = database.records.firstIndex(where: { $0.id == id }), database.records[index].draftContent == nil else { return }
        database.records[index].draftContent = database.records[index].publishedContent ?? ""
        persist()
    }

    func updateDraft(recordID: UUID, content: String) {
        guard let index = database.records.firstIndex(where: { $0.id == recordID }) else { return }
        database.records[index].draftContent = content
        database.records[index].updatedAt = Date()
        touchDocument(database.records[index].documentID)
        persist()
    }

    func publishDraft(recordID: UUID) {
        guard let index = database.records.firstIndex(where: { $0.id == recordID }),
              let draft = database.records[index].draftContent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !draft.isEmpty else { return }

        if let published = database.records[index].publishedContent {
            database.records[index].versions.append(RecordVersion(content: published))
        }
        database.records[index].publishedContent = draft
        database.records[index].draftContent = nil
        database.records[index].updatedAt = Date()
        touchDocument(database.records[index].documentID)
        persist()
    }

    func discardDraft(recordID: UUID) {
        guard let index = database.records.firstIndex(where: { $0.id == recordID }) else { return }
        if database.records[index].publishedContent == nil {
            database.records.remove(at: index)
        } else {
            database.records[index].draftContent = nil
        }
        persist()
    }

    func softDeleteRecord(id: UUID) {
        guard let index = database.records.firstIndex(where: { $0.id == id }) else { return }
        database.records[index].deletedAt = Date()
        touchDocument(database.records[index].documentID)
        persist()
    }

    @discardableResult
    func createCalendarItem(title: String, date: Date, time: Date?) -> UUID? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        let item = CalendarItem(title: cleanTitle, date: date, time: time)
        database.calendarItems.append(item)
        persist()
        return item.id
    }

    var visibleRecurringRules: [RecurringRule] {
        database.recurringRules
            .filter { !$0.isDeleted }
            .sorted { $0.startDate > $1.startDate }
    }

    @discardableResult
    func createRecurringRule(title: String, startDate: Date, endDate: Date?, weekdays: Set<Int>) -> UUID? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, endDate == nil || endDate! >= startDate else { return nil }
        let rule = RecurringRule(title: cleanTitle, startDate: startDate, endDate: endDate, weekdays: weekdays)
        database.recurringRules.append(rule)
        persist()
        return rule.id
    }

    func stopRecurringRule(id: UUID) {
        guard let index = database.recurringRules.firstIndex(where: { $0.id == id }) else { return }
        database.recurringRules[index].stoppedAt = Date()
        persist()
    }

    func softDeleteRecurringRule(id: UUID) {
        guard let index = database.recurringRules.firstIndex(where: { $0.id == id }) else { return }
        database.recurringRules[index].deletedAt = Date()
        persist()
    }

    func ensureRecurringInstances(for date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        var changed = false

        for rule in database.recurringRules where !rule.isDeleted && !rule.isStopped {
            let start = calendar.startOfDay(for: rule.startDate)
            guard day >= start else { continue }
            if let endDate = rule.endDate, day > calendar.startOfDay(for: endDate) { continue }
            guard rule.weekdays.isEmpty || rule.weekdays.contains(weekday) else { continue }
            let exists = database.calendarItems.contains {
                $0.recurringRuleID == rule.id && calendar.isDate($0.date, inSameDayAs: day)
            }
            guard !exists else { continue }
            database.calendarItems.append(CalendarItem(title: rule.title, date: day, recurringRuleID: rule.id))
            changed = true
        }

        if changed { persist() }
    }

    func setCalendarItemStatus(id: UUID, status: CalendarItemStatus) {
        guard let index = database.calendarItems.firstIndex(where: { $0.id == id }) else { return }
        database.calendarItems[index].status = status
        persist()
    }

    func updateCalendarItem(id: UUID, title: String, date: Date, time: Date?) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let index = database.calendarItems.firstIndex(where: { $0.id == id }) else { return }
        database.calendarItems[index].title = cleanTitle
        database.calendarItems[index].date = date
        database.calendarItems[index].time = time
        persist()
    }

    func softDeleteCalendarItem(id: UUID) {
        guard let index = database.calendarItems.firstIndex(where: { $0.id == id }) else { return }
        database.calendarItems[index].deletedAt = Date()
        persist()
    }

    func restoreCategory(id: UUID) {
        guard let index = database.categories.firstIndex(where: { $0.id == id }) else { return }
        database.categories[index].deletedAt = nil
        for documentIndex in database.documents.indices where database.documents[documentIndex].deletedByCategoryID == id {
            let documentID = database.documents[documentIndex].id
            database.documents[documentIndex].deletedAt = nil
            database.documents[documentIndex].deletedByCategoryID = nil
            restoreRecordsDeletedWithDocument(documentID)
        }
        persist()
    }

    func restoreDocument(id: UUID) {
        guard let index = database.documents.firstIndex(where: { $0.id == id }) else { return }
        database.documents[index].deletedAt = nil
        database.documents[index].deletedByCategoryID = nil
        if category(id: database.documents[index].categoryID)?.isDeleted != false, let defaultID = defaultCategoryID {
            database.documents[index].categoryID = defaultID
        }
        restoreRecordsDeletedWithDocument(id)
        persist()
    }

    func restoreRecord(id: UUID) {
        guard let index = database.records.firstIndex(where: { $0.id == id }),
              document(id: database.records[index].documentID)?.isDeleted == false else { return }
        database.records[index].deletedAt = nil
        database.records[index].deletedByDocumentID = nil
        persist()
    }

    func restoreCalendarItem(id: UUID) {
        guard let index = database.calendarItems.firstIndex(where: { $0.id == id }) else { return }
        database.calendarItems[index].deletedAt = nil
        persist()
    }

    func restoreRecurringRule(id: UUID) {
        guard let index = database.recurringRules.firstIndex(where: { $0.id == id }) else { return }
        database.recurringRules[index].deletedAt = nil
        persist()
    }

    func permanentlyDeleteCategory(id: UUID) {
        guard category(id: id)?.isDeleted == true else { return }
        let documentIDs = database.documents.filter { $0.categoryID == id && $0.isDeleted }.map(\.id)
        database.records.removeAll { documentIDs.contains($0.documentID) }
        database.documents.removeAll { documentIDs.contains($0.id) }
        database.categories.removeAll { $0.id == id }
        persist()
    }

    func permanentlyDeleteDocument(id: UUID) {
        guard document(id: id)?.isDeleted == true else { return }
        database.records.removeAll { $0.documentID == id }
        database.documents.removeAll { $0.id == id }
        persist()
    }

    func permanentlyDeleteRecord(id: UUID) {
        guard database.records.first(where: { $0.id == id })?.isDeleted == true else { return }
        database.records.removeAll { $0.id == id }
        persist()
    }

    func permanentlyDeleteCalendarItem(id: UUID) {
        guard database.calendarItems.first(where: { $0.id == id })?.deletedAt != nil else { return }
        database.calendarItems.removeAll { $0.id == id }
        persist()
    }

    func permanentlyDeleteRecurringRule(id: UUID) {
        guard database.recurringRules.first(where: { $0.id == id })?.isDeleted == true else { return }
        database.recurringRules.removeAll { $0.id == id }
        persist()
    }

    private func restoreRecordsDeletedWithDocument(_ documentID: UUID) {
        for index in database.records.indices where database.records[index].deletedByDocumentID == documentID {
            database.records[index].deletedAt = nil
            database.records[index].deletedByDocumentID = nil
        }
    }

    private func touchDocument(_ id: UUID) {
        guard let index = database.documents.firstIndex(where: { $0.id == id }) else { return }
        database.documents[index].updatedAt = Date()
    }

    private func repairDefaultCategoryIfNeeded() {
        guard !database.categories.contains(where: { $0.stableKey == MemoryCategory.defaultStableKey && !$0.isDeleted }) else { return }
        database.categories.insert(
            MemoryCategory(stableKey: MemoryCategory.defaultStableKey, name: "未分类", colorHex: "8F7CF6", sortOrder: 0),
            at: 0
        )
        persist()
    }

    private func migrateDatabaseIfNeeded() {
        guard database.schemaVersion < AppDatabase.currentSchemaVersion else { return }
        // v2-v4 add optional fields and recurring-rule storage. Missing optionals decode as nil.
        database.schemaVersion = AppDatabase.currentSchemaVersion
        persist()
    }

    private func persist() {
        do {
            try Self.write(database, to: databaseURL)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "本地数据保存失败：\(error.localizedDescription)"
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func write(_ database: AppDatabase, to url: URL) throws {
        let data = try encoder.encode(database)
        try data.write(to: url, options: [.atomic])
    }
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

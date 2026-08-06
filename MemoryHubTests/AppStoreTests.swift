import XCTest
@testable import MemoryHub

final class AppStoreTests: XCTestCase {
    @MainActor
    func testFreshInstallUsesLightAppearanceAndKeepsUserSelection() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        XCTAssertEqual(fixture.store.appearance, .light)

        fixture.store.appearance = .dark
        let reloaded = AppStore(
            databaseURL: fixture.databaseURL,
            userDefaults: fixture.userDefaults
        )
        XCTAssertEqual(reloaded.appearance, .dark)
    }

    @MainActor
    func testLegacyDatabaseMigratesAndRepairsDefaultCategory() throws {
        let legacyData = Data(#"{"schemaVersion":1}"#.utf8)
        let fixture = try makeStore(seed: legacyData)
        defer { removeFixture(fixture) }

        XCTAssertEqual(fixture.store.database.schemaVersion, AppDatabase.currentSchemaVersion)
        XCTAssertEqual(fixture.store.activeCategories.count, 1)
        XCTAssertTrue(try XCTUnwrap(fixture.store.activeCategories.first).isDefault)

        let reloaded = AppStore(
            databaseURL: fixture.databaseURL,
            userDefaults: fixture.userDefaults
        )
        XCTAssertEqual(reloaded.database.schemaVersion, AppDatabase.currentSchemaVersion)
        XCTAssertEqual(reloaded.activeCategories.filter(\.isDefault).count, 1)
    }

    @MainActor
    func testDocumentDeletionAndRestorePreserveReminderPoolAndRecords() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let categoryID = try XCTUnwrap(fixture.store.defaultCategoryID)
        let documentID = try XCTUnwrap(fixture.store.createDocument(title: "  护照资料  ", categoryID: categoryID))
        fixture.store.toggleReminderPool(documentID: documentID)

        let recordID = fixture.store.createRecordDraft(documentID: documentID)
        fixture.store.updateDraft(recordID: recordID, content: "复印件在蓝色文件夹")
        fixture.store.publishDraft(recordID: recordID)
        fixture.store.softDeleteDocument(id: documentID)

        let deletedDocument = try XCTUnwrap(fixture.store.document(id: documentID))
        XCTAssertEqual(deletedDocument.title, "护照资料")
        XCTAssertTrue(deletedDocument.isDeleted)
        XCTAssertFalse(deletedDocument.isInReminderPool)
        XCTAssertEqual(deletedDocument.reminderPoolBeforeDeletion, true)
        XCTAssertTrue(try XCTUnwrap(fixture.store.database.records.first { $0.id == recordID }).isDeleted)

        fixture.store.restoreDocument(id: documentID)

        let restoredDocument = try XCTUnwrap(fixture.store.document(id: documentID))
        XCTAssertFalse(restoredDocument.isDeleted)
        XCTAssertTrue(restoredDocument.isInReminderPool)
        XCTAssertNil(restoredDocument.reminderPoolBeforeDeletion)
        XCTAssertFalse(try XCTUnwrap(fixture.store.database.records.first { $0.id == recordID }).isDeleted)
    }

    @MainActor
    func testPublishingEditedRecordCreatesVersionHistory() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let categoryID = try XCTUnwrap(fixture.store.defaultCategoryID)
        let documentID = try XCTUnwrap(fixture.store.createDocument(title: "体检记录", categoryID: categoryID))
        let recordID = fixture.store.createRecordDraft(documentID: documentID)
        fixture.store.updateDraft(recordID: recordID, content: "第一次结果")
        fixture.store.publishDraft(recordID: recordID)
        fixture.store.beginEditingRecord(id: recordID)
        fixture.store.updateDraft(recordID: recordID, content: "第二次结果")
        fixture.store.publishDraft(recordID: recordID)

        let record = try XCTUnwrap(fixture.store.database.records.first { $0.id == recordID })
        XCTAssertEqual(record.publishedContent, "第二次结果")
        XCTAssertNil(record.draftContent)
        XCTAssertEqual(record.versions.map(\.content), ["第一次结果"])
    }

    @MainActor
    func testCalendarItemWithoutTimeCannotKeepNotificationMode() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let itemID = try XCTUnwrap(
            fixture.store.createCalendarItem(
                title: "  整理资料  ",
                notes: "   ",
                date: Date(),
                time: nil,
                notificationMode: .strong
            )
        )

        let item = try XCTUnwrap(fixture.store.database.calendarItems.first { $0.id == itemID })
        XCTAssertEqual(item.title, "整理资料")
        XCTAssertNil(item.notes)
        XCTAssertNil(item.time)
        XCTAssertEqual(item.notificationMode, Optional(CalendarNotificationMode.none))
    }

    @MainActor
    func testRecurringRuleCreatesOnlyOneMatchingInstance() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: day)
        let ruleID = try XCTUnwrap(
            fixture.store.createRecurringRule(
                title: "服药",
                startDate: day,
                endDate: nil,
                weekdays: [weekday]
            )
        )

        fixture.store.ensureRecurringInstances(for: day)
        fixture.store.ensureRecurringInstances(for: day)

        let matches = fixture.store.database.calendarItems.filter { $0.recurringRuleID == ruleID }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.title, "服药")
    }

    @MainActor
    func testMergeBackupMapsIncomingDefaultCategoryAndAvoidsDuplicates() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let incomingDefault = MemoryCategory(
            stableKey: MemoryCategory.defaultStableKey,
            name: "旧版未分类",
            colorHex: "8F7CF6",
            sortOrder: 0
        )
        let incomingDocument = MemoryDocument(
            categoryID: incomingDefault.id,
            title: "迁移文档"
        )
        let incoming = AppDatabase(
            categories: [incomingDefault],
            documents: [incomingDocument]
        )

        fixture.store.importBackup(incoming, replaceExisting: false)
        fixture.store.importBackup(incoming, replaceExisting: false)

        let defaults = fixture.store.database.categories.filter { $0.isDefault && !$0.isDeleted }
        XCTAssertEqual(defaults.count, 1)
        let mergedDocument = try XCTUnwrap(fixture.store.document(id: incomingDocument.id))
        XCTAssertEqual(mergedDocument.categoryID, try XCTUnwrap(fixture.store.defaultCategoryID))
        XCTAssertEqual(fixture.store.database.documents.filter { $0.id == incomingDocument.id }.count, 1)
    }

    @MainActor
    func testReminderCandidatesExcludeHiddenSnoozedArchivedAndDeletedDocuments() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let categoryID = try XCTUnwrap(fixture.store.defaultCategoryID)
        let visibleID = try XCTUnwrap(fixture.store.createDocument(title: "可显示", categoryID: categoryID))
        let hiddenID = try XCTUnwrap(fixture.store.createDocument(title: "今天隐藏", categoryID: categoryID))
        let snoozedID = try XCTUnwrap(fixture.store.createDocument(title: "稍后提醒", categoryID: categoryID))
        let archivedID = try XCTUnwrap(fixture.store.createDocument(title: "已归档", categoryID: categoryID))
        let deletedID = try XCTUnwrap(fixture.store.createDocument(title: "已删除", categoryID: categoryID))

        for id in [visibleID, hiddenID, snoozedID, archivedID, deletedID] {
            fixture.store.toggleReminderPool(documentID: id)
        }
        fixture.store.hideDocumentReminderToday(documentID: hiddenID)
        fixture.store.snoozeDocumentReminder(documentID: snoozedID, until: Date().addingTimeInterval(60 * 60))
        fixture.store.archiveDocument(id: archivedID)
        fixture.store.softDeleteDocument(id: deletedID)

        XCTAssertEqual(fixture.store.eligibleReminderDocuments().map(\.id), [visibleID])
    }

    @MainActor
    func testFridgeRemovalCanCreatePurchaseAndRestoreHistoryItem() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let itemID = try XCTUnwrap(
            fixture.store.createFridgeItem(
                name: "  牛奶  ",
                storage: "冷藏",
                quantity: "半盒",
                expiryDate: nil,
                isOpened: true,
                notes: " "
            )
        )

        fixture.store.removeFridgeItem(id: itemID, reason: .removed, addToPurchaseList: true)

        XCTAssertTrue(fixture.store.activeFridgeItems.isEmpty)
        XCTAssertEqual(fixture.store.fridgeHistoryItems.map(\.id), [itemID])
        XCTAssertEqual(fixture.store.database.purchaseItems.map(\.name), ["牛奶"])

        fixture.store.restoreFridgeItem(id: itemID)

        XCTAssertEqual(fixture.store.activeFridgeItems.map(\.id), [itemID])
        XCTAssertTrue(fixture.store.fridgeHistoryItems.isEmpty)
    }

    @MainActor
    func testHomeItemTracksDistinctNonemptyLocationsAndRestoresFromRecycleBin() throws {
        let fixture = try makeStore()
        defer { removeFixture(fixture) }

        let itemID = try XCTUnwrap(
            fixture.store.createHomeItem(
                name: "备用钥匙",
                location: "玄关抽屉",
                quantity: nil,
                status: nil,
                notes: nil,
                accessory: "蓝色钥匙圈"
            )
        )
        fixture.store.updateHomeItem(
            id: itemID,
            name: "备用钥匙",
            location: "书桌右侧",
            quantity: nil,
            status: nil,
            notes: nil,
            accessory: "蓝色钥匙圈"
        )
        fixture.store.updateHomeItem(
            id: itemID,
            name: "备用钥匙",
            location: "书桌右侧",
            quantity: nil,
            status: nil,
            notes: nil,
            accessory: "蓝色钥匙圈"
        )

        let item = try XCTUnwrap(fixture.store.database.homeItems.first { $0.id == itemID })
        XCTAssertEqual(item.locationHistory.map(\.location), ["玄关抽屉", "书桌右侧"])

        fixture.store.softDeleteHomeItem(id: itemID)
        XCTAssertTrue(fixture.store.activeHomeItems.isEmpty)
        fixture.store.restoreHomeItem(id: itemID)
        XCTAssertEqual(fixture.store.activeHomeItems.map(\.id), [itemID])
    }

    @MainActor
    private func makeStore(seed: Data? = nil) throws -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MemoryHubTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("database.json")
        if let seed {
            try seed.write(to: databaseURL, options: .atomic)
        }

        let suiteName = "MemoryHubTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = AppStore(databaseURL: databaseURL, userDefaults: userDefaults)
        return Fixture(
            store: store,
            directory: directory,
            databaseURL: databaseURL,
            userDefaults: userDefaults,
            defaultsSuiteName: suiteName
        )
    }

    private func removeFixture(_ fixture: Fixture) {
        fixture.userDefaults.removePersistentDomain(forName: fixture.defaultsSuiteName)
        try? FileManager.default.removeItem(at: fixture.directory)
    }
}

private struct Fixture {
    let store: AppStore
    let directory: URL
    let databaseURL: URL
    let userDefaults: UserDefaults
    let defaultsSuiteName: String
}

import XCTest

final class MemoryHubUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
            "--memory-hub-ui-testing"
        ]
        app.launch()
    }

    func testCreateDocumentFromDefaultCategory() throws {
        createDocument(named: "体检资料")

        XCTAssertTrue(app.staticTexts["体检资料"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["这里还没有记录"].exists)
    }

    func testPublishFirstRecordDraft() throws {
        createDocument(named: "健康记录")
        app.buttons["添加第一条记录"].tap()

        let editor = app.textViews["记录内容"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText("复诊时间已经确认")
        app.buttons["完成"].tap()

        XCTAssertTrue(app.buttons["复诊时间已经确认"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["未分类 · 共 1 条记录"].exists)
    }

    func testDeleteDocumentAndRestoreItFromRecycleBin() throws {
        createDocument(named: "待恢复文档")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["编辑"].tap()
        app.buttons["文档操作"].tap()
        app.buttons["删除文档"].tap()

        let confirmDelete = app.alerts.buttons["删除"]
        XCTAssertTrue(confirmDelete.waitForExistence(timeout: 3))
        confirmDelete.tap()
        XCTAssertTrue(app.staticTexts["这里还没有文档"].waitForExistence(timeout: 3))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["我的"].tap()
        app.buttons["回收站"].tap()

        XCTAssertTrue(app.staticTexts["待恢复文档"].waitForExistence(timeout: 3))
        app.buttons["恢复"].tap()
        XCTAssertTrue(app.staticTexts["回收站是空的"].waitForExistence(timeout: 3))
    }

    func testAddDocumentToReminderPool() throws {
        createDocument(named: "旅行清单")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["编辑"].tap()

        let addToPool = app.buttons["加入提醒池"]
        XCTAssertTrue(addToPool.waitForExistence(timeout: 3))
        addToPool.tap()
        XCTAssertTrue(app.buttons["移出提醒池"].waitForExistence(timeout: 3))
    }

    func testCreateCalendarItem() throws {
        app.buttons["日历"].tap()
        app.buttons["新增事项"].tap()

        let titleField = app.textFields["简短标题"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("预约复诊")
        app.buttons["创建"].tap()

        XCTAssertTrue(app.staticTexts["预约复诊"].waitForExistence(timeout: 3))
    }

    func testCreateFridgeItem() throws {
        openHomeModule(named: "冰箱")
        app.buttons["新增食材"].tap()

        let nameField = app.textFields["名称（必填）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("牛奶")
        app.buttons["创建食材"].tap()

        XCTAssertTrue(app.staticTexts["牛奶"].waitForExistence(timeout: 3))
    }

    func testCreateHomeItemWithFreeTextLocation() throws {
        openHomeModule(named: "物品位置")
        app.buttons["新增物品"].tap()

        let nameField = app.textFields["物品名（必填）"]
        let locationField = app.textFields["当前位置（自由填写）"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("备用钥匙")
        locationField.tap()
        locationField.typeText("玄关抽屉")
        app.buttons["创建物品"].tap()

        XCTAssertTrue(app.staticTexts["备用钥匙"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["玄关抽屉"].exists)
    }

    func testOpenAndCancelBackupExporter() throws {
        openSettingsPage(named: "数据备份")
        XCTAssertTrue(app.staticTexts["本地存储概览"].waitForExistence(timeout: 3))
        app.buttons["导出本地备份"].tap()

        let cancel = firstExistingButton(in: app, labels: ["取消", "Cancel"], timeout: 5)
        XCTAssertNotNil(cancel)
        cancel?.tap()
        XCTAssertTrue(app.staticTexts["本地存储概览"].waitForExistence(timeout: 3))
    }

    func testDailyNotificationPermissionOutcome() throws {
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw XCTSkip("通知授权需要签名应用或真实设备，GitHub 无签名模拟器不会返回权限结果")
        }

        openSettingsPage(named: "通知设置")

        let toggle = app.switches["开启每日提醒"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let permissionButtonLabels = ["允许", "Allow", "允许通知", "Allow Notifications"]
        let permissionMonitor = addUIInterruptionMonitor(withDescription: "通知权限") { alert in
            for label in permissionButtonLabels {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
        defer { removeUIInterruptionMonitor(permissionMonitor) }

        toggle.tap()
        app.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let reminderTime = app.staticTexts["提醒时间"]
        let permissionError = app.alerts["通知设置"]
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            for label in permissionButtonLabels {
                let allow = springboard.buttons[label]
                if allow.exists { allow.tap() }
            }

            if permissionError.exists {
                XCTAssertTrue(app.staticTexts["系统通知权限未开启，请在系统设置中允许通知。"].exists)
                permissionError.buttons["知道了"].tap()
                XCTAssertEqual(toggle.value as? String, "0")
                return
            }

            if reminderTime.exists {
                XCTAssertEqual(toggle.value as? String, "1")
                return
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTFail("通知权限请求未在 3 秒内进入授权或拒绝状态")
    }

    private func createDocument(named title: String) {
        app.buttons["分类"].tap()

        let defaultCategory = app.buttons["未分类"]
        XCTAssertTrue(defaultCategory.waitForExistence(timeout: 3))
        defaultCategory.tap()

        let addDocument = app.buttons["新建文档"]
        XCTAssertTrue(addDocument.waitForExistence(timeout: 3))
        addDocument.tap()

        let titleField = app.textFields["文档标题"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText(title)
        app.buttons["创建"].tap()
    }

    private func openHomeModule(named name: String) {
        let module = app.buttons[name]
        for _ in 0..<6 where !module.exists {
            app.swipeUp()
        }
        XCTAssertTrue(module.waitForExistence(timeout: 3))
        module.tap()
    }

    private func openSettingsPage(named name: String) {
        app.buttons["我的"].tap()
        let destination = app.buttons[name]
        XCTAssertTrue(destination.waitForExistence(timeout: 3))
        destination.tap()
    }

    private func firstExistingButton(
        in application: XCUIApplication,
        labels: [String],
        timeout: TimeInterval
    ) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for label in labels {
                let button = application.buttons[label]
                if button.exists { return button }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return nil
    }
}

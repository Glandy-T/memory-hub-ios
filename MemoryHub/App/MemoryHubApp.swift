import Foundation
import SwiftUI

@main
struct MemoryHubApp: App {
    @StateObject private var store: AppStore

    init() {
        _store = StateObject(wrappedValue: Self.makeStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.appearance.colorScheme)
        }
    }

    private static func makeStore() -> AppStore {
        guard ProcessInfo.processInfo.arguments.contains("--memory-hub-ui-testing") else {
            return AppStore()
        }

        let fileManager = FileManager.default
        let databaseURL = fileManager.temporaryDirectory
            .appendingPathComponent("MemoryHubUITests", isDirectory: true)
            .appendingPathComponent("memory-hub-ui-tests.json")
        try? fileManager.removeItem(at: databaseURL.deletingLastPathComponent())

        let defaults = UserDefaults(suiteName: "com.glandy.memoryhub.ui-testing") ?? .standard
        defaults.removePersistentDomain(forName: "com.glandy.memoryhub.ui-testing")
        UserDefaults.standard.removeObject(forKey: "memoryHub.dailyCheckEnabled")
        UserDefaults.standard.removeObject(forKey: "memoryHub.dailyCheckHour")
        UserDefaults.standard.removeObject(forKey: "memoryHub.strongReminderInterval")
        return AppStore(fileManager: fileManager, databaseURL: databaseURL, userDefaults: defaults)
    }
}

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("memoryHub.dailyCheckEnabled") private var dailyCheckEnabled = false
    @AppStorage("memoryHub.dailyCheckHour") private var dailyCheckHour = 8
    @AppStorage("memoryHub.strongReminderInterval") private var strongInterval = 15
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("开启每日提醒", isOn: $dailyCheckEnabled)
                if dailyCheckEnabled {
                    Picker("提醒时间", selection: $dailyCheckHour) {
                        Text("早上 8:00").tag(8)
                        Text("早上 9:00").tag(9)
                    }
                }
            } header: {
                Text("每日检查提醒")
            } footer: {
                Text("提醒文案保持简短，即使当天没有事项也可以发送。")
            }

            Section {
                Picker("重复间隔", selection: $strongInterval) {
                    Text("10 分钟").tag(10)
                    Text("15 分钟").tag(15)
                    Text("30 分钟").tag(30)
                }
            } header: {
                Text("强提醒")
            } footer: {
                Text("强提醒最多安排 6 次；事项完成、无视或删除后立即取消后续通知。")
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: dailyCheckEnabled) { _, _ in scheduleDailyCheck() }
        .onChange(of: dailyCheckHour) { _, _ in scheduleDailyCheck() }
        .alert("通知设置", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("知道了") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func scheduleDailyCheck() {
        Task {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["memoryHub.dailyCheck"])
            guard dailyCheckEnabled else { return }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else {
                    await MainActor.run {
                        dailyCheckEnabled = false
                        errorMessage = "系统通知权限未开启，请在系统设置中允许通知。"
                    }
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = "Memory Hub"
                content.body = "嘿，来检查一下今天的待办事项吧。"
                content.sound = .default
                var components = DateComponents()
                components.hour = dailyCheckHour
                components.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                try await center.add(UNNotificationRequest(identifier: "memoryHub.dailyCheck", content: content, trigger: trigger))
            } catch {
                await MainActor.run { errorMessage = "无法设置通知：\(error.localizedDescription)" }
            }
        }
    }
}

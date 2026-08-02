import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    settingsGroup("内容与提醒") {
                        NavigationLink {
                            ReminderPoolView()
                        } label: {
                            SettingRow(title: "文档提醒池", detail: "已选择 \(reminderCount) 篇", icon: "doc.badge.clock")
                        }
                        .buttonStyle(.plain)
                        SettingRow(title: "首页刷新规则", detail: "打开或手动刷新", icon: "arrow.clockwise")
                    }

                    settingsGroup("外观") {
                        Picker("主题", selection: $store.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.title).tag(appearance)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(14)
                    }

                    settingsGroup("数据与安全") {
                        NavigationLink {
                            RecycleBinView()
                        } label: {
                            SettingRow(title: "回收站", detail: "可恢复的删除内容", icon: "trash")
                        }
                        .buttonStyle(.plain)
                        SettingRow(title: "数据备份", detail: "尚未设置", icon: "externaldrive")
                    }

                    settingsGroup("关于") {
                        SettingRow(title: "Memory Hub", detail: "版本 0.1.0", icon: "info.circle")
                    }
                }
                .padding(.horizontal, MHTheme.pagePadding)
                .padding(.bottom, 32)
            }
            .navigationTitle("我的")
            .memoryHubPage()
        }
    }

    private var reminderCount: Int {
        store.database.documents.filter { $0.isInReminderPool && !$0.isDeleted && !$0.isArchived }.count
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MHTheme.secondaryText)
            VStack(spacing: 4, content: content)
                .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: MHTheme.cardRadius))
        }
    }
}

private struct SettingRow: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(MHTheme.accent)
                .frame(width: 28)
            Text(title).font(.body.weight(.medium))
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(MHTheme.secondaryText)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(MHTheme.secondaryText.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}

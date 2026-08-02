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
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            SettingRow(title: "通知设置", detail: "每日检查与强提醒", icon: "bell")
                        }
                        .buttonStyle(.plain)
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
                            ArchiveView()
                        } label: {
                            SettingRow(title: "归档", detail: "已归档文档", icon: "archivebox")
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            RecycleBinView()
                        } label: {
                            SettingRow(title: "回收站", detail: "可恢复的删除内容", icon: "trash")
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            DataManagementView()
                        } label: {
                            SettingRow(title: "数据备份", detail: "导入、导出与存储概览", icon: "externaldrive")
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            PrivacyView()
                        } label: {
                            SettingRow(title: "隐私", detail: "本地优先", icon: "hand.raised")
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup("关于") {
                        NavigationLink {
                            AboutView()
                        } label: {
                            SettingRow(title: "Memory Hub", detail: "版本 0.1.0", icon: "info.circle")
                        }
                        .buttonStyle(.plain)
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

private struct PrivacyView: View {
    var body: some View {
        List {
            Section("数据位置") {
                Label("内容默认只保存在这台设备", systemImage: "iphone")
                Label("第一版不创建账号或云同步", systemImage: "icloud.slash")
            }
            Section("系统权限") {
                Text("只有在你开启通知时才请求通知权限。导入和导出通过系统文件选择器完成。")
            }
        }
        .navigationTitle("隐私")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Hub").font(.title2.bold())
                    Text("版本 0.1.0")
                        .font(.caption)
                        .foregroundStyle(MHTheme.secondaryText)
                    Text("一个安静的个人记忆与生活信息管理工具。它不会给你的生活打分，也不会制造连续打卡压力。")
                        .font(.body)
                }
                .padding(.vertical, 8)
            }
            Section("帮助") {
                Text("从分类建立文档，在日历安排事项；首页会投影今天的事项，并从你选择的文档提醒池中随机取三篇。")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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

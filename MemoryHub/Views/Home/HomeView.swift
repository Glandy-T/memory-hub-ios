import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var reminderIDs: [UUID] = []
    @State private var undoItem: CalendarItem?
    @State private var snoozingDocument: MemoryDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    todaySection
                    reminderSection
                    lifeModules
                }
                .padding(.horizontal, MHTheme.pagePadding)
                .padding(.bottom, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background {
                if colorScheme == .light {
                    Image("LightPigmentBackground")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.5)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
            }
            .navigationDestination(for: UUID.self) { documentID in
                DocumentDetailView(documentID: documentID)
            }
            .sheet(item: $snoozingDocument) { document in
                SnoozeReminderSheet(document: document) {
                    refreshReminders()
                }
            }
            .memoryHubPage()
            .onAppear {
                store.ensureRecurringInstances(for: logicalToday)
                refreshReminders()
            }
            .overlay(alignment: .bottom) {
                if let item = undoItem {
                    HStack(spacing: 14) {
                        Text("已从今日事项移除")
                            .font(.subheadline)
                        Spacer()
                        Button("撤销") {
                            store.setCalendarItemStatus(id: item.id, status: .pending)
                            undoItem = nil
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(
                logicalToday,
                format: .dateTime
                    .month(.wide)
                    .day()
                    .locale(Locale(identifier: "zh_CN"))
            )
                .font(.title.bold())
            Text(
                logicalToday,
                format: .dateTime
                    .weekday(.short)
                    .locale(Locale(identifier: "zh_CN"))
            )
                .font(.subheadline)
                .foregroundStyle(MHTheme.secondaryText)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("今日事项", detail: "来自日历")
            if todayItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今天暂时没有事项")
                        .font(.title3.weight(.semibold))
                    Text("日历里安排到今天的内容会出现在这里。")
                        .font(.subheadline)
                        .foregroundStyle(MHTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                .padding(22)
                .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: 24))
            } else {
                ForEach(todayItems) { item in
                    VStack(alignment: .leading, spacing: 18) {
                        Text(item.title)
                            .font(.title3.weight(.semibold))
                        if let time = item.time {
                            Text(time, format: .dateTime.hour().minute())
                                .font(.subheadline)
                                .foregroundStyle(MHTheme.secondaryText)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button("无视") { resolve(item, as: .skipped) }
                                .buttonStyle(.bordered)
                            Button("完成") { resolve(item, as: .completed) }
                                .buttonStyle(.borderedProminent)
                                .tint(MHTheme.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                    .padding(22)
                    .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: 24))
                }
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("文档提醒", detail: reminderDocuments.isEmpty ? "提醒池为空" : "随机 3 条")
                Spacer()
                Button(action: refreshReminders) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("刷新文档提醒")
            }

            if reminderDocuments.isEmpty {
                Text("在分类的文档列表中点“编辑”，勾选想偶尔回看的文档。")
                    .font(.subheadline)
                    .foregroundStyle(MHTheme.secondaryText)
                    .padding(.vertical, 16)
            } else {
                ForEach(reminderDocuments) { document in
                    HStack(spacing: 12) {
                        Circle().fill(categoryColor(for: document)).frame(width: 8, height: 8)
                        NavigationLink(value: document.id) {
                            Text(document.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(MHTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Menu {
                            Button("今天隐藏", systemImage: "eye.slash") {
                                store.hideDocumentReminderToday(documentID: document.id)
                                refreshReminders()
                            }
                            Button("稍后提醒", systemImage: "clock") {
                                snoozingDocument = document
                            }
                            Button("此文档永不提醒", systemImage: "bell.slash", role: .destructive) {
                                store.removeDocumentFromReminderPool(documentID: document.id)
                                refreshReminders()
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(MHTheme.secondaryText)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .frame(minHeight: 58)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(MHTheme.hairline).frame(height: 1)
                    }
                }
            }
        }
    }

    private var lifeModules: some View {
        HStack(spacing: 14) {
            NavigationLink {
                FridgeView()
            } label: {
                ModuleCard(title: "冰箱", detail: "食材与待采购", icon: "refrigerator", tint: MHTheme.cyan)
            }
            .buttonStyle(.plain)

            NavigationLink {
                ItemsView()
            } label: {
                ModuleCard(title: "物品位置", detail: "记录放在哪里", icon: "shippingbox", tint: MHTheme.violet)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(MHTheme.secondaryText)
        }
    }

    private var todayItems: [CalendarItem] {
        store.database.calendarItems.filter {
            Calendar.current.isDate($0.date, inSameDayAs: logicalToday) && $0.status == .pending && $0.deletedAt == nil
        }
    }

    private var logicalToday: Date {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        guard hour < 4 else { return now }
        return Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
    }

    private var reminderDocuments: [MemoryDocument] {
        reminderIDs.compactMap { store.document(id: $0) }
    }

    private func refreshReminders() {
        reminderIDs = store.database.documents
            .filter { document in
                guard document.isInReminderPool && !document.isDeleted && !document.isArchived else { return false }
                if let hidden = document.reminderHiddenOn, Calendar.current.isDateInToday(hidden) { return false }
                if let snoozed = document.reminderSnoozedUntil, snoozed > Date() { return false }
                return true
            }
            .shuffled()
            .prefix(3)
            .map(\.id)
    }

    private func categoryColor(for document: MemoryDocument) -> Color {
        Color(hex: store.category(id: document.categoryID)?.colorHex ?? "8F7CF6")
    }

    private func resolve(_ item: CalendarItem, as status: CalendarItemStatus) {
        store.setCalendarItemStatus(id: item.id, status: status)
        withAnimation { undoItem = item }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if undoItem?.id == item.id {
                withAnimation { undoItem = nil }
            }
        }
    }
}

private struct SnoozeReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let document: MemoryDocument
    let onSaved: () -> Void

    @State private var date = Date().addingTimeInterval(60 * 60)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "提醒时间",
                        selection: $date,
                        in: Date()...Date().addingTimeInterval(24 * 60 * 60)
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                } footer: {
                    Text("最长可延后 24 小时，可以跨到次日。")
                }
            }
            .navigationTitle("稍后提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("取消")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.snoozeDocumentReminder(documentID: document.id, until: date)
                        onSaved()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("保存")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ModuleCard: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Spacer()
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(MHTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: MHTheme.cardRadius))
    }
}

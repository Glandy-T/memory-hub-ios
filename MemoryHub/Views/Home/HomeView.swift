import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var reminderIDs: [UUID] = []
    @State private var undoItem: CalendarItem?
    @State private var snoozingDocument: MemoryDocument?

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        header
                        todaySection(cardHeight: taskCardHeight(for: viewport.size.height))
                        reminderSection
                        lifeModules
                    }
                    .padding(.horizontal, MHTheme.pagePadding)
                    .padding(.bottom, 32)
                }
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
                } else {
                    DarkAmbientBackground()
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
                    HStack(spacing: 12) {
                        Text("已从今日事项移除")
                            .font(.subheadline)
                        Spacer()
                        Button("撤销") {
                            store.setCalendarItemStatus(id: item.id, status: .pending)
                            undoItem = nil
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.horizontal, MHTheme.pagePadding)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(localizedDate("M月d日"))
                .font(.title.bold())
            Text(localizedDate("EEE"))
                .font(.subheadline)
                .foregroundStyle(MHTheme.secondaryText)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private func localizedDate(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter.string(from: logicalToday)
    }

    private func todaySection(cardHeight carouselHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "今日事项",
                detail: todayItems.isEmpty ? "来自日历" : "\(todayItems.count) 件待处理"
            )
            if todayItems.isEmpty {
                HStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(MHTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(MHTheme.accent.opacity(0.1), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("今天没有安排")
                            .font(.headline)
                        Text("从日历添加后会显示在这里")
                            .font(.subheadline)
                            .foregroundStyle(MHTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .memoryHubGlassCard(cornerRadius: MHTheme.cardRadius)
            } else {
                GeometryReader { carousel in
                    let cardWidth = max(carousel.size.width * 0.72, 240)
                    let cardHeight = max(carouselHeight - 96, 400)

                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 12) {
                            ForEach(todayItems) { item in
                                TodayItemCard(
                                    item: item,
                                    height: cardHeight,
                                    onSkip: { resolve(item, as: .skipped) },
                                    onComplete: { resolve(item, as: .completed) }
                                )
                                .frame(width: cardWidth)
                                .id(item.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(
                        .horizontal,
                        max((carousel.size.width - cardWidth) / 2, 0),
                        for: .scrollContent
                    )
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned)
                }
                .frame(height: carouselHeight)
            }
        }
    }

    private func taskCardHeight(for viewportHeight: CGFloat) -> CGFloat {
        max(viewportHeight - 128, 400)
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
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
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
        .padding(16)
        .memoryHubGlassCard(cornerRadius: MHTheme.cardRadius)
    }

    private var lifeModules: some View {
        HStack(spacing: 16) {
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
        VStack(alignment: .leading, spacing: 4) {
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

private struct TodayItemCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var resolutionOffset: CGFloat = 0

    let item: CalendarItem
    let height: CGFloat
    let onSkip: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Group {
                    if let time = item.time {
                        Label {
                            Text(time, format: .dateTime.hour().minute())
                        } icon: {
                            Image(systemName: "clock")
                        }
                    } else {
                        Label("全天", systemImage: "sun.max")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MHTheme.accent)

                Spacer()
            }

            Spacer(minLength: 24)

            Text(item.title)
                .font(.title.weight(.bold))
                .foregroundStyle(MHTheme.primaryText)
                .lineLimit(2)

            Text(item.time == nil ? "今天 · 全天事项" : "今天 · 已设置提醒时间")
                .font(.subheadline)
                .foregroundStyle(MHTheme.secondaryText)
                .padding(.top, 8)

            Spacer(minLength: 24)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .memoryHubGlassCard(cornerRadius: 24)
        .overlay {
            if abs(dragTranslation) > 12 {
                Label(
                    dragTranslation < 0 ? "完成" : "无视",
                    systemImage: dragTranslation < 0 ? "checkmark" : "eye.slash"
                )
                .font(.headline)
                .foregroundStyle(dragTranslation < 0 ? MHTheme.accent : MHTheme.secondaryText)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
                .opacity(min(abs(dragTranslation) / 88, 1))
            }
        }
        .offset(y: resolutionOffset + dragTranslation * 0.35)
        .scaleEffect(1 - min(abs(dragTranslation) / 4_000, 0.025))
        .opacity(resolutionOffset == 0 ? 1 : 0)
        .simultaneousGesture(verticalResolutionGesture)
        .accessibilityHint("左右滑动切换事项，上滑完成，下滑无视")
        .accessibilityAction(named: "完成", onComplete)
        .accessibilityAction(named: "无视", onSkip)
    }

    private var verticalResolutionGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                state = value.translation.height
            }
            .onEnded { value in
                let verticalDistance = value.translation.height
                guard abs(verticalDistance) > abs(value.translation.width), abs(verticalDistance) >= 88 else { return }
                resolveBySwipe(completing: verticalDistance < 0)
            }
    }

    private func resolveBySwipe(completing: Bool) {
        let action = completing ? onComplete : onSkip
        guard !reduceMotion else {
            action()
            return
        }

        withAnimation(.easeOut(duration: 0.18)) {
            resolutionOffset = completing ? -height : height
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            action()
            resolutionOffset = 0
        }
    }
}

private struct DarkAmbientBackground: View {
    var body: some View {
        ZStack {
            MHTheme.pageBackground

            Circle()
                .fill(MHTheme.cyan.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 92)
                .offset(x: 145, y: -210)

            Circle()
                .fill(MHTheme.violet.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 108)
                .offset(x: -155, y: 190)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct ModuleCard: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
            Spacer()
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(MHTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .memoryHubGlassCard()
    }
}

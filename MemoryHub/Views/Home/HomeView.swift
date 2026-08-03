import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var reminderIDs: [UUID] = []
    @State private var undoItem: CalendarItem?
    @State private var snoozingDocument: MemoryDocument?
    @State private var focusedTodayItemID: UUID?

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        firstScreen(
                            width: viewport.size.width,
                            minimumHeight: viewport.size.height + 16
                        )
                        reminderSection
                            .padding(.horizontal, 24)
                        lifeModules
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 128)
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
        .accessibilityElement(children: .combine)
    }

    private func firstScreen(width: CGFloat, minimumHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Rectangle()
                .fill(MHTheme.hairline.opacity(0.72))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.top, 18)

            todaySection(viewportWidth: width)
        }
        .frame(minHeight: minimumHeight, alignment: .top)
    }

    private func localizedDate(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter.string(from: logicalToday)
    }

    private func todaySection(viewportWidth: CGFloat) -> some View {
        let mainCardWidth = viewportWidth * (310.0 / 430.0)
        let sideCardWidth = viewportWidth * (170.0 / 430.0)
        let cardSpacing = viewportWidth * (12.0 / 430.0)
        let mainCardHeight = mainCardWidth * (548.0 / 310.0)
        let sideCardHeight = sideCardWidth * (438.0 / 170.0)
        let defaultFocusedID = todayItems.isEmpty ? nil : todayItems[todayItems.count / 2].id
        let activeFocusedID = focusedTodayItemID ?? defaultFocusedID

        return VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 4) {
                Text("今日事项")
                    .font(.headline)
                HStack(spacing: 7) {
                    Circle()
                        .fill(MHTheme.violet)
                        .frame(width: 5, height: 5)
                    Text(todayItems.isEmpty ? "来自日历" : "\(todayItems.count) 件待处理")
                        .font(.caption)
                        .foregroundStyle(MHTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 26)

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
                .padding(.horizontal, 24)
                .padding(.top, 25)
            } else {
                GeometryReader { carousel in
                    ScrollViewReader { scrollProxy in
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: cardSpacing) {
                                ForEach(todayItems) { item in
                                    let isFocused = item.id == activeFocusedID
                                    TodayItemCard(
                                        item: item,
                                        isFocused: isFocused,
                                        height: isFocused ? mainCardHeight : sideCardHeight,
                                        onSkip: { resolve(item, as: .skipped) },
                                        onComplete: { resolve(item, as: .completed) }
                                    )
                                    .frame(width: isFocused ? mainCardWidth : sideCardWidth)
                                    .id(item.id)
                                }
                            }
                            .scrollTargetLayout()
                            .animation(.easeOut(duration: 0.2), value: activeFocusedID)
                        }
                        .contentMargins(
                            .horizontal,
                            max((carousel.size.width - mainCardWidth) / 2, 0),
                            for: .scrollContent
                        )
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $focusedTodayItemID, anchor: .center)
                        .onAppear {
                            focusInitialTodayItemIfNeeded(todayItems.map(\.id), using: scrollProxy)
                        }
                        .onChange(of: todayItems.map(\.id)) { _, itemIDs in
                            focusInitialTodayItemIfNeeded(itemIDs, using: scrollProxy)
                        }
                    }
                }
                .frame(height: mainCardHeight)
                .padding(.top, 25)
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("文档提醒", detail: reminderDocuments.isEmpty ? "提醒池为空" : "从提醒池中随机抽取")
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(MHTheme.primaryText)
                                Text(reminderMetadata(for: document))
                                    .font(.caption)
                                    .foregroundStyle(MHTheme.secondaryText)
                            }
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

    private func reminderMetadata(for document: MemoryDocument) -> String {
        let category = store.category(id: document.categoryID)?.name ?? "未分类"
        return "\(category) · \(document.updatedAt.formatted(.dateTime.month().day()))编辑"
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

    private func focusInitialTodayItemIfNeeded(_ itemIDs: [UUID], using scrollProxy: ScrollViewProxy) {
        guard !itemIDs.isEmpty else {
            focusedTodayItemID = nil
            return
        }

        if let focusedTodayItemID, itemIDs.contains(focusedTodayItemID) {
            Task { @MainActor in
                await Task.yield()
                scrollProxy.scrollTo(focusedTodayItemID, anchor: .center)
            }
            return
        }

        let targetID = itemIDs[itemIDs.count / 2]
        focusedTodayItemID = targetID
        Task { @MainActor in
            await Task.yield()
            scrollProxy.scrollTo(targetID, anchor: .center)
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
    let isFocused: Bool
    let height: CGFloat
    let onSkip: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Group {
            if isFocused {
                GeometryReader { card in
                    let scale = card.size.width / 310.0

                    ZStack(alignment: .top) {
                        LinearGradient(
                            colors: [
                                MHTheme.accent.opacity(0),
                                MHTheme.accent.opacity(0.08),
                                MHTheme.warning.opacity(0.08),
                                MHTheme.coral.opacity(0.06),
                                MHTheme.violet.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: card.size.width * 1.4, height: 92 * scale)
                        .rotationEffect(.degrees(-16))
                        .blur(radius: 22 * scale)
                        .offset(y: 312 * scale)
                        .accessibilityHidden(true)

                        Text(item.time?.formatted(date: .omitted, time: .shortened) ?? "全天")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(MHTheme.secondaryText.opacity(0.58))
                            .position(x: card.size.width / 2, y: 118 * scale)

                        VStack(spacing: 10 * scale) {
                            Text(item.title)
                                .font(.title.weight(.semibold))
                                .foregroundStyle(MHTheme.primaryText.opacity(0.94))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)

                            if let notes = normalizedNotes {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(MHTheme.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                        }
                        .frame(width: card.size.width - 56 * scale)
                        .position(x: card.size.width / 2, y: 275 * scale)
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .memoryHubGlassCard(cornerRadius: 20)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if isFocused, abs(dragTranslation) > 12 {
                Label(
                    dragTranslation < 0 ? "完成" : "无视",
                    systemImage: dragTranslation < 0 ? "checkmark" : "eye.slash"
                )
                .font(.headline)
                .foregroundStyle(dragTranslation < 0 ? MHTheme.accent : MHTheme.secondaryText)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
                .opacity(min(abs(dragTranslation) / CGFloat(88), CGFloat(1)))
            }
        }
        .offset(y: resolutionOffset + dragTranslation * 0.35)
        .scaleEffect(1 - min(abs(dragTranslation) / 4_000, 0.025))
        .opacity(resolutionOffset == 0 ? 1 : 0)
        .simultaneousGesture(verticalResolutionGesture)
        .accessibilityHint("左右滑动切换事项，上滑完成，下滑无视")
        .accessibilityAction(named: Text("完成")) {
            onComplete()
        }
        .accessibilityAction(named: Text("无视")) {
            onSkip()
        }
    }

    private var verticalResolutionGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                state = value.translation.height
            }
            .onEnded { value in
                guard isFocused else { return }
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

    private var normalizedNotes: String? {
        let value = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
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

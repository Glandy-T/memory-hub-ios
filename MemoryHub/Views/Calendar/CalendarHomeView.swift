import SwiftUI

struct CalendarHomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedDate = Date()
    @State private var showingNewItem = false
    @State private var editingItem: CalendarItem?

    var body: some View {
        NavigationStack {
            List {
                topActions
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .listRowBackground(MHTheme.raisedBackground)

                Section {
                    if selectedItems.isEmpty {
                        Text("这一天还没有事项")
                            .font(.subheadline)
                            .foregroundStyle(MHTheme.secondaryText)
                            .frame(minHeight: 54)
                    } else {
                        ForEach(selectedItems) { item in
                            Button { editingItem = item } label: {
                                CalendarItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if item.status == .pending {
                                        Button("完成", systemImage: "checkmark") {
                                            store.setCalendarItemStatus(id: item.id, status: .completed)
                                        }
                                        .tint(MHTheme.cyan)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("删除", systemImage: "trash", role: .destructive) {
                                        store.softDeleteCalendarItem(id: item.id)
                                    }
                                    if item.status == .pending {
                                        Button("无视", systemImage: "slash.circle") {
                                            store.setCalendarItemStatus(id: item.id, status: .skipped)
                                        }
                                        .tint(MHTheme.secondaryText)
                                    }
                                }
                        }
                    }
                    Button("新增事项", systemImage: "plus") { showingNewItem = true }
                        .frame(minHeight: 44)
                } header: {
                    Text(selectedDate, format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                        .font(.headline)
                        .foregroundStyle(MHTheme.primaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("日历")
            .sheet(isPresented: $showingNewItem) {
                CalendarItemEditor(initialDate: selectedDate)
            }
            .sheet(item: $editingItem) { item in
                CalendarItemEditor(initialDate: item.date, item: item)
            }
            .memoryHubPage()
        }
    }

    private var topActions: some View {
        HStack {
            Button {
                selectedDate = Date()
            } label: {
                Label("今天", systemImage: "scope")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Spacer()
        }
        .padding(.top, 4)
    }

    private var selectedItems: [CalendarItem] {
        store.database.calendarItems
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) && $0.deletedAt == nil }
            .sorted {
                switch ($0.time, $1.time) {
                case let (left?, right?): left < right
                case (nil, _?): false
                case (_?, nil): true
                case (nil, nil): $0.title < $1.title
                }
            }
    }
}

private struct CalendarItemRow: View {
    let item: CalendarItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)
            Text(item.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(item.status == .pending ? MHTheme.primaryText : MHTheme.secondaryText)
                .strikethrough(item.status == .completed)
            Spacer()
            if let time = item.time {
                Text(time, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
            }
        }
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private var statusIcon: String {
        switch item.status {
        case .pending: "circle"
        case .completed: "checkmark.circle.fill"
        case .skipped: "slash.circle"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .pending: MHTheme.secondaryText
        case .completed: MHTheme.cyan
        case .skipped: MHTheme.secondaryText
        }
    }
}

private struct CalendarItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var title = ""
    @State private var date: Date
    @State private var includesTime = false
    @State private var time = Date()
    private let itemID: UUID?

    init(initialDate: Date, item: CalendarItem? = nil) {
        itemID = item?.id
        _title = State(initialValue: item?.title ?? "")
        _date = State(initialValue: item?.date ?? initialDate)
        _includesTime = State(initialValue: item?.time != nil)
        _time = State(initialValue: item?.time ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("事项") {
                    TextField("简短标题", text: $title)
                }
                Section("日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    Toggle("设置时间", isOn: $includesTime)
                    if includesTime {
                        DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    Text("没有设置时间的事项只会在应用内显示，不发送系统通知。")
                        .font(.footnote)
                        .foregroundStyle(MHTheme.secondaryText)
                }
            }
            .navigationTitle(itemID == nil ? "新增事项" : "编辑事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("取消")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let itemID {
                            store.updateCalendarItem(id: itemID, title: title, date: date, time: includesTime ? time : nil)
                        } else {
                            _ = store.createCalendarItem(title: title, date: date, time: includesTime ? time : nil)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("创建")
                }
            }
        }
    }
}

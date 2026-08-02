import SwiftUI

struct RecurringRulesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingEditor = false
    @State private var deletingRule: RecurringRule?

    var body: some View {
        List {
            if store.visibleRecurringRules.isEmpty {
                ContentUnavailableView(
                    "还没有周期事项",
                    systemImage: "repeat",
                    description: Text("周期规则只在符合日期时生成当天实例。")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.visibleRecurringRules) { rule in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(rule.title)
                                .font(.body.weight(.semibold))
                            Spacer()
                            if rule.isStopped {
                                Text("已停止")
                                    .font(.caption)
                                    .foregroundStyle(MHTheme.secondaryText)
                            }
                            Menu {
                                if !rule.isStopped {
                                    Button("停止未来事项", systemImage: "stop.circle") {
                                        store.stopRecurringRule(id: rule.id)
                                    }
                                }
                                Button("移入回收站", systemImage: "trash", role: .destructive) {
                                    deletingRule = rule
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .frame(width: 44, height: 44)
                            }
                        }
                        Text(ruleDescription(rule))
                            .font(.caption)
                            .foregroundStyle(MHTheme.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("周期事项")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新增周期事项")
            }
        }
        .sheet(isPresented: $showingEditor) {
            RecurringRuleEditor()
        }
        .alert(
            "删除周期规则？",
            isPresented: Binding(
                get: { deletingRule != nil },
                set: { if !$0 { deletingRule = nil } }
            )
        ) {
            Button("移入回收站", role: .destructive) {
                if let id = deletingRule?.id { store.softDeleteRecurringRule(id: id) }
                deletingRule = nil
            }
            Button("取消", role: .cancel) { deletingRule = nil }
        } message: {
            Text("未来不再生成事项，已经产生的历史实例会保留。")
        }
        .memoryHubPage()
    }

    private func ruleDescription(_ rule: RecurringRule) -> String {
        let schedule: String
        if rule.weekdays.isEmpty {
            schedule = "每天"
        } else {
            let labels = [(2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")]
            schedule = labels.filter { rule.weekdays.contains($0.0) }.map { $0.1 }.joined(separator: "、")
        }
        let start = rule.startDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN")))
        if let end = rule.endDate {
            return "\(schedule) · \(start) 至 \(end.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))"
        }
        return "\(schedule) · \(start) 起"
    }
}

private struct RecurringRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var title = ""
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var repeatsDaily = true
    @State private var weekdays: Set<Int> = []

    private let weekdayLabels = [(2, "星期一"), (3, "星期二"), (4, "星期三"), (5, "星期四"), (6, "星期五"), (7, "星期六"), (1, "星期日")]

    var body: some View {
        NavigationStack {
            Form {
                Section("周期事项") {
                    TextField("简短名称", text: $title)
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    Toggle("设置结束日期", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section("重复") {
                    Toggle("每天", isOn: $repeatsDaily)
                    if !repeatsDaily {
                        ForEach(weekdayLabels, id: \.0) { entry in
                            Toggle(entry.1, isOn: weekdayBinding(entry.0))
                        }
                    }
                }
                Section {
                    Text("第一版周期事项只在应用内显示，不发送系统通知。")
                        .font(.footnote)
                        .foregroundStyle(MHTheme.secondaryText)
                }
            }
            .navigationTitle("新增周期事项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("取消")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        _ = store.createRecurringRule(
                            title: title,
                            startDate: startDate,
                            endDate: hasEndDate ? endDate : nil,
                            weekdays: repeatsDaily ? [] : weekdays
                        )
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .accessibilityLabel("创建")
                }
            }
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (repeatsDaily || !weekdays.isEmpty)
    }

    private func weekdayBinding(_ value: Int) -> Binding<Bool> {
        Binding(
            get: { weekdays.contains(value) },
            set: { enabled in
                if enabled { weekdays.insert(value) } else { weekdays.remove(value) }
            }
        )
    }
}

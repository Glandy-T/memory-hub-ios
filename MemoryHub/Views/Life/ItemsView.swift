import SwiftUI

struct ItemsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var showingEditor = false
    @State private var editingItem: HomeItem?
    @State private var deletingItem: HomeItem?

    var body: some View {
        List {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "还没有物品" : "没有找到物品",
                    systemImage: "shippingbox",
                    description: Text(query.isEmpty ? "名称必填，当前位置可以留空。" : "试试其他关键词。")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredItems) { item in
                    Button { editingItem = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(statusColor(item.status))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.body.weight(.semibold))
                                HStack(spacing: 8) {
                                    if let location = item.location { Text(location) }
                                    if let quantity = item.quantity { Text(quantity) }
                                    if let status = item.status { Text(status.title) }
                                }
                                .font(.caption)
                                .foregroundStyle(MHTheme.secondaryText)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("删除", systemImage: "trash", role: .destructive) { deletingItem = item }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $query, prompt: "搜索物品或位置")
        .navigationTitle("物品位置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新增物品")
            }
        }
        .sheet(isPresented: $showingEditor) { HomeItemEditor() }
        .sheet(item: $editingItem) { HomeItemEditor(item: $0) }
        .alert(
            "删除“\(deletingItem?.name ?? "")”？",
            isPresented: Binding(
                get: { deletingItem != nil },
                set: { if !$0 { deletingItem = nil } }
            )
        ) {
            Button("移入回收站", role: .destructive) {
                if let id = deletingItem?.id { store.softDeleteHomeItem(id: id) }
                deletingItem = nil
            }
            Button("取消", role: .cancel) { deletingItem = nil }
        } message: {
            Text("之后可以从统一回收站恢复。")
        }
        .memoryHubPage()
    }

    private var filteredItems: [HomeItem] {
        guard !query.isEmpty else { return store.activeHomeItems }
        return store.activeHomeItems.filter {
            $0.name.localizedCaseInsensitiveContains(query) || ($0.location?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    private func statusColor(_ status: HomeItemStockStatus?) -> Color {
        switch status {
        case .enough: MHTheme.cyan
        case .low: MHTheme.warning
        case .empty: MHTheme.coral
        case nil: MHTheme.secondaryText
        }
    }
}

private struct HomeItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    private let itemID: UUID?

    @State private var name: String
    @State private var location: String
    @State private var quantity: String
    @State private var status: HomeItemStockStatus?
    @State private var notes: String
    @State private var accessory: String

    init(item: HomeItem? = nil) {
        itemID = item?.id
        _name = State(initialValue: item?.name ?? "")
        _location = State(initialValue: item?.location ?? "")
        _quantity = State(initialValue: item?.quantity ?? "")
        _status = State(initialValue: item?.status)
        _notes = State(initialValue: item?.notes ?? "")
        _accessory = State(initialValue: item?.accessory ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("物品") {
                    TextField("物品名（必填）", text: $name)
                    TextField("当前位置（自由填写）", text: $location)
                    TextField("数量（可选）", text: $quantity)
                    Picker("状态", selection: $status) {
                        Text("不指定").tag(HomeItemStockStatus?.none)
                        ForEach(HomeItemStockStatus.allCases) { value in
                            Text(value.title).tag(HomeItemStockStatus?.some(value))
                        }
                    }
                }
                Section("补充信息") {
                    TextField("配件或容器", text: $accessory)
                    TextField("备注", text: $notes, axis: .vertical)
                }
                if let itemID,
                   let item = store.database.homeItems.first(where: { $0.id == itemID }),
                   !item.locationHistory.isEmpty {
                    Section("位置历史") {
                        ForEach(item.locationHistory.reversed()) { change in
                            HStack {
                                Text(change.location)
                                Spacer()
                                Text(change.changedAt, format: .dateTime.month().day())
                                    .font(.caption)
                                    .foregroundStyle(MHTheme.secondaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle(itemID == nil ? "新增物品" : "编辑物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save(); dismiss() } label: { Image(systemName: "checkmark") }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        if let itemID {
            store.updateHomeItem(id: itemID, name: name, location: location, quantity: quantity, status: status, notes: notes, accessory: accessory)
        } else {
            _ = store.createHomeItem(name: name, location: location, quantity: quantity, status: status, notes: notes, accessory: accessory)
        }
    }
}


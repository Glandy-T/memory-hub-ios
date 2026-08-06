import SwiftUI

private enum FridgeSection: String, CaseIterable, Identifiable {
    case contents = "冰箱内容"
    case shopping = "待采购"
    var id: String { rawValue }
}

struct FridgeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var section = FridgeSection.contents
    @State private var showingEditor = false
    @State private var editingItem: FridgeItem?
    @State private var showingNewPurchase = false
    @State private var completedPurchase: PurchaseItem?

    var body: some View {
        List {
            Picker("分区", selection: $section) {
                ForEach(FridgeSection.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if section == .contents {
                contentsSection
            } else {
                shoppingSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("冰箱")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    FridgeHistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("冰箱历史")

                Button {
                    if section == .contents { showingEditor = true } else { showingNewPurchase = true }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(section == .contents ? "新增食材" : "新增采购项")
            }
        }
        .sheet(isPresented: $showingEditor) { FridgeItemEditor() }
        .sheet(item: $editingItem) { FridgeItemEditor(item: $0) }
        .sheet(isPresented: $showingNewPurchase) {
            TextEntrySheet(title: "新增采购项", placeholder: "名称", confirmTitle: "添加") {
                _ = store.addPurchaseItem(name: $0)
            }
        }
        .overlay(alignment: .bottom) {
            if let item = completedPurchase {
                HStack {
                    Text("已从采购清单移除")
                    Spacer()
                    Button("撤销") {
                        store.restorePurchaseItem(item)
                        completedPurchase = nil
                    }
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(.regularMaterial, in: Capsule())
                .padding()
            }
        }
        .memoryHubPage()
    }

    @ViewBuilder
    private var contentsSection: some View {
        if store.activeFridgeItems.isEmpty {
            ContentUnavailableView("冰箱是空的", systemImage: "refrigerator", description: Text("只需填写名称即可添加。"))
                .listRowBackground(Color.clear)
        } else {
            ForEach(store.activeFridgeItems) { item in
                Button { editingItem = item } label: {
                    FridgeItemRow(item: item)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("吃完", systemImage: "checkmark") {
                        store.removeFridgeItem(id: item.id, reason: .eaten)
                    }
                    .tint(MHTheme.cyan)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("丢弃", systemImage: "trash", role: .destructive) {
                        store.removeFridgeItem(id: item.id, reason: .discarded)
                    }
                    Button("用完并采购", systemImage: "cart.badge.plus") {
                        store.removeFridgeItem(id: item.id, reason: .removed, addToPurchaseList: true)
                    }
                    .tint(MHTheme.violet)
                }
            }
        }
    }

    @ViewBuilder
    private var shoppingSection: some View {
        if store.database.purchaseItems.isEmpty {
            ContentUnavailableView("采购清单是空的", systemImage: "cart", description: Text("可手动添加，也可从冰箱内容生成。"))
                .listRowBackground(Color.clear)
        } else {
            ForEach(store.database.purchaseItems.sorted { $0.createdAt > $1.createdAt }) { item in
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .foregroundStyle(MHTheme.secondaryText)
                    Text(item.name)
                    Spacer()
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("已购买", systemImage: "checkmark") {
                        completedPurchase = store.completePurchaseItem(id: item.id)
                    }
                    .tint(MHTheme.cyan)
                    Button("购入冰箱", systemImage: "refrigerator") {
                        _ = store.completePurchaseItem(id: item.id)
                        _ = store.createFridgeItem(name: item.name, storage: nil, quantity: nil, expiryDate: nil, isOpened: false, notes: nil)
                        completedPurchase = nil
                    }
                    .tint(MHTheme.accent)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("移除", systemImage: "trash", role: .destructive) {
                        completedPurchase = store.completePurchaseItem(id: item.id)
                    }
                }
            }
        }
    }
}

private struct FridgeItemRow: View {
    let item: FridgeItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.storage == "冷冻" ? "snowflake" : "refrigerator")
                .foregroundStyle(item.storage == "冷冻" ? MHTheme.accent : MHTheme.cyan)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.body.weight(.semibold))
                HStack(spacing: 8) {
                    if let storage = item.storage { Text(storage) }
                    if let quantity = item.quantity { Text(quantity) }
                    if item.isOpened { Text("已开封") }
                }
                .font(.caption)
                .foregroundStyle(MHTheme.secondaryText)
            }
            Spacer()
            if let expiry = item.expiryDate {
                Text(expiry, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
            }
        }
        .frame(minHeight: 58)
    }
}

private struct FridgeItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    private let itemID: UUID?

    @State private var name: String
    @State private var storage: String
    @State private var quantity: String
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var isOpened: Bool
    @State private var notes: String

    init(item: FridgeItem? = nil) {
        itemID = item?.id
        _name = State(initialValue: item?.name ?? "")
        _storage = State(initialValue: item?.storage ?? "不指定")
        _quantity = State(initialValue: item?.quantity ?? "")
        _hasExpiry = State(initialValue: item?.expiryDate != nil)
        _expiryDate = State(initialValue: item?.expiryDate ?? Date())
        _isOpened = State(initialValue: item?.isOpened ?? false)
        _notes = State(initialValue: item?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("食材") {
                    TextField("名称（必填）", text: $name)
                    Picker("存放", selection: $storage) {
                        Text("不指定").tag("不指定")
                        Text("冷藏").tag("冷藏")
                        Text("冷冻").tag("冷冻")
                    }
                    TextField("数量，例如：半盒", text: $quantity)
                    Toggle("已开封", isOn: $isOpened)
                }
                Section("到期日期") {
                    Toggle("设置日期", isOn: $hasExpiry)
                    if hasExpiry { DatePicker("日期", selection: $expiryDate, displayedComponents: .date) }
                }
                Section("备注") { TextField("可选", text: $notes, axis: .vertical) }
            }
            .navigationTitle(itemID == nil ? "新增食材" : "编辑食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save(); dismiss() } label: { Image(systemName: "checkmark") }
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel(itemID == nil ? "创建食材" : "保存食材")
                }
            }
        }
    }

    private func save() {
        let storageValue = storage == "不指定" ? nil : storage
        if let itemID {
            store.updateFridgeItem(id: itemID, name: name, storage: storageValue, quantity: quantity, expiryDate: hasExpiry ? expiryDate : nil, isOpened: isOpened, notes: notes)
        } else {
            _ = store.createFridgeItem(name: name, storage: storageValue, quantity: quantity, expiryDate: hasExpiry ? expiryDate : nil, isOpened: isOpened, notes: notes)
        }
    }
}

private struct FridgeHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var deletingForever: FridgeItem?

    var body: some View {
        List {
            if store.fridgeHistoryItems.isEmpty {
                ContentUnavailableView("没有冰箱历史", systemImage: "clock", description: Text("移除的项目保留 15 天。"))
            } else {
                ForEach(store.fridgeHistoryItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                            Text(item.removalReason?.title ?? "已移除")
                                .font(.caption)
                                .foregroundStyle(MHTheme.secondaryText)
                        }
                        Spacer()
                        Button("恢复") { store.restoreFridgeItem(id: item.id) }
                            .buttonStyle(.bordered)
                        Menu {
                            Button("永久删除", systemImage: "trash", role: .destructive) {
                                deletingForever = item
                            }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    }
                }
            }
        }
        .navigationTitle("冰箱历史")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .alert(
            "永久删除“\(deletingForever?.name ?? "")”？",
            isPresented: Binding(
                get: { deletingForever != nil },
                set: { if !$0 { deletingForever = nil } }
            )
        ) {
            Button("永久删除", role: .destructive) {
                if let id = deletingForever?.id { store.permanentlyDeleteFridgeItem(id: id) }
                deletingForever = nil
            }
            Button("取消", role: .cancel) { deletingForever = nil }
        } message: {
            Text("此操作无法撤销。")
        }
        .memoryHubPage()
    }
}

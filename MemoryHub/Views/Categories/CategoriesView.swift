import SwiftUI

private enum CategoryRoute: Hashable {
    case documents(UUID)
    case document(UUID)
}

struct CategoriesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var showingNewCategory = false
    @State private var isManaging = false
    @State private var renamingCategory: MemoryCategory?
    @State private var coloringCategory: MemoryCategory?
    @State private var deletingCategory: MemoryCategory?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isManaging {
                    managementList
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            searchField

                            ForEach(filteredCategories) { category in
                                NavigationLink(value: CategoryRoute.documents(category.id)) {
                                    CategoryRow(category: category)
                                }
                                .buttonStyle(.plain)
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    withAnimation(.easeInOut(duration: 0.2)) { isManaging = true }
                                }
                            }
                        }
                        .padding(.horizontal, MHTheme.pagePadding)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle(isManaging ? "管理分类" : "分类")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isManaging {
                        Button("完成") { withAnimation { isManaging = false } }
                    } else {
                        Menu {
                            Button("新增分类", systemImage: "plus") { showingNewCategory = true }
                            Button("管理分类", systemImage: "slider.horizontal.3") { isManaging = true }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }
                    }
                }
            }
            .navigationDestination(for: CategoryRoute.self) { route in
                switch route {
                case .documents(let categoryID):
                    DocumentListView(
                        categoryID: categoryID,
                        onOpen: { path.append(CategoryRoute.document($0)) },
                        onCreated: { path.append(CategoryRoute.document($0)) }
                    )
                case .document(let documentID):
                    DocumentDetailView(documentID: documentID)
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                TextEntrySheet(
                    title: "新增分类",
                    placeholder: "分类名称",
                    confirmTitle: "创建"
                ) { name in
                    _ = store.createCategory(name: name)
                }
            }
            .sheet(item: $renamingCategory) { category in
                TextEntrySheet(
                    title: "重命名分类",
                    placeholder: "分类名称",
                    initialText: category.name,
                    confirmTitle: "完成"
                ) { store.renameCategory(id: category.id, name: $0) }
            }
            .sheet(item: $coloringCategory) { category in
                CategoryColorSheet(category: category)
            }
            .confirmationDialog(
                "删除“\(deletingCategory?.name ?? "")”？",
                isPresented: Binding(
                    get: { deletingCategory != nil },
                    set: { if !$0 { deletingCategory = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let category = deletingCategory {
                    if store.documents(in: category.id).isEmpty {
                        Button("移入回收站", role: .destructive) {
                            store.softDeleteCategory(id: category.id, moveDocumentsToDefault: false)
                            deletingCategory = nil
                        }
                    } else {
                        Button("文档移到默认分类，再删除分类") {
                            store.softDeleteCategory(id: category.id, moveDocumentsToDefault: true)
                            deletingCategory = nil
                        }
                        Button("分类和文档一起移入回收站", role: .destructive) {
                            store.softDeleteCategory(id: category.id, moveDocumentsToDefault: false)
                            deletingCategory = nil
                        }
                    }
                }
                Button("取消", role: .cancel) { deletingCategory = nil }
            } message: {
                Text("普通删除可以稍后从回收站恢复。")
            }
            .memoryHubPage()
        }
    }

    private var filteredCategories: [MemoryCategory] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return store.activeCategories
        }
        return store.activeCategories.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MHTheme.secondaryText)
            TextField("搜索分类", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(MHTheme.fieldBackground, in: RoundedRectangle(cornerRadius: MHTheme.controlRadius))
        .padding(.bottom, 10)
    }

    private var managementList: some View {
        List {
            Section("拖动排序") {
                ForEach(store.activeCategories) { category in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: category.colorHex))
                            .frame(width: 10, height: 10)
                        Text(category.name)
                            .font(.body.weight(.semibold))
                        if category.isDefault {
                            Text("默认")
                                .font(.caption2)
                                .foregroundStyle(MHTheme.secondaryText)
                        }
                        Spacer()
                        Menu {
                            Button("重命名", systemImage: "pencil") { renamingCategory = category }
                            Button("更改颜色", systemImage: "paintpalette") { coloringCategory = category }
                            if !category.isDefault {
                                Button("删除分类", systemImage: "trash", role: .destructive) {
                                    deletingCategory = category
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }
                    }
                    .listRowBackground(MHTheme.raisedBackground)
                }
                .onMove { source, destination in
                    var ids = store.activeCategories.map(\.id)
                    ids.move(fromOffsets: source, toOffset: destination)
                    store.reorderCategories(ids: ids)
                }

                Button("新增分类", systemImage: "plus") { showingNewCategory = true }
                    .frame(minHeight: 44)
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }
}

private struct CategoryColorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let category: MemoryCategory

    private let colors = ["8F7CF6", "2A6BEA", "41C7BE", "FFC94A", "FF6E67", "D06BE5"]

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 22) {
                ForEach(colors, id: \.self) { hex in
                    Button {
                        store.updateCategoryColor(id: category.id, colorHex: hex)
                        dismiss()
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 52, height: 52)
                            .overlay {
                                if category.colorHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .accessibilityLabel("选择颜色")
                }
            }
            .padding(28)
            .navigationTitle("分类颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .memoryHubPage()
        }
        .presentationDetents([.height(300)])
    }
}

private struct CategoryRow: View {
    let category: MemoryCategory

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 10, height: 10)
            Text(category.name)
                .font(.body.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MHTheme.secondaryText)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 58)
        .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

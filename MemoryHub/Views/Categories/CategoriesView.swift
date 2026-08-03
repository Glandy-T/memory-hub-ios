import SwiftUI

private enum CategoryRoute: Hashable {
    case documents(UUID)
    case document(UUID)
}

struct CategoriesView: View {
    @EnvironmentObject private var store: AppStore
    @Binding private var path: NavigationPath
    @State private var query = ""
    @State private var showingNewCategory = false
    @State private var isManaging = ProcessInfo.processInfo.arguments.contains("--memory-hub-screenshot-category-management")
    @State private var didApplyScreenshotRoute = false
    @State private var renamingCategory: MemoryCategory?
    @State private var coloringCategory: MemoryCategory?
    @State private var deletingCategory: MemoryCategory?

    init(path: Binding<NavigationPath> = .constant(NavigationPath())) {
        _path = path
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isManaging {
                    managementList
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            searchField

                            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Rectangle()
                                    .fill(MHTheme.hairline.opacity(0.72))
                                    .frame(height: 1)
                                    .padding(.top, 18)

                                Text("全部分类")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 20)
                                    .padding(.bottom, 14)

                                LazyVStack(spacing: 14) {
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
                            } else {
                                GlobalSearchResultsView(
                                    query: query,
                                    openCategory: { path.append(CategoryRoute.documents($0)) },
                                    openDocument: { path.append(CategoryRoute.document($0)) }
                                )
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
                NewCategorySheet()
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
            .onAppear(perform: applyScreenshotRouteIfNeeded)
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
            TextField("搜索全部内容", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MHTheme.hairline.opacity(0.72), lineWidth: 1)
        }
    }

    private var managementList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("拖动排序 · 更多操作可修改或删除")
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
                    .padding(.bottom, 14)

                LazyVStack(spacing: 10) {
                    ForEach(store.activeCategories) { category in
                        ManagementCategoryRow(
                            category: category,
                            rename: { renamingCategory = category },
                            recolor: { coloringCategory = category },
                            delete: { deletingCategory = category },
                            move: { draggedID in reorderCategory(draggedID, over: category.id) }
                        )
                    }
                }

                Button("新增分类", systemImage: "plus") { showingNewCategory = true }
                    .frame(minHeight: 44)
                    .padding(.top, 10)
            }
            .padding(.horizontal, MHTheme.pagePadding)
            .padding(.bottom, 110)
        }
    }

    private func reorderCategory(_ draggedID: UUID, over targetID: UUID) {
        var ids = store.activeCategories.map(\.id)
        guard let source = ids.firstIndex(of: draggedID),
              let target = ids.firstIndex(of: targetID),
              source != target else { return }
        let moved = ids.remove(at: source)
        ids.insert(moved, at: min(target, ids.endIndex))
        store.reorderCategories(ids: ids)
    }

    private func applyScreenshotRouteIfNeeded() {
        guard !didApplyScreenshotRoute else { return }
        didApplyScreenshotRoute = true
        let arguments = ProcessInfo.processInfo.arguments
        guard let certificate = store.activeCategories.first(where: { $0.name == "证件" }) else { return }

        if arguments.contains("--memory-hub-screenshot-document-list") ||
            arguments.contains("--memory-hub-screenshot-document-list-editing") {
            path.append(CategoryRoute.documents(certificate.id))
        } else if arguments.contains("--memory-hub-screenshot-document-detail"),
                  let document = store.documents(in: certificate.id).first(where: { $0.title == "旅行证件放在哪里" }) {
            path.append(CategoryRoute.documents(certificate.id))
            path.append(CategoryRoute.document(document.id))
        }
    }
}

private struct NewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var selectedColor = "41C7BE"

    private let colors = ["8F7CF6", "2A6BEA", "41C7BE", "FFC94A", "FF6E67", "D06BE5"]

    var body: some View {
        NavigationStack {
            Form {
                Section("分类名称") {
                    TextField("输入分类名称", text: $name)
                        .submitLabel(.done)
                }

                Section("分类颜色") {
                    HStack(spacing: 18) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .padding(4)
                                    .overlay {
                                        if selectedColor == hex {
                                            Circle()
                                                .stroke(Color(hex: hex).opacity(0.82), lineWidth: 2)
                                        }
                                    }
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("选择分类颜色")
                            .accessibilityAddTraits(selectedColor == hex ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("新增分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        if store.createCategory(name: name, colorHex: selectedColor) != nil {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ManagementCategoryRow: View {
    let category: MemoryCategory
    let rename: () -> Void
    let recolor: () -> Void
    let delete: () -> Void
    let move: (UUID) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.caption2)
                .foregroundStyle(MHTheme.secondaryText)
                .frame(width: 24, height: 44)
                .draggable(category.id.uuidString)

            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 12, height: 12)

            Text(category.name)
                .font(.body.weight(.semibold))

            Spacer()

            Menu {
                Button("重命名", systemImage: "pencil", action: rename)
                Button("更改颜色", systemImage: "paintpalette", action: recolor)
                if !category.isDefault {
                    Button("删除分类", systemImage: "trash", role: .destructive, action: delete)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(MHTheme.secondaryText)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MHTheme.hairline.opacity(0.72), lineWidth: 1)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let value = items.first, let id = UUID(uuidString: value) else { return false }
            move(id)
            return true
        }
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
                .frame(width: 12, height: 12)
            Text(category.name)
                .font(.body.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 54)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MHTheme.hairline.opacity(0.72), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

import SwiftUI

struct DocumentListView: View {
    @EnvironmentObject private var store: AppStore
    let categoryID: UUID
    let onOpen: (UUID) -> Void
    let onCreated: (UUID) -> Void

    @State private var isEditing = ProcessInfo.processInfo.arguments.contains("--memory-hub-screenshot-document-list-editing")
    @State private var showingNewDocument = false
    @State private var renamingDocument: MemoryDocument?
    @State private var deletingDocument: MemoryDocument?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isEditing {
                    HStack {
                        Text("勾选加入提醒池 · 更多可管理文档")
                        Spacer()
                        Text("候选池 \(documents.filter(\.isInReminderPool).count) 篇")
                            .foregroundStyle(MHTheme.violet)
                    }
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
                    .padding(.bottom, 8)
                }

                if documents.isEmpty {
                    ContentUnavailableView(
                        "这里还没有文档",
                        systemImage: "doc",
                        description: Text("先创建标题，再进入文档添加记录。")
                    )
                    .padding(.top, 100)
                } else {
                    ForEach(documents) { document in
                        if isEditing {
                            EditableDocumentRow(
                                document: document,
                                hasDraft: store.hasDraft(in: document.id),
                                toggleReminder: { store.toggleReminderPool(documentID: document.id) },
                                rename: { renamingDocument = document },
                                archive: { store.archiveDocument(id: document.id) },
                                delete: { deletingDocument = document }
                            )
                        } else {
                            Button {
                                onOpen(document.id)
                            } label: {
                                DocumentRow(document: document, hasDraft: store.hasDraft(in: document.id))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, MHTheme.pagePadding)
            .padding(.bottom, 110)
        }
        .overlay(alignment: .bottom) {
            if !isEditing {
                Button { showingNewDocument = true } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(MHTheme.accent, in: Circle())
                        .shadow(color: MHTheme.accent.opacity(0.28), radius: 16, y: 8)
                }
                .padding(.bottom, 22)
                .accessibilityLabel("新建文档")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: category?.colorHex ?? "8F7CF6"))
                        .frame(width: 8, height: 8)
                    Text(category?.name ?? "文档")
                        .font(.headline)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "完成" : "编辑") { isEditing.toggle() }
            }
        }
        .sheet(isPresented: $showingNewDocument) {
            TextEntrySheet(title: "新建文档", placeholder: "文档标题", confirmTitle: "创建") { title in
                if let id = store.createDocument(title: title, categoryID: categoryID) {
                    onCreated(id)
                }
            }
        }
        .sheet(item: $renamingDocument) { document in
            TextEntrySheet(title: "修改标题", placeholder: "文档标题", initialText: document.title, confirmTitle: "完成") { title in
                store.renameDocument(id: document.id, title: title)
            }
        }
        .alert(
            "删除“\(deletingDocument?.title ?? "")”？",
            isPresented: Binding(
                get: { deletingDocument != nil },
                set: { if !$0 { deletingDocument = nil } }
            )
        ) {
            Button("取消", role: .cancel) { deletingDocument = nil }
            Button("删除", role: .destructive) {
                if let id = deletingDocument?.id { store.softDeleteDocument(id: id) }
                deletingDocument = nil
            }
        } message: {
            Text("文档与其中的记录会一起移入回收站，之后可以恢复。")
        }
        .memoryHubPage()
    }

    private var category: MemoryCategory? { store.category(id: categoryID) }
    private var documents: [MemoryDocument] { store.documents(in: categoryID) }
}

struct DocumentRow: View {
    let document: MemoryDocument
    let hasDraft: Bool

    var body: some View {
        DocumentRowContent(document: document, hasDraft: hasDraft)
            .overlay(alignment: .bottom) {
                Rectangle().fill(MHTheme.hairline.opacity(0.72)).frame(height: 1)
            }
        .contentShape(Rectangle())
    }
}

private struct DocumentRowContent: View {
    let document: MemoryDocument
    let hasDraft: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(document.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MHTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if hasDraft {
                    Circle()
                        .fill(MHTheme.coral)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("有草稿")
                }
            }
            .padding(.top, 8)

            Text("\(document.updatedAt.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN"))))编辑")
                .font(.caption2)
                .foregroundStyle(MHTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(height: 78)
    }
}

private struct EditableDocumentRow: View {
    let document: MemoryDocument
    let hasDraft: Bool
    let toggleReminder: () -> Void
    let rename: () -> Void
    let archive: () -> Void
    let delete: () -> Void

    var body: some View {
        DocumentRowContent(document: document, hasDraft: hasDraft)
            .padding(.leading, 34)
            .padding(.trailing, 44)
            .overlay(alignment: .topLeading) {
                Button(action: toggleReminder) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(document.isInReminderPool ? MHTheme.violet : Color.clear)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(
                                document.isInReminderPool ? MHTheme.violet : MHTheme.secondaryText.opacity(0.72),
                                lineWidth: 1
                            )
                        if document.isInReminderPool {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 20, height: 20)
                }
                .frame(width: 44, height: 44)
                .offset(x: -12, y: -8)
                .accessibilityLabel(document.isInReminderPool ? "移出提醒池" : "加入提醒池")
            }
            .overlay(alignment: .topTrailing) {
                Menu {
                    Button("修改标题", systemImage: "pencil", action: rename)
                    Button("归档文档", systemImage: "archivebox", action: archive)
                    Button("删除文档", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(MHTheme.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("文档操作")
                .offset(y: -8)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MHTheme.hairline.opacity(0.72))
                    .frame(height: 1)
                    .padding(.leading, 34)
            }
    }
}

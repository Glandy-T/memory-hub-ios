import SwiftUI

struct DocumentListView: View {
    @EnvironmentObject private var store: AppStore
    let categoryID: UUID
    let onOpen: (UUID) -> Void
    let onCreated: (UUID) -> Void

    @State private var isEditing = false
    @State private var showingNewDocument = false
    @State private var renamingDocument: MemoryDocument?
    @State private var deletingDocument: MemoryDocument?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isEditing {
                    HStack {
                        Text("勾选加入首页提醒池")
                        Spacer()
                        Text("已加入 \(documents.filter(\.isInReminderPool).count) 篇")
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
        .navigationTitle(category?.name ?? "文档")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
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
        .confirmationDialog(
            "删除“\(deletingDocument?.title ?? "")”？",
            isPresented: Binding(
                get: { deletingDocument != nil },
                set: { if !$0 { deletingDocument = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("移入回收站", role: .destructive) {
                if let id = deletingDocument?.id { store.softDeleteDocument(id: id) }
                deletingDocument = nil
            }
            Button("取消", role: .cancel) { deletingDocument = nil }
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(document.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(MHTheme.primaryText)
                Text(document.updatedAt, format: .dateTime.month().day().locale(Locale(identifier: "zh_CN")))
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if hasDraft {
                Circle()
                    .fill(MHTheme.coral)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("有草稿")
            }
        }
        .frame(minHeight: 78)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MHTheme.hairline).frame(height: 1)
        }
        .contentShape(Rectangle())
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
        HStack(spacing: 8) {
            Button(action: toggleReminder) {
                Image(systemName: document.isInReminderPool ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(document.isInReminderPool ? MHTheme.violet : MHTheme.secondaryText)
                    .frame(width: 44, height: 44)
            }
            DocumentRow(document: document, hasDraft: hasDraft)
            Menu {
                Button("修改标题", systemImage: "pencil", action: rename)
                Button("归档文档", systemImage: "archivebox", action: archive)
                Button("删除文档", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(MHTheme.secondaryText)
                    .frame(width: 44, height: 44)
            }
        }
    }
}

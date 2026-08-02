import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var store: AppStore
    @State private var deletingDocument: MemoryDocument?

    var body: some View {
        List {
            if documents.isEmpty {
                ContentUnavailableView("归档是空的", systemImage: "archivebox", description: Text("归档文档不会出现在普通分类列表中。"))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(documents) { document in
                    NavigationLink {
                        DocumentDetailView(documentID: document.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title).font(.body.weight(.medium))
                            Text(store.category(id: document.categoryID)?.name ?? "未分类")
                                .font(.caption)
                                .foregroundStyle(MHTheme.secondaryText)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("恢复", systemImage: "arrow.uturn.backward") {
                            store.restoreArchivedDocument(id: document.id)
                        }
                        .tint(MHTheme.cyan)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("删除", systemImage: "trash", role: .destructive) { deletingDocument = document }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("归档")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert(
            "删除“\(deletingDocument?.title ?? "")”？",
            isPresented: Binding(get: { deletingDocument != nil }, set: { if !$0 { deletingDocument = nil } })
        ) {
            Button("移入回收站", role: .destructive) {
                if let id = deletingDocument?.id { store.softDeleteDocument(id: id) }
                deletingDocument = nil
            }
            Button("取消", role: .cancel) { deletingDocument = nil }
        } message: {
            Text("归档与删除是不同状态，删除后仍可从回收站恢复。")
        }
        .memoryHubPage()
    }

    private var documents: [MemoryDocument] {
        store.database.documents.filter { $0.isArchived && !$0.isDeleted }.sorted { $0.updatedAt > $1.updatedAt }
    }
}


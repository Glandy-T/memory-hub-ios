import SwiftUI

struct ReminderPoolView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            if documents.isEmpty {
                ContentUnavailableView(
                    "提醒池是空的",
                    systemImage: "doc.badge.clock",
                    description: Text("请到分类内的文档列表点“编辑”，勾选想偶尔回看的文档。")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("已加入的文档") {
                    ForEach(documents) { document in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: store.category(id: document.categoryID)?.colorHex ?? "8F7CF6"))
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.title)
                                    .font(.body.weight(.medium))
                                Text(store.category(id: document.categoryID)?.name ?? "未分类")
                                    .font(.caption)
                                    .foregroundStyle(MHTheme.secondaryText)
                            }
                            Spacer()
                            Button("移除") {
                                store.removeDocumentFromReminderPool(documentID: document.id)
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(minHeight: 58)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("文档提醒池")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .memoryHubPage()
    }

    private var documents: [MemoryDocument] {
        store.database.documents
            .filter { $0.isInReminderPool && !$0.isDeleted && !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}


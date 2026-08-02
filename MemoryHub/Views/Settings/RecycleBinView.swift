import SwiftUI

private enum TrashTarget: Identifiable {
    case category(MemoryCategory)
    case document(MemoryDocument)
    case record(MemoryRecord)
    case calendar(CalendarItem)

    var id: String {
        switch self {
        case .category(let value): "category-\(value.id)"
        case .document(let value): "document-\(value.id)"
        case .record(let value): "record-\(value.id)"
        case .calendar(let value): "calendar-\(value.id)"
        }
    }

    var title: String {
        switch self {
        case .category(let value): value.name
        case .document(let value): value.title
        case .record(let value): value.publishedContent ?? "记录草稿"
        case .calendar(let value): value.title
        }
    }
}

struct RecycleBinView: View {
    @EnvironmentObject private var store: AppStore
    @State private var permanentlyDeleting: TrashTarget?

    var body: some View {
        List {
            if isEmpty {
                ContentUnavailableView(
                    "回收站是空的",
                    systemImage: "trash",
                    description: Text("普通删除的内容会先保留在这里。")
                )
                .listRowBackground(Color.clear)
            }

            if !deletedCategories.isEmpty {
                Section("分类") {
                    ForEach(deletedCategories) { category in
                        TrashRow(
                            title: category.name,
                            detail: "包含 \(deletedDocumentsInCategory(category.id).count) 篇随分类删除的文档",
                            restore: { store.restoreCategory(id: category.id) },
                            permanentlyDelete: { permanentlyDeleting = .category(category) }
                        )
                    }
                }
            }

            if !standaloneDeletedDocuments.isEmpty {
                Section("文档") {
                    ForEach(standaloneDeletedDocuments) { document in
                        TrashRow(
                            title: document.title,
                            detail: store.category(id: document.categoryID)?.name ?? "原分类不可用",
                            restore: { store.restoreDocument(id: document.id) },
                            permanentlyDelete: { permanentlyDeleting = .document(document) }
                        )
                    }
                }
            }

            if !standaloneDeletedRecords.isEmpty {
                Section("记录") {
                    ForEach(standaloneDeletedRecords) { record in
                        TrashRow(
                            title: record.publishedContent ?? "未命名记录",
                            detail: store.document(id: record.documentID)?.title ?? "原文档不可用",
                            restore: { store.restoreRecord(id: record.id) },
                            permanentlyDelete: { permanentlyDeleting = .record(record) }
                        )
                    }
                }
            }

            if !deletedCalendarItems.isEmpty {
                Section("日历事项") {
                    ForEach(deletedCalendarItems) { item in
                        TrashRow(
                            title: item.title,
                            detail: item.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))),
                            restore: { store.restoreCalendarItem(id: item.id) },
                            permanentlyDelete: { permanentlyDeleting = .calendar(item) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert(
            "永久删除“\(permanentlyDeleting?.title ?? "")”？",
            isPresented: Binding(
                get: { permanentlyDeleting != nil },
                set: { if !$0 { permanentlyDeleting = nil } }
            )
        ) {
            Button("永久删除", role: .destructive) {
                performPermanentDelete()
                permanentlyDeleting = nil
            }
            Button("取消", role: .cancel) { permanentlyDeleting = nil }
        } message: {
            Text("此操作无法撤销。")
        }
        .memoryHubPage()
    }

    private var deletedCategories: [MemoryCategory] {
        store.database.categories.filter(\.isDeleted)
    }

    private var standaloneDeletedDocuments: [MemoryDocument] {
        store.database.documents.filter { $0.isDeleted && $0.deletedByCategoryID == nil }
    }

    private var standaloneDeletedRecords: [MemoryRecord] {
        store.database.records.filter {
            $0.isDeleted && $0.deletedByDocumentID == nil && store.document(id: $0.documentID)?.isDeleted == false
        }
    }

    private var deletedCalendarItems: [CalendarItem] {
        store.database.calendarItems.filter { $0.deletedAt != nil }
    }

    private var isEmpty: Bool {
        deletedCategories.isEmpty && standaloneDeletedDocuments.isEmpty && standaloneDeletedRecords.isEmpty && deletedCalendarItems.isEmpty
    }

    private func deletedDocumentsInCategory(_ id: UUID) -> [MemoryDocument] {
        store.database.documents.filter { $0.deletedByCategoryID == id }
    }

    private func performPermanentDelete() {
        guard let target = permanentlyDeleting else { return }
        switch target {
        case .category(let value): store.permanentlyDeleteCategory(id: value.id)
        case .document(let value): store.permanentlyDeleteDocument(id: value.id)
        case .record(let value): store.permanentlyDeleteRecord(id: value.id)
        case .calendar(let value): store.permanentlyDeleteCalendarItem(id: value.id)
        }
    }
}

private struct TrashRow: View {
    let title: String
    let detail: String
    let restore: () -> Void
    let permanentlyDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
            }
            Spacer()
            Button("恢复", action: restore)
                .buttonStyle(.bordered)
            Menu {
                Button("永久删除", systemImage: "trash", role: .destructive, action: permanentlyDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
        }
        .frame(minHeight: 62)
    }
}

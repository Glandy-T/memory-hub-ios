import SwiftUI

struct DocumentDetailView: View {
    @EnvironmentObject private var store: AppStore
    let documentID: UUID

    @State private var deletingRecord: MemoryRecord?
    @State private var editingRecord: MemoryRecord?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Text("\(category?.name ?? "未分类") · 共 \(publishedRecordCount) 条记录")
                    .font(.footnote)
                    .foregroundStyle(MHTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 18)

                Rectangle()
                    .fill(MHTheme.hairline.opacity(0.88))
                    .frame(height: 1)

                if visibleRecords.isEmpty {
                    emptyState
                } else {
                    ForEach(visibleRecords) { record in
                        if let content = record.publishedContent {
                            PublishedRecordRow(
                                record: record,
                                content: content,
                                edit: { edit(record) },
                                delete: { deletingRecord = record }
                            )
                        } else if let draft = record.draftContent,
                                  !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            DraftRecordRow(
                                record: record,
                                content: draft,
                                open: { editingRecord = record },
                                discard: { store.discardDraft(recordID: record.id) }
                            )
                        }
                    }
                }

                Button(action: addDraft) {
                    Label(
                        visibleRecords.isEmpty ? "添加第一条记录" : "添加一条记录",
                        systemImage: "plus"
                    )
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(MHTheme.accent)
                    .background(
                        MHTheme.raisedBackground.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: MHTheme.controlRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: MHTheme.controlRadius, style: .continuous)
                            .stroke(
                                MHTheme.accent.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1, dash: [5])
                            )
                    }
                }
                .padding(.top, visibleRecords.isEmpty ? 18 : 22)
            }
            .padding(.horizontal, MHTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonDisplayMode(.minimal)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: category?.colorHex ?? "8F7CF6"))
                        .frame(width: 8, height: 8)
                    Text(document?.title ?? "文档")
                        .font(.headline)
                        .lineLimit(1)
                }
            }
        }
        .sheet(item: $editingRecord) { record in
            RecordEditorSheet(record: record)
        }
        .alert(
            "删除这条记录？",
            isPresented: Binding(
                get: { deletingRecord != nil },
                set: { if !$0 { deletingRecord = nil } }
            )
        ) {
            Button("取消", role: .cancel) { deletingRecord = nil }
            Button("删除", role: .destructive) {
                if let id = deletingRecord?.id { store.softDeleteRecord(id: id) }
                deletingRecord = nil
            }
        } message: {
            Text("删除后可从“我的 → 回收站”恢复。")
        }
        .memoryHubPage()
    }

    private var document: MemoryDocument? { store.document(id: documentID) }
    private var category: MemoryCategory? {
        guard let categoryID = document?.categoryID else { return nil }
        return store.category(id: categoryID)
    }
    private var records: [MemoryRecord] { store.records(in: documentID) }
    private var visibleRecords: [MemoryRecord] {
        records.filter { $0.publishedContent != nil || $0.isDraft }
    }
    private var publishedRecordCount: Int {
        records.filter { $0.publishedContent != nil }.count
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Text("这里还没有记录")
                .font(.headline)
            Text("先添加第一条内容，未完成时会自动保存为草稿")
                .font(.footnote)
                .foregroundStyle(MHTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 205)
    }

    private func addDraft() {
        let id = store.createRecordDraft(documentID: documentID)
        editingRecord = store.database.records.first { $0.id == id }
    }

    private func edit(_ record: MemoryRecord) {
        store.beginEditingRecord(id: record.id)
        editingRecord = store.database.records.first { $0.id == record.id }
    }
}

private struct PublishedRecordRow: View {
    let record: MemoryRecord
    let content: String
    let edit: () -> Void
    let delete: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(documentTimestamp(record.createdAt))
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
                Spacer()
                Button("删除", role: .destructive, action: delete)
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText.opacity(0.78))
                    .frame(minWidth: 44, minHeight: 44)
            }

            Button(action: edit) {
                Text(renderedContent)
                    .font(.subheadline)
                    .foregroundStyle(MHTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(isExpanded ? nil : 9)
            }
            .buttonStyle(.plain)

            if content.count > 280 {
                Button(isExpanded ? "收起" : "展开全文") {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MHTheme.accent)
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MHTheme.hairline.opacity(0.88)).frame(height: 1)
        }
    }

    private var renderedContent: AttributedString {
        (try? AttributedString(markdown: content)) ?? AttributedString(content)
    }
}

private struct DraftRecordRow: View {
    let record: MemoryRecord
    let content: String
    let open: () -> Void
    let discard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("草稿", systemImage: "pencil.line")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MHTheme.violet)
                Spacer()
                Button("放弃", role: .destructive, action: discard)
                    .font(.caption)
                    .frame(minWidth: 44, minHeight: 44)
            }

            Button(action: open) {
                Text(content)
                    .font(.body)
                    .foregroundStyle(MHTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MHTheme.hairline.opacity(0.88)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("未完成的记录草稿")
    }
}

private struct RecordEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let record: MemoryRecord

    @State private var text: String

    init(record: MemoryRecord) {
        self.record = record
        _text = State(initialValue: record.draftContent ?? record.publishedContent ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 8, height: 8)
                    Text(documentTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(documentTimestamp(record.createdAt))
                    .font(.footnote)
                    .foregroundStyle(MHTheme.secondaryText)

                Rectangle()
                    .fill(MHTheme.hairline.opacity(0.88))
                    .frame(height: 1)

                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .onChange(of: text) { _, value in
                        store.updateDraft(recordID: record.id, content: value)
                    }

                HStack {
                    Menu {
                        ForEach(["当前状态", "下一步", "问题", "备注"], id: \.self) { heading in
                            Button(heading) { insertHeading(heading) }
                        }
                    } label: {
                        Label("小标题", systemImage: "plus")
                    }

                    Spacer()

                    Button("放弃草稿", role: .destructive) {
                        store.discardDraft(recordID: record.id)
                        dismiss()
                    }
                }
                .font(.subheadline)
            }
            .padding(MHTheme.pagePadding)
            .navigationTitle(record.publishedContent == nil ? "新增记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        store.publishDraft(recordID: record.id)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .memoryHubPage()
        }
        .presentationDetents([.large])
        .onDisappear {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.discardDraft(recordID: record.id)
            }
        }
    }

    private var document: MemoryDocument? {
        store.document(id: record.documentID)
    }

    private var documentTitle: String {
        document?.title ?? "文档"
    }

    private var categoryColor: Color {
        guard let categoryID = document?.categoryID,
              let category = store.category(id: categoryID) else { return MHTheme.violet }
        return Color(hex: category.colorHex)
    }

    private func insertHeading(_ heading: String) {
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        text += "\(prefix)## \(heading)\n"
        store.updateDraft(recordID: record.id, content: text)
    }
}

private func documentTimestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_Hans_CN")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy年M月d日 · HH:mm"
    return formatter.string(from: date)
}

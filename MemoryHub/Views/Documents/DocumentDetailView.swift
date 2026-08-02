import SwiftUI

struct DocumentDetailView: View {
    @EnvironmentObject private var store: AppStore
    let documentID: UUID

    @State private var deletingRecord: MemoryRecord?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                if records.isEmpty {
                    emptyState
                } else {
                    ForEach(records) { record in
                        if record.draftContent != nil {
                            RecordDraftEditor(record: record)
                        } else if let content = record.publishedContent {
                            PublishedRecordCard(
                                record: record,
                                content: content,
                                edit: { store.beginEditingRecord(id: record.id) },
                                delete: { deletingRecord = record }
                            )
                        }
                    }
                }

                Button(action: addDraft) {
                    Label("添加一条记录", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(MHTheme.accent)
                        .background {
                            RoundedRectangle(cornerRadius: MHTheme.controlRadius)
                                .stroke(MHTheme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        }
                }
            }
            .padding(.horizontal, MHTheme.pagePadding)
            .padding(.vertical, 20)
        }
        .navigationTitle(document?.title ?? "文档")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(
            "删除这条记录？",
            isPresented: Binding(
                get: { deletingRecord != nil },
                set: { if !$0 { deletingRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("移入回收站", role: .destructive) {
                if let id = deletingRecord?.id { store.softDeleteRecord(id: id) }
                deletingRecord = nil
            }
            Button("取消", role: .cancel) { deletingRecord = nil }
        } message: {
            Text("删除后可从“我的 → 回收站”恢复。")
        }
        .memoryHubPage()
    }

    private var document: MemoryDocument? { store.document(id: documentID) }
    private var records: [MemoryRecord] { store.records(in: documentID) }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("这里还没有记录")
                .font(.headline)
            Text("从下面添加第一条记录。未完成的内容会自动保留为草稿。")
                .font(.subheadline)
                .foregroundStyle(MHTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: MHTheme.cardRadius))
    }

    private func addDraft() {
        _ = store.createRecordDraft(documentID: documentID)
    }
}

private struct PublishedRecordCard: View {
    let record: MemoryRecord
    let content: String
    let edit: () -> Void
    let delete: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(record.createdAt, format: .dateTime.year().month().day().hour().minute().locale(Locale(identifier: "zh_CN")))
                    .font(.caption)
                    .foregroundStyle(MHTheme.secondaryText)
                Spacer()
                Button("删除", role: .destructive, action: delete)
                    .font(.caption)
                    .frame(minWidth: 44, minHeight: 44)
            }
            Button(action: edit) {
                Text(renderedContent)
                    .font(.body)
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
        .padding(18)
        .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: MHTheme.cardRadius))
    }

    private var renderedContent: AttributedString {
        (try? AttributedString(markdown: content)) ?? AttributedString(content)
    }
}

private struct RecordDraftEditor: View {
    @EnvironmentObject private var store: AppStore
    let record: MemoryRecord

    @State private var text: String

    init(record: MemoryRecord) {
        self.record = record
        _text = State(initialValue: record.draftContent ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(record.publishedContent == nil ? "新增记录 · 草稿" : "编辑记录 · 草稿")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MHTheme.violet)
                Spacer()
                Button("放弃", role: .destructive) { store.discardDraft(recordID: record.id) }
                    .font(.caption)
                    .frame(minWidth: 44, minHeight: 44)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(10)
                .background(MHTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: text) { _, value in
                    store.updateDraft(recordID: record.id, content: value)
                }

            Menu {
                ForEach(["当前状态", "下一步", "问题", "备注"], id: \.self) { heading in
                    Button(heading) { insertHeading(heading) }
                }
            } label: {
                Label("小标题", systemImage: "plus")
            }
            .font(.subheadline)

            Button("完成") { store.publishDraft(recordID: record.id) }
                .buttonStyle(.borderedProminent)
                .tint(MHTheme.accent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: MHTheme.cardRadius))
    }

    private func insertHeading(_ heading: String) {
        let prefix = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
        text += "\(prefix)## \(heading)\n"
        store.updateDraft(recordID: record.id, content: text)
    }
}

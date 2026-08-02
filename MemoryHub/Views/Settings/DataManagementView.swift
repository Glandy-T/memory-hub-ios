import SwiftUI
import UniformTypeIdentifiers

struct MemoryHubBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataManagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument = MemoryHubBackupDocument()
    @State private var pendingImport: AppDatabase?
    @State private var message: String?

    var body: some View {
        alertView
            .memoryHubPage()
    }

    private var dataList: some View {
        List {
            storageOverviewSection
            backupSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("数据备份")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var storageOverviewSection: some View {
        Section {
            countRow("分类", store.database.categories.filter { !$0.isDeleted }.count)
            countRow("文档", store.database.documents.filter { !$0.isDeleted }.count)
            countRow("记录", store.database.records.filter { !$0.isDeleted }.count)
            countRow("日历事项", store.database.calendarItems.filter { $0.deletedAt == nil }.count)
            countRow("冰箱与采购", store.activeFridgeItems.count + store.database.purchaseItems.count)
            countRow("物品", store.activeHomeItems.count)
        } header: {
            Text("本地存储概览")
        }
    }

    private var backupSection: some View {
        Section {
            Button("导出本地备份", systemImage: "square.and.arrow.up") { prepareExport() }
            Button("导入备份", systemImage: "square.and.arrow.down") { importing = true }
        } header: {
            Text("备份")
        } footer: {
            Text("导入前必须选择合并或替换，不会无提示覆盖现有数据。")
        }
    }

    private var transferView: some View {
        dataList
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "MemoryHub-Backup"
        ) { result in
            if case .failure(let error) = result { message = "导出失败：\(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    private var confirmationView: some View {
        transferView
        .confirmationDialog(
            "如何导入这份备份？",
            isPresented: pendingImportPresented,
            titleVisibility: .visible
        ) {
            Button("与现有数据合并") { applyImport(replace: false) }
            Button("替换现有数据", role: .destructive) { applyImport(replace: true) }
            Button("取消", role: .cancel) { pendingImport = nil }
        } message: {
            Text("合并会按数据 ID 跳过重复内容；替换会覆盖当前本地数据库。")
        }
    }

    private var alertView: some View {
        confirmationView
        .alert("数据管理", isPresented: messagePresented) {
            Button("知道了") { message = nil }
        } message: { Text(message ?? "") }
    }

    private var pendingImportPresented: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )
    }

    private var messagePresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    private func countRow(_ title: String, _ count: Int) -> some View {
        HStack { Text(title); Spacer(); Text("\(count)").foregroundStyle(MHTheme.secondaryText) }
    }

    private func prepareExport() {
        do {
            exportDocument = MemoryHubBackupDocument(data: try store.backupData())
            exporting = true
        } catch {
            message = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try store.decodeBackup(Data(contentsOf: url))
        } catch {
            message = "无法读取备份：\(error.localizedDescription)"
        }
    }

    private func applyImport(replace: Bool) {
        guard let pendingImport else { return }
        store.importBackup(pendingImport, replaceExisting: replace)
        self.pendingImport = nil
        message = replace ? "已替换为导入的数据。" : "备份已与现有数据合并。"
    }
}

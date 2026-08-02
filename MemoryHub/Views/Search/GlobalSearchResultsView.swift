import SwiftUI

struct GlobalSearchResultsView: View {
    @EnvironmentObject private var store: AppStore
    let query: String
    let openCategory: (UUID) -> Void
    let openDocument: (UUID) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            if isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            }

            resultSection("分类", count: categories.count) {
                ForEach(categories) { category in
                    SearchResultRow(title: category.name, detail: "分类", icon: "folder") {
                        openCategory(category.id)
                    }
                }
            }

            resultSection("文档与记录", count: documentResults.count) {
                ForEach(documentResults) { result in
                    SearchResultRow(
                        title: result.document.title,
                        detail: result.detail,
                        icon: result.document.isArchived ? "archivebox" : "doc.text"
                    ) { openDocument(result.document.id) }
                }
            }

            resultSection("冰箱与采购", count: foodResults.count) {
                ForEach(foodResults, id: \.id) { result in
                    NavigationLink { FridgeView() } label: {
                        SearchResultLabel(title: result.title, detail: result.detail, icon: "refrigerator")
                    }
                    .buttonStyle(.plain)
                }
            }

            resultSection("物品", count: homeItems.count) {
                ForEach(homeItems) { item in
                    NavigationLink { ItemsView() } label: {
                        SearchResultLabel(title: item.name, detail: item.location ?? "未记录位置", icon: "shippingbox")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var normalizedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var categories: [MemoryCategory] {
        store.activeCategories.filter { $0.name.localizedCaseInsensitiveContains(normalizedQuery) }
    }

    private var documentResults: [DocumentSearchResult] {
        store.database.documents
            .filter { !$0.isDeleted }
            .compactMap { document in
                let matchingRecords = store.database.records.filter {
                    $0.documentID == document.id && !$0.isDeleted && ($0.publishedContent?.localizedCaseInsensitiveContains(normalizedQuery) == true)
                }
                guard document.title.localizedCaseInsensitiveContains(normalizedQuery) || !matchingRecords.isEmpty else { return nil }
                let category = store.category(id: document.categoryID)?.name ?? "未分类"
                let suffix = document.isArchived ? " · 已归档" : ""
                return DocumentSearchResult(document: document, detail: "\(category)\(suffix)")
            }
            .sorted { $0.document.updatedAt > $1.document.updatedAt }
    }

    private var foodResults: [FoodSearchResult] {
        let fridge = store.activeFridgeItems
            .filter { $0.name.localizedCaseInsensitiveContains(normalizedQuery) || ($0.notes?.localizedCaseInsensitiveContains(normalizedQuery) == true) }
            .map { FoodSearchResult(id: "fridge-\($0.id)", title: $0.name, detail: $0.storage ?? "冰箱内容") }
        let purchase = store.database.purchaseItems
            .filter { $0.name.localizedCaseInsensitiveContains(normalizedQuery) }
            .map { FoodSearchResult(id: "purchase-\($0.id)", title: $0.name, detail: "待采购") }
        return fridge + purchase
    }

    private var homeItems: [HomeItem] {
        store.activeHomeItems.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery) ||
            ($0.location?.localizedCaseInsensitiveContains(normalizedQuery) == true) ||
            ($0.notes?.localizedCaseInsensitiveContains(normalizedQuery) == true)
        }
    }

    private var isEmpty: Bool {
        categories.isEmpty && documentResults.isEmpty && foodResults.isEmpty && homeItems.isEmpty
    }

    @ViewBuilder
    private func resultSection<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        if count > 0 {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MHTheme.secondaryText)
                content()
            }
        }
    }
}

private struct FoodSearchResult: Identifiable {
    let id: String
    let title: String
    let detail: String
}

private struct DocumentSearchResult: Identifiable {
    let document: MemoryDocument
    let detail: String
    var id: UUID { document.id }
}

private struct SearchResultRow: View {
    let title: String
    let detail: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SearchResultLabel(title: title, detail: detail, icon: icon)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultLabel: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(MHTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(MHTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MHTheme.secondaryText)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 58)
        .background(MHTheme.raisedBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: RootTab
    @State private var categoryPath = NavigationPath()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let opensCategories = arguments.contains { $0.hasPrefix("--memory-hub-screenshot-categor") || $0.hasPrefix("--memory-hub-screenshot-document") }
        _selection = State(initialValue: opensCategories ? .categories : .home)
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .toolbar(.hidden, for: .tabBar)
                .tag(RootTab.home)
                .tabItem {
                    Label("首页", systemImage: "house")
                        .labelStyle(.iconOnly)
                }

            CalendarHomeView()
                .toolbar(.hidden, for: .tabBar)
                .tag(RootTab.calendar)
                .tabItem {
                    Label("日历", systemImage: "calendar")
                        .labelStyle(.iconOnly)
                }

            CategoriesView(path: $categoryPath)
                .toolbar(.hidden, for: .tabBar)
                .tag(RootTab.categories)
                .tabItem {
                    Label("分类", systemImage: "square.grid.2x2")
                        .labelStyle(.iconOnly)
                }

            SettingsView()
                .toolbar(.hidden, for: .tabBar)
                .tag(RootTab.profile)
                .tabItem {
                    Label("我的", systemImage: "person")
                        .labelStyle(.iconOnly)
                }
        }
        .tint(MHTheme.accent)
        .toolbar(.hidden, for: .tabBar)
        .overlay {
            if selection != .categories || categoryPath.isEmpty {
                GeometryReader { viewport in
                    let barWidth = viewport.size.width * (322.0 / 430.0)
                    let barHeight = barWidth * (58.0 / 322.0)

                    VStack {
                        Spacer()
                        RootBottomNavigation(selection: $selection)
                            .frame(width: barWidth, height: barHeight)
                            .padding(
                                .bottom,
                                max(viewport.safeAreaInsets.bottom, viewport.size.width * (34.0 / 430.0))
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .alert("本地数据提示", isPresented: errorBinding) {
            Button("知道了") { store.lastErrorMessage = nil }
        } message: {
            Text(store.lastErrorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.lastErrorMessage != nil },
            set: { if !$0 { store.lastErrorMessage = nil } }
        )
    }
}

private enum RootTab: Hashable, CaseIterable {
    case home
    case calendar
    case categories
    case profile

    var title: String {
        switch self {
        case .home: "首页"
        case .calendar: "日历"
        case .categories: "分类"
        case .profile: "我的"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .calendar: "calendar"
        case .categories: "square.grid.2x2"
        case .profile: "person"
        }
    }
}

private struct RootBottomNavigation: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 20, weight: selection == tab ? .semibold : .regular))
                        .foregroundStyle(selection == tab ? MHTheme.accent : MHTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(MHTheme.hairline.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 7, y: 5)
    }
}

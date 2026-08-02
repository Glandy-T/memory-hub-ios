import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "house") }

            CalendarHomeView()
                .tabItem { Label("日历", systemImage: "calendar") }

            CategoriesView()
                .tabItem { Label("分类", systemImage: "square.grid.2x2") }

            SettingsView()
                .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(MHTheme.accent)
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


import SwiftUI

@main
struct MaxGenerationApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        ZStack(alignment: .top) {
            if store.data.profile == nil {
                OnboardingView()
            } else {
                MainTabs()
            }

            if let text = store.toast {
                ToastView(text: text)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }

            if let level = store.levelUpTo {
                LevelUpOverlay(level: level) { store.levelUpTo = nil }
                    .zIndex(3)
                    .onAppear { SoundFX.play(.levelup) }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.toast)
    }
}

struct MainTabs: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Hero", systemImage: "person.crop.circle.fill") }
            if store.has(.gym) {
                GymView()
                    .tabItem { Label("Train", systemImage: "figure.boxing") }
            }
            if store.has(.study) {
                StudyView()
                    .tabItem { Label("Study", systemImage: "book.fill") }
            }
            if store.has(.food) {
                FoodView()
                    .tabItem { Label("Food", systemImage: "fork.knife") }
            }
            GoalsView()
                .tabItem { Label("Goals", systemImage: "target") }
        }
    }
}

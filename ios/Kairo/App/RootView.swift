import SwiftUI

/// Top-level tab bar. Builds each feature's view from the injected environment.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    /// Set the active theme before the tree renders. (KairoApp rebuilds RootView
    /// via `.id(themeMode)`, so this runs on every theme switch.)
    init(themeMode: ThemeMode) { Theme.mode = themeMode }

    var body: some View {
        TabView {
            HomeView(env: env)
                .tabItem { Label("Home", systemImage: "house.fill") }
            CaptureView(env: env)
                .tabItem { Label("Capture", systemImage: "mic.fill") }
            AskView(env: env)
                .tabItem { Label("Ask", systemImage: "bubble.left.and.bubble.right.fill") }
            ReviewView(env: env)
                .tabItem { Label("Review", systemImage: "rectangle.on.rectangle.angled") }
            DigestView(env: env)
                .tabItem { Label("Digest", systemImage: "newspaper.fill") }
        }
        .tint(Theme.gold)
        .font(Theme.sans(16))   // DM Sans as the app-wide base font
    }
}

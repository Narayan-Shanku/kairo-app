import SwiftUI

@main
struct KairoApp: App {
    // Under unit tests the host app still launches; we skip the real environment
    // (SwiftData container, networking) so the test runner bootstraps cleanly.
    // Tests construct ViewModels with mocks directly and never need this.
    @State private var environment: AppEnvironment? = KairoApp.isTesting ? nil : AppEnvironment.live()
    @AppStorage("themeMode") private var themeModeRaw = ThemeMode.light.rawValue
    // In "System" mode, Theme resolves colors from the OS appearance at render
    // time — keying the tree on the scheme re-resolves them live when the OS
    // switches light/dark while the app is open.
    @Environment(\.colorScheme) private var systemScheme

    private var themeMode: ThemeMode { ThemeMode(rawValue: themeModeRaw) ?? .system }

    static var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            if let environment {
                RootView(themeMode: themeMode)
                    .environment(environment)
                    .preferredColorScheme(themeMode.colorScheme)
                    .tint(Theme.gold)
                    .id("\(themeModeRaw)-\(systemScheme)")   // rebuild the tree so all colors re-resolve
            } else {
                Color.clear   // minimal UI while hosting unit tests
            }
        }
    }
}

import SwiftUI

/// User's appearance preference, persisted via `@AppStorage("themeMode")`.
/// `hero` is Kairō's signature coastal "Sunset" theme — distinct from light/dark.
enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark, hero

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:  return "Beachside"
        case .dark:   return "Deep Ocean"
        case .hero:   return "Sunset"
        case .system: return "System"
        }
    }

    /// System chrome scheme. Sunset rides on dark chrome (light status bar).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        case .hero:   return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        case .hero:   return "sunset.fill"
        }
    }
}

import SwiftUI
import UIKit

/// Kairō's coastal palette — three themes: **Beachside** (light, warm sand +
/// ocean teal), **Deep Ocean** (dark, deep teal-ink + aqua), and the signature
/// **Sunset** (deep ocean lit by a coral glow, peach text). Colors are computed
/// from the app-selected `Theme.mode` (set in `RootView.init`; the root is rebuilt
/// via `.id` on change), so the whole UI re-resolves on a theme switch.
///
/// Ocean teal is the accent across all three; there is no amber/gold.
enum Theme {
    enum Resolved { case light, dark, hero }

    /// The app-selected theme. Set before render in `RootView.init`.
    static var mode: ThemeMode = .light

    static var resolved: Resolved {
        switch mode {
        case .hero:   return .hero
        case .light:  return .light
        case .dark:   return .dark
        case .system: return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
    }
    static var isHero: Bool { mode == .hero }

    private static func pick(_ light: UInt, _ dark: UInt, _ hero: UInt) -> Color {
        switch resolved {
        case .light: return Color(hex: light)
        case .dark:  return Color(hex: dark)
        case .hero:  return Color(hex: hero)
        }
    }

    // Coastal palette (no amber):
    //   light = Beachside (warm sand + ocean teal)
    //   dark  = Deep Ocean (deep teal-ink + aqua)
    //   hero  = Sunset (deep ocean + coral glow + peach)
    //                              light       dark        hero (Sunset)
    static var ink: Color      { pick(0xF3EEE3, 0x0A1A1C, 0x0E2A2E) }  // background
    static var panel: Color    { pick(0xFFFFFF, 0x102729, 0x16383A) }  // cards
    static var panel2: Color   { pick(0xE9F1ED, 0x163436, 0x1E4644) }  // raised cards
    static var border: Color   { pick(0xDBD3C4, 0x244240, 0x2E5452) }
    static var cream: Color    { pick(0x1C2B2E, 0xEAF4F2, 0xFBE3D2) }  // primary text
    static var creamDim: Color { pick(0x50605F, 0x9FB8B4, 0xDBB6A4) }  // secondary text
    static var muted: Color    { pick(0x8D9794, 0x67807D, 0x9A8A80) }  // tertiary text
    // `gold` keeps its name for compatibility but now holds the coastal accent.
    static var gold: Color     { pick(0x0E9C92, 0x28C2B0, 0xFF8C6B) }  // teal / aqua / coral
    static var gold2: Color    { pick(0x0A7B73, 0x1A9E90, 0xE86A4E) }
    static var accentSoft: Color { pick(0xDCEFEC, 0x0E2E2B, 0x3A2620) }
    static var onGold: Color   { pick(0xFFFFFF, 0x05201D, 0x2A1410) }  // text on accent
    static var danger: Color   { pick(0xD9614A, 0xE0816F, 0xFF6B6B) }
    static var citation: Color { pick(0x2E8FD0, 0x6FB0E6, 0x74C2D6) }

    /// Color used for a life domain's tag/dot.
    static func domainColor(_ domain: String) -> Color {
        let bright = resolved != .light   // brighter on dark/hero
        switch domain {
        case "Health":        return Color(hex: bright ? 0x3EC98A : 0x1F9E6B)  // green
        case "Career":        return Color(hex: bright ? 0x5A93E0 : 0x3F71BE)  // blue
        case "Learning":      return Color(hex: bright ? 0xB78FE0 : 0x8A5EC0)  // violet
        case "Projects":      return Color(hex: bright ? 0x7C8CF0 : 0x515FC0)  // indigo
        case "Fitness":       return Color(hex: bright ? 0xF09A6B : 0xC56A3C)  // coral
        case "Finance":       return Color(hex: bright ? 0xC9AE72 : 0x9C824A)  // sand
        case "Relationships": return Color(hex: bright ? 0xE07A9A : 0xC25478)  // pink
        default:              return muted
        }
    }

    // MARK: Type (DM Serif Display + DM Sans, inherited from the repo)
    static func serif(_ size: CGFloat) -> Font { .custom("DMSerifDisplay-Regular", size: size) }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("DM Sans", size: size).weight(weight)
    }

    /// The signature accent gradient (ocean teal in light/dark, coral in Sunset).
    static var goldGradient: LinearGradient {
        LinearGradient(colors: [gold, gold2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

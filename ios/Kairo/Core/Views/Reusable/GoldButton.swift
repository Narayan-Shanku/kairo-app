import SwiftUI

/// Primary call-to-action button style (full-width gold gradient).
struct GoldButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onGold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.goldGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    /// Fill the screen with Kairō's ink background. In Golden Hour, add the
    /// signature warm radial glow (the "golden hour light").
    func kairoBackground() -> some View {
        background(
            ZStack {
                Theme.ink
                if Theme.isHero {
                    RadialGradient(
                        colors: [Theme.gold.opacity(0.14), .clear],
                        center: .top, startRadius: 0, endRadius: 540)
                }
            }
            .ignoresSafeArea()
        )
    }
}

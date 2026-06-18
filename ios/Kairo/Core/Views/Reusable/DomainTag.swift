import SwiftUI

/// A small colored capsule for a life domain (e.g. "Health").
struct DomainTag: View {
    let domain: String

    var body: some View {
        Text(domain)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .foregroundStyle(Theme.domainColor(domain))
            .background(Theme.domainColor(domain).opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("\(domain) domain")
    }
}

#Preview {
    DomainTag(domain: "Health").padding().background(Theme.ink)
}

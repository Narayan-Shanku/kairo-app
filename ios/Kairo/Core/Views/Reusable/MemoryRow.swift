import SwiftUI

/// A single memory shown in lists (Home recent, timeline).
struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                DomainTag(domain: memory.primaryDomain)
                Text("\(DateFormat.pretty(memory.timestamp)) · \(memory.sourceType)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Text(memory.text)
                .font(.subheadline)
                .foregroundStyle(Theme.creamDim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

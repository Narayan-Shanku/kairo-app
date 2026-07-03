import SwiftUI

struct ReviewView: View {
    @State private var vm: ReviewViewModel

    init(env: AppEnvironment) {
        _vm = State(initialValue: ReviewViewModel(cards: env.cards))
    }

    private let ratingColors: [Rating: Color] = [
        .again: Theme.danger,
        .hard: Color(hex: 0xD8B34A),
        .good: Theme.domainColor("Health"),
        .easy: Theme.citation,
    ]

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let card = vm.current {
                    cardView(card)
                } else {
                    allCaughtUp
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .kairoBackground()
            .navigationTitle("Review")
            .task { await vm.load() }
        }
    }

    private func cardView(_ card: Card) -> some View {
        // Scrolls so long decision cards + the reflection field + rating buttons
        // stay reachable when the keyboard is up on small devices.
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(vm.queue.count) TO REVIEW")
                .font(.caption.weight(.bold)).kerning(1.5)
                .foregroundStyle(Theme.muted)

            VStack(alignment: .leading, spacing: 18) {
                DomainTag(domain: card.domain.isEmpty ? card.type : card.domain)
                Text(card.front)
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.cream)

                if vm.revealed {
                    Divider().overlay(Theme.border)
                    Text(card.back).font(.body).foregroundStyle(Theme.creamDim)
                    if card.isDecision {
                        TextField("Did it hold up? It's saved as a new memory…",
                                  text: $vm.reflection, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(10)
                            .background(Theme.ink)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.4)))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Theme.cream)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(Theme.panel2)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if vm.revealed {
                HStack(spacing: 10) {
                    ForEach(Rating.allCases) { rating in
                        let color = ratingColors[rating] ?? Theme.gold
                        Button(rating.label) { Task { await vm.rate(rating) } }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(color)
                            .frame(maxWidth: .infinity, minHeight: 44)   // HIG tap target
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(color.opacity(0.5)))
                            .contentShape(Rectangle())
                    }
                }
            } else {
                Button("Show answer") { vm.reveal() }
                    .buttonStyle(GoldButton())
            }

            if let error = vm.errorMessage {
                Text(error).font(.footnote).foregroundStyle(Theme.danger)
            }
        }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var allCaughtUp: some View {
        VStack(spacing: 10) {
            Text("✓").font(.system(size: 44)).foregroundStyle(Theme.domainColor("Health"))
            Text("All caught up")
                .font(Theme.serif(22))
                .foregroundStyle(Theme.cream)
            Text("No memories due right now. Come back tomorrow — or capture something new.")
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
        }
    }
}

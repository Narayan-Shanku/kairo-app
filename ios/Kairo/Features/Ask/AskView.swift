import SwiftUI

struct AskView: View {
    @State private var vm: AskViewModel
    @State private var input = ""

    init(env: AppEnvironment) {
        _vm = State(initialValue: AskViewModel(memories: env.memories))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if vm.exchanges.isEmpty { emptyState }
                        ForEach(vm.exchanges) { exchangeView($0) }
                    }
                    .padding()
                }
                inputBar
            }
            .kairoBackground()
            .navigationTitle("Ask")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("◐").font(.system(size: 40)).foregroundStyle(Theme.gold.opacity(0.5))
            Text("Ask anything about your past. Try:")
                .font(.subheadline).foregroundStyle(Theme.muted)
            ForEach(vm.suggestions, id: \.self) { s in
                Button(s) { Task { await vm.ask(s) } }
                    .font(.subheadline).foregroundStyle(Theme.creamDim)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(Capsule().stroke(Theme.border))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private func exchangeView(_ ex: AskViewModel.Exchange) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer(minLength: 40)
                Text(ex.question)
                    .padding(11)
                    .background(Theme.goldGradient)
                    .foregroundStyle(Theme.onGold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            VStack(alignment: .leading, spacing: 10) {
                if let answer = ex.answer {
                    Text(answer).foregroundStyle(Theme.creamDim)
                    if !ex.sources.isEmpty { sourceChips(ex.sources) }
                    Button(ex.pinned ? "✓ Added to Review" : "⭐ Remember this") {
                        Task { await vm.pin(ex.id) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .disabled(ex.pinned)
                } else {
                    Text("Searching your memories…").italic().foregroundStyle(Theme.muted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func sourceChips(_ sources: [Source]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sources) { s in
                Text("\(s.date) · \(s.domain)")
                    .font(.caption2)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .foregroundStyle(Theme.citation)
                    .background(Theme.citation.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your memory…", text: $input)
                .textFieldStyle(.plain)
                .padding(13)
                .background(Theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Theme.cream)
                .submitLabel(.send)
                .onSubmit(send)
            Button("Ask", action: send)
                .buttonStyle(.borderedProminent)
                .tint(Theme.gold)
                .foregroundStyle(Theme.onGold)
                .disabled(vm.isBusy)
        }
        .padding()
    }

    private func send() {
        let q = input
        input = ""
        Task { await vm.ask(q) }
    }
}

import SwiftUI

struct DigestView: View {
    @State private var vm: DigestViewModel

    init(env: AppEnvironment) {
        _vm = State(initialValue: DigestViewModel(proactive: env.proactive))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if vm.isLoading && vm.digest == nil {
                        ProgressView().tint(Theme.gold)
                            .frame(maxWidth: .infinity).padding(.top, 50)
                    } else if let d = vm.digest {
                        Text("\(d.weekStart) → \(d.weekEnd) · \(d.memoryCount ?? 0) memories")
                            .font(.caption.weight(.bold)).kerning(1)
                            .foregroundStyle(Theme.muted)
                        Text(markdown(d.digestText))
                            .font(.body)
                            .foregroundStyle(Theme.creamDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .background(Theme.panel)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if let error = vm.errorMessage {
                        Text(error).font(.subheadline).foregroundStyle(Theme.danger)
                    }
                }
                .padding()
            }
            .kairoBackground()
            .navigationTitle("Weekly digest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await vm.load(refresh: true) } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Regenerate digest")
                    .disabled(vm.isLoading)
                }
            }
            .task { if vm.digest == nil { await vm.load() } }
        }
    }

    /// Render the digest's lightweight markdown (bold + line breaks).
    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

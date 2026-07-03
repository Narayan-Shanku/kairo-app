import SwiftUI

struct HomeView: View {
    @State private var vm: HomeViewModel
    @State private var showSettings = false

    init(env: AppEnvironment) {
        _vm = State(initialValue: HomeViewModel(
            memories: env.memories, cards: env.cards, proactive: env.proactive))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(vm.greeting)
                        .font(Theme.serif(34))
                        .foregroundStyle(Theme.cream)

                    if let streak = vm.today?.streak {
                        streakHeader(streak)
                    }

                    if let stats = vm.stats { statRow(stats) }

                    if let recall = vm.today?.recall { recallCard(recall) }

                    if let nudges = vm.today?.nudges, !nudges.isEmpty {
                        ForEach(nudges) { nudge in
                            Text("💡 \(nudge.message)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.creamDim)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.panel)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if let cs = vm.cardStats, cs.due > 0 { reviewBadge(cs) }

                    if vm.showSeedBanner { seedBanner }

                    Text("RECENT MEMORIES")
                        .font(.caption.weight(.bold)).kerning(1.5)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)

                    if vm.recent.isEmpty {
                        Text("No memories yet. Capture your first check-in →")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(vm.recent) { MemoryRow(memory: $0) }
                    }

                    if let error = vm.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(Theme.danger)
                    }
                }
                .padding()
            }
            .kairoBackground()
            .navigationTitle("Kairō")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task { await vm.load(); await NotificationService.bootstrap() }
            .refreshable { await vm.load() }
        }
    }

    private func statRow(_ s: Stats) -> some View {
        HStack(spacing: 12) {
            statCard("\(s.totalMemories)", "Memories")
            statCard("\(s.totalSessions)", "Check-ins")
            statCard("\(s.activeDomainCount)", "Domains")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Theme.serif(26))
                .foregroundStyle(Theme.gold)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func streakHeader(_ s: Streak) -> some View {
        let mood: SunMood = s.checkedInToday ? .beaming : (s.current > 0 ? .worried : .asleep)
        return HStack(spacing: 14) {
            KairoSun(mood: mood)
                .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.current > 0 ? "\(s.current)-day streak" : "Start your streak")
                    .font(Theme.serif(22))
                    .foregroundStyle(Theme.cream)
                Text(s.checkedInToday ? "Checked in today ✓"
                     : (s.current > 0 ? "Check in to keep Kairo shining"
                                      : "Capture a memory or check in"))
                    .font(.caption)
                    .foregroundStyle(Theme.creamDim)
            }
            Spacer(minLength: 8)
            if !s.checkedInToday {
                Button { Task { await vm.checkIn() } } label: {
                    Text("Check in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onGold)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.gold)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Check in today")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func recallCard(_ recall: RecallCard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("↩ \(recall.date) · \(recall.domain)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.domainColor(recall.domain))
            Text(recall.prompt)
                .font(Theme.serif(20))
                .foregroundStyle(Theme.cream)
            Text("“\(recall.snippet)”")
                .font(.footnote).italic()
                .foregroundStyle(Theme.muted)
            TextField("Reply — it's saved as a new memory…", text: $vm.recallReply, axis: .vertical)
                .lineLimit(2...4)
                .padding(10)
                .background(Theme.ink)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Theme.cream)
            HStack {
                Button("Save reflection") { Task { await vm.submitRecall() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onGold)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Theme.gold).clipShape(Capsule())
                Button("Dismiss") { Task { await vm.dismissRecall() } }
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)               // HIG tap-target minimum
                    .contentShape(Rectangle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.panel2, Theme.panel],
                                   startPoint: .top, endPoint: .bottom))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reviewBadge(_ cs: CardStats) -> some View {
        HStack {
            Text("🔁 \(cs.due) \(cs.due == 1 ? "memory" : "memories") to review")
                .foregroundStyle(Theme.cream)
            if cs.streak > 0 {
                Text("· 🔥 \(cs.streak)-day streak").foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .font(.subheadline.weight(.semibold))
        .padding(14)
        .background(Theme.gold.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.4)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("\(cs.due) memories to review")
    }

    private var seedBanner: some View {
        Button {
            Task { await vm.seedDemo() }
        } label: {
            HStack {
                Text(vm.isSeeding ? "Loading…" : "New here? Load demo memories")
                Spacer()
                if !vm.isSeeding { Image(systemName: "arrow.right") }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.gold)
            .padding(14)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.4)))
        }
        .disabled(vm.isSeeding)
    }
}

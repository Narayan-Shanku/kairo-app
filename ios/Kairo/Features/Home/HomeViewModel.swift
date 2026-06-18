import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let memories: MemoryRepository
    private let cards: CardRepository
    private let proactive: ProactiveRepository

    var stats: Stats?
    var cardStats: CardStats?
    var recent: [Memory] = []
    var errorMessage: String?
    var isSeeding = false

    // Proactive Engine
    var today: ProactiveToday?
    var recallReply = ""

    init(memories: MemoryRepository, cards: CardRepository, proactive: ProactiveRepository) {
        self.memories = memories
        self.cards = cards
        self.proactive = proactive
    }

    var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "Good morning."
        case ..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }

    var showSeedBanner: Bool { (stats?.totalMemories ?? 0) == 0 }

    func load() async {
        do {
            async let s = memories.stats()
            async let r = memories.recent(limit: 6)
            stats = try await s
            recent = try await r
            cardStats = try? await cards.stats()       // cards optional UX
            today = try? await proactive.today()       // degrade gracefully
            errorMessage = nil
        } catch {
            errorMessage = "Can't reach Kairō. Is the server running? (\(error.localizedDescription))"
        }
    }

    func checkIn() async {
        _ = try? await proactive.checkIn()
        await load()
    }

    func submitRecall() async {
        guard let recall = today?.recall,
              !recallReply.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        try? await proactive.respondRecall(memoryId: recall.memoryId, response: recallReply)
        recallReply = ""
        await load()
    }

    func dismissRecall() async {
        guard let recall = today?.recall else { return }
        try? await proactive.dismissRecall(memoryId: recall.memoryId)
        await load()
    }

    func seedDemo() async {
        isSeeding = true
        try? await memories.seedDemo()
        await load()
        isSeeding = false
    }
}

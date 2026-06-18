import Foundation
import Testing
@testable import Kairo

/// Exercises the fully on-device engine (no backend). Foundation Models generation
/// isn't available in the Simulator, so `query` exercises the extractive fallback —
/// everything else (capture, embed/search, SM-2 review, proactive) runs for real.
@MainActor
struct OnDeviceEngineTests {
    private func freshStore() -> OnDeviceStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairo-test-\(UUID().uuidString).json")
        return OnDeviceStore(url: url)
    }
    private func nowISO() -> String { ISO8601DateFormatter().string(from: Date()) }

    @Test func captureStoresAndSearchRanks() async throws {
        let store = freshStore()
        let repo = LocalMemoryRepository(store: store)
        _ = try await repo.captureText("I went for a long morning run and felt energized")
        _ = try await repo.captureText("Reviewed the quarterly budget and cut expenses")

        let stats = try await repo.stats()
        #expect(stats.totalMemories == 2)

        let results = await repo.searchOffline("morning run exercise", limit: 1)
        #expect(results.first?.text.localizedCaseInsensitiveContains("run") == true)
    }

    @Test func queryReturnsAnswerWithSources() async throws {
        let store = freshStore()
        let repo = LocalMemoryRepository(store: store)
        _ = try await repo.captureText("Bloated after heavy lentils and poor sleep")
        let resp = try await repo.query("what triggers my bloating")
        #expect(!resp.answer.isEmpty)
        #expect(!resp.sources.isEmpty)
    }

    @Test func cardReviewAdvancesSchedule() async throws {
        let store = freshStore()
        let now = nowISO()
        store.addCard(OnDeviceStore.StoredCard(
            cardId: "c1", type: "insight", front: "Q", back: "A", domain: "Health",
            createdAt: now, dueDate: now, ease: 2.5, intervalDays: 0,
            repetitions: 0, lapses: 0, lastReviewed: nil))
        let cards = LocalCardRepository(store: store, memories: LocalMemoryRepository(store: store))

        #expect(try await cards.due(limit: 10).contains { $0.id == "c1" })
        let r = try await cards.review(cardId: "c1", rating: .good, reflection: nil)
        #expect(r.intervalDays == 1)
    }

    @Test func decisionReflectionWritesBackMemory() async throws {
        let store = freshStore()
        let mem = LocalMemoryRepository(store: store)
        let now = nowISO()
        store.addCard(OnDeviceStore.StoredCard(
            cardId: "d1", type: "decision", front: "Did it hold up?", back: "Decision X",
            domain: "Career", createdAt: now, dueDate: now, ease: 2.5, intervalDays: 0,
            repetitions: 0, lapses: 0, lastReviewed: nil))
        let cards = LocalCardRepository(store: store, memories: mem)

        let before = try await mem.stats()
        let r = try await cards.review(cardId: "d1", rating: .good, reflection: "Yes, it stuck")
        #expect(r.createdMemory == true)
        #expect(try await mem.stats().totalMemories == before.totalMemories + 1)
    }

    @Test func proactiveTodayComputesStreakAndNudges() async throws {
        let store = freshStore()
        let repo = LocalMemoryRepository(store: store)
        for _ in 0..<3 { _ = try await repo.captureText("a health note about sleep and energy") }
        let proactive = LocalProactiveRepository(store: store, memories: repo)
        let today = try await proactive.today()
        #expect(today.streak.current >= 1)
        #expect(today.streak.checkedInToday == true)
    }

    @Test func demoSeedPopulatesStore() async throws {
        let store = freshStore()
        DemoData.seed(into: store, embedding: EmbeddingService())
        #expect(store.memories.count == 13)
        #expect(store.cards.count == 5)
    }
}

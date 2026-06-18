import Foundation
@testable import Kairo

/// In-memory test doubles for the repository/service protocols. Classes so tests
/// can inspect recorded calls.

final class MockMemoryRepository: MemoryRepository {
    var statsResult = Stats(totalMemories: 3, totalSessions: 2, domains: ["Health": 2, "Career": 1])
    var recentResult: [Memory] = [
        Memory(chunkId: "m1", text: "Felt good after a walk",
               domains: ["Fitness"], timestamp: "2026-06-17T10:00:00Z", sourceType: "text")
    ]
    var queryResult = RAGResponse(
        answer: "Because lentils.",
        sources: [Source(chunkId: "s1", date: "Jun 8", domain: "Health", snippet: "bloated after lentils")],
        confidence: 0.9)
    var captureResult = CaptureSummary(chunkCount: 1, wordCount: 5, domains: ["Health"], transcript: nil)
    var throwError: Error?

    private(set) var captured: [String] = []
    private(set) var pinned: [(String, String)] = []
    private(set) var seeded = false

    private func failIfNeeded() throws { if let throwError { throw throwError } }

    func stats() async throws -> Stats { try failIfNeeded(); return statsResult }
    func recent(limit: Int) async throws -> [Memory] { try failIfNeeded(); return recentResult }
    func memories(domain: String?, limit: Int) async throws -> [Memory] { try failIfNeeded(); return recentResult }
    func captureText(_ text: String) async throws -> CaptureSummary {
        try failIfNeeded(); captured.append(text); return captureResult
    }
    func query(_ question: String) async throws -> RAGResponse { try failIfNeeded(); return queryResult }
    func pinAnswer(question: String, answer: String) async throws -> Bool {
        try failIfNeeded(); pinned.append((question, answer)); return true
    }
    func seedDemo() async throws { try failIfNeeded(); seeded = true }
    func searchOffline(_ query: String, limit: Int) async -> [Memory] {
        Array(offlineResults.prefix(limit))
    }
    var offlineResults: [Memory] = []
}

final class MockCardRepository: CardRepository {
    var dueResult: [Card] = [
        Card(cardId: "c1", type: "decision", front: "Did it stick?", back: "Decision: X", domain: "Career")
    ]
    var statsResult = CardStats(due: 2, total: 5, reviewedToday: false, streak: 1)
    var throwError: Error?
    private(set) var reviews: [(id: String, rating: Rating, reflection: String?)] = []

    func due(limit: Int) async throws -> [Card] { if let throwError { throw throwError }; return dueResult }
    func stats() async throws -> CardStats { if let throwError { throw throwError }; return statsResult }
    func review(cardId: String, rating: Rating, reflection: String?) async throws -> ReviewResult {
        reviews.append((cardId, rating, reflection))
        return ReviewResult(intervalDays: 1, nextReview: "Jun 18", createdMemory: reflection != nil)
    }
}

final class MockProactiveRepository: ProactiveRepository {
    var todayResult = ProactiveToday(
        streak: Streak(current: 5, longest: 7, checkedInToday: true, totalDays: 10),
        recall: RecallCard(memoryId: "r1", prompt: "How did that go?",
                           date: "Jun 15", snippet: "felt bloated", domain: "Health"),
        nudges: [Nudge(type: "pattern", message: "3 Health notes recently", domain: "Health")])
    var digestResult = Digest(weekStart: "2026-06-12", weekEnd: "2026-06-18",
                              digestText: "**This week**\nA good week.", memoryCount: 9)
    var throwError: Error?
    private(set) var responded: [(id: String, text: String)] = []
    private(set) var dismissed: [String] = []

    func today() async throws -> ProactiveToday {
        if let throwError { throw throwError }
        return todayResult
    }
    func respondRecall(memoryId: String, response: String) async throws {
        responded.append((memoryId, response))
    }
    func dismissRecall(memoryId: String) async throws { dismissed.append(memoryId) }
    func digest(refresh: Bool) async throws -> Digest {
        if let throwError { throw throwError }
        return digestResult
    }
}

struct MockAudioRecording: AudioRecording {
    func requestPermission() async -> Bool { true }
    func start(url: URL) throws {}
    func stop() {}
}

struct MockTranscription: TranscriptionService {
    var engineName: String { "mock" }
    func transcribe(audioURL: URL) async throws -> String { "transcribed text" }
}

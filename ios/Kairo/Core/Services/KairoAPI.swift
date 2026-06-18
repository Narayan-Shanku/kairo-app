import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Abstraction over the Kairō backend. ViewModels depend on this protocol (not
/// the concrete client) so they can be unit-tested with a mock.
protocol KairoAPI {
    func stats() async throws -> Stats
    func recentMemories(limit: Int) async throws -> [Memory]
    func memories(domain: String?, limit: Int) async throws -> [Memory]
    func captureText(_ text: String) async throws -> CaptureSummary
    func query(_ question: String) async throws -> RAGResponse
    func transcribe(audioURL: URL) async throws -> Transcript
    func dueCards(limit: Int) async throws -> [Card]
    func cardStats() async throws -> CardStats
    func review(cardId: String, rating: Rating, reflection: String?) async throws -> ReviewResult
    func pin(front: String, back: String) async throws -> Bool
    func seedDemo() async throws
    // Proactive Engine
    func proactiveToday() async throws -> ProactiveToday
    func respondRecall(memoryId: String, response: String) async throws
    func dismissRecall(memoryId: String) async throws
    func digest(refresh: Bool) async throws -> Digest
}

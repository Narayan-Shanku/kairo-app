import Foundation

/// Data access for the Proactive Engine (streak, Day-3 recall, nudges, digest).
/// Online-only — callers treat failures as "nothing to show" so the UI degrades
/// gracefully offline.
protocol ProactiveRepository {
    func today() async throws -> ProactiveToday
    /// Explicitly mark today as a check-in (keeps the streak alive on days you
    /// don't capture a memory). Returns the refreshed proactive payload.
    func checkIn() async throws -> ProactiveToday
    func respondRecall(memoryId: String, response: String) async throws
    func dismissRecall(memoryId: String) async throws
    func digest(refresh: Bool) async throws -> Digest
}

struct DefaultProactiveRepository: ProactiveRepository {
    let api: KairoAPI

    func today() async throws -> ProactiveToday { try await api.proactiveToday() }
    func checkIn() async throws -> ProactiveToday { try await api.proactiveToday() }
    func respondRecall(memoryId: String, response: String) async throws {
        try await api.respondRecall(memoryId: memoryId, response: response)
    }
    func dismissRecall(memoryId: String) async throws {
        try await api.dismissRecall(memoryId: memoryId)
    }
    func digest(refresh: Bool) async throws -> Digest { try await api.digest(refresh: refresh) }
}

import Foundation

/// Data access for spaced-repetition review cards. Due cards are cached for
/// offline review; submitting a review still requires the backend (online).
protocol CardRepository {
    func due(limit: Int) async throws -> [Card]
    func stats() async throws -> CardStats
    func review(cardId: String, rating: Rating, reflection: String?) async throws -> ReviewResult
    /// Best-effort: distill new review cards from recent memories that don't have
    /// one yet. Returns how many were created. On-device this runs generation;
    /// the backend already generates cards during ingest, so the remote impl is a
    /// no-op.
    func generateMissing(limit: Int) async -> Int
}

struct DefaultCardRepository: CardRepository {
    let api: KairoAPI
    let cache: LocalCache?

    func due(limit: Int) async throws -> [Card] {
        do {
            let fresh = try await api.dueCards(limit: limit)
            await cache?.saveCards(fresh)
            return fresh
        } catch {
            if let cached = await cache?.loadCards(), !cached.isEmpty { return cached }
            throw error
        }
    }

    func stats() async throws -> CardStats {
        do {
            return try await api.cardStats()
        } catch {
            // Offline: approximate from cached due cards.
            if let cached = await cache?.loadCards(), !cached.isEmpty {
                return CardStats(due: cached.count, total: cached.count,
                                 reviewedToday: false, streak: 0)
            }
            throw error
        }
    }

    func review(cardId: String, rating: Rating, reflection: String?) async throws -> ReviewResult {
        try await api.review(cardId: cardId, rating: rating, reflection: reflection)
    }

    // The backend distills cards during ingest, so the client doesn't drive it.
    func generateMissing(limit: Int) async -> Int { 0 }
}

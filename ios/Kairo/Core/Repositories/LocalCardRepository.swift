import Foundation

/// On-device CardRepository: due queue + SM-2 review, fully local. A decision
/// card's reflection is written back as a new memory (the validation loop).
struct LocalCardRepository: CardRepository {
    let store: OnDeviceStore
    let memories: MemoryRepository   // for the decision-reflection write-back

    func due(limit: Int) async throws -> [Card] {
        let now = LocalMemoryRepository.nowISO()
        let cards = await store.cards
        return cards.filter { $0.dueDate <= now }.prefix(limit).map(\.asCard)
    }

    func stats() async throws -> CardStats {
        let now = LocalMemoryRepository.nowISO()
        let cards = await store.cards
        let due = cards.filter { $0.dueDate <= now }.count
        let dates = Set(await store.reviewDates)
        return CardStats(due: due, total: cards.count,
                         reviewedToday: dates.contains(StreakCalc.today()),
                         streak: StreakCalc.current(dates))
    }

    func review(cardId: String, rating: Rating, reflection: String?) async throws -> ReviewResult {
        guard var c = await store.card(cardId) else {
            throw APIError(message: "card not found")
        }
        let next = SM2.schedule(
            SM2.State(ease: c.ease, intervalDays: c.intervalDays,
                      repetitions: c.repetitions, lapses: c.lapses),
            rating: rating)
        let now = Date()
        c.ease = next.ease
        c.intervalDays = next.intervalDays
        c.repetitions = next.repetitions
        c.lapses = next.lapses
        c.lastReviewed = ISO8601DateFormatter().string(from: now)
        c.dueDate = ISO8601DateFormatter().string(from: now.addingTimeInterval(next.intervalDays * 86400))
        await store.upsertCard(c)
        await store.recordReview(StreakCalc.today())

        var createdMemory = false
        if c.type == "decision",
           let r = reflection?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty {
            _ = try? await memories.captureText(r)
            createdMemory = true
        }
        return ReviewResult(intervalDays: next.intervalDays,
                            nextReview: DateFormat.pretty(c.dueDate),
                            createdMemory: createdMemory)
    }
}

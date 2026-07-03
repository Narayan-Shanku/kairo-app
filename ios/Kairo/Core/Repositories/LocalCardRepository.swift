import Foundation

/// On-device CardRepository: due queue + SM-2 review, fully local. A decision
/// card's reflection is written back as a new memory (the validation loop).
struct LocalCardRepository: CardRepository {
    let store: OnDeviceStore
    let memories: MemoryRepository   // for the decision-reflection write-back
    let generation = GenerationService()
    let cloud = CloudGenerationService()

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

    // MARK: - Card generation (distill memories → insight/decision cards)

    private struct Distilled: Decodable {
        let type: String
        let front: String
        let back: String
        let confidence: Double
    }

    private enum DistillOutcome {
        case card(type: String, front: String, back: String)
        case notCardworthy   // definitive "none"/low-confidence verdict — never retry
        case unavailable     // no generator / transient failure — retry on a later pass
    }

    /// Distill review cards from recent memories not yet processed. Each memory is
    /// marked "attempted" before generation (so dedup holds across concurrent
    /// calls); transient failures release the mark so the memory is retried later.
    func generateMissing(limit: Int) async -> Int {
        guard generation.isAvailable || cloud.isConfigured else { return 0 }
        let attempted = await store.cardAttempted
        let candidates = await store.memories
            .sorted { $0.timestamp > $1.timestamp }      // newest first
            .filter { !attempted.contains($0.chunkId) }
            .prefix(limit)
        guard !candidates.isEmpty else { return 0 }

        var created = 0
        for m in candidates {
            await store.markCardAttempted(m.chunkId)     // reserve before distilling
            switch await distill(m.text) {
            case .card(let type, let front, let back):
                let now = LocalMemoryRepository.nowISO()
                await store.addCard(OnDeviceStore.StoredCard(
                    cardId: UUID().uuidString, type: type, front: front, back: back,
                    domain: m.domains.first ?? "", createdAt: now, dueDate: now,   // due immediately
                    ease: SM2.defaultEase, intervalDays: 0, repetitions: 0, lapses: 0,
                    lastReviewed: nil, sourceMemoryId: m.chunkId))
                created += 1
            case .notCardworthy:
                break                                    // stays marked — settled verdict
            case .unavailable:
                await store.unmarkCardAttempted(m.chunkId)  // transient — retry later
            }
        }
        return created
    }

    /// One memory → an (insight|decision) card, a definitive "not cardworthy", or
    /// "unavailable" when no generator could produce a verdict at all.
    private func distill(_ text: String) async -> DistillOutcome {
        let prompt = cardPrompt(text)
        var raw = await generation.generate(prompt)      // on-device first
        if raw == nil { raw = await cloud.generate(prompt) }  // then cloud (older devices)
        guard let raw else { return .unavailable }       // no verdict — network/generator failure
        guard let json = Self.extractJSON(raw),
              let d = try? JSONDecoder().decode(Distilled.self, from: Data(json.utf8))
        else { return .notCardworthy }                   // unparseable reply — don't loop on it

        let type = d.type.lowercased()
        let front = d.front.trimmingCharacters(in: .whitespacesAndNewlines)
        let back = d.back.trimmingCharacters(in: .whitespacesAndNewlines)
        // Quality gate — same bar as the backend (confidence ≥ 0.6, real content).
        guard type == "insight" || type == "decision",
              !front.isEmpty, !back.isEmpty, d.confidence >= 0.6 else { return .notCardworthy }
        return .card(type: type, front: front, back: back)
    }

    /// Pull the JSON object out of a model reply (tolerates code fences / prose).
    private static func extractJSON(_ s: String) -> String? {
        guard let a = s.firstIndex(of: "{"), let b = s.lastIndex(of: "}"), a < b else { return nil }
        return String(s[a...b])
    }

    private func cardPrompt(_ text: String) -> String {
        """
        You decide whether a personal journal entry contains something worth \
        REMEMBERING long-term as a spaced-repetition flashcard.

        Return ONLY JSON:
        {"type": "insight" | "decision" | "none", "front": "...", "back": "...", "confidence": 0.0}

        - "insight": the entry holds a durable, reusable lesson or finding the person \
        would benefit from recalling later (a health trigger, a method that worked, a \
        principle). front = a short question testing recall of the lesson. back = the \
        lesson, concisely, in the person's own framing.
        - "decision": the person made a decision, plan, intention, or resolution worth \
        following up on. front = a question asking whether that decision held up or \
        worked. back = a one-line restatement of the decision for context.
        - "none": a routine log with no reusable takeaway. Be conservative — prefer \
        "none" unless there is a clear lesson or a concrete decision.

        Entry:
        \"\"\"\(text.prefix(2000))\"\"\"
        """
    }
}

import Foundation

/// A spaced-repetition review card.
struct Card: Codable, Identifiable, Hashable {
    let cardId: String
    let type: String        // insight | decision | pinned
    let front: String
    let back: String
    let domain: String

    var id: String { cardId }
    var isDecision: Bool { type == "decision" }

    enum CodingKeys: String, CodingKey {
        case cardId = "card_id"
        case type, front, back, domain
    }
}

/// Review-deck statistics (due count, streak, etc.).
struct CardStats: Codable, Hashable {
    let due: Int
    let total: Int
    let reviewedToday: Bool
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case due, total, streak
        case reviewedToday = "reviewed_today"
    }
}

/// Result of reviewing a card.
struct ReviewResult: Codable, Hashable {
    let intervalDays: Double
    let nextReview: String
    let createdMemory: Bool

    enum CodingKeys: String, CodingKey {
        case intervalDays = "interval_days"
        case nextReview = "next_review"
        case createdMemory = "created_memory"
    }
}

/// Recall rating sent when reviewing a card.
enum Rating: String, CaseIterable, Identifiable {
    case again, hard, good, easy
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

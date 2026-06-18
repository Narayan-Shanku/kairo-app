import Foundation

/// Check-in streak.
struct Streak: Codable, Hashable {
    let current: Int
    let longest: Int
    let checkedInToday: Bool
    let totalDays: Int

    enum CodingKeys: String, CodingKey {
        case current, longest
        case checkedInToday = "checked_in_today"
        case totalDays = "total_days"
    }
}

/// A Day-3 recall card.
struct RecallCard: Codable, Hashable, Identifiable {
    let memoryId: String
    let prompt: String
    let date: String
    let snippet: String
    let domain: String

    var id: String { memoryId }

    enum CodingKeys: String, CodingKey {
        case memoryId = "memory_id"
        case prompt, date, snippet, domain
    }
}

/// A smart nudge.
struct Nudge: Codable, Hashable, Identifiable {
    let type: String
    let message: String
    let domain: String?

    var id: String { message }
}

/// The proactive home payload.
struct ProactiveToday: Codable, Hashable {
    let streak: Streak
    let recall: RecallCard?
    let nudges: [Nudge]
}

/// Weekly digest.
struct Digest: Codable, Hashable {
    let weekStart: String
    let weekEnd: String
    let digestText: String
    let memoryCount: Int?

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case digestText = "digest_text"
        case memoryCount = "memory_count"
    }
}

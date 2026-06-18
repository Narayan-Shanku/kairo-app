import Foundation

/// Overall memory-store statistics for the Home screen.
struct Stats: Codable, Hashable {
    let totalMemories: Int
    let totalSessions: Int
    let domains: [String: Int]

    var activeDomainCount: Int { domains.values.filter { $0 > 0 }.count }

    enum CodingKeys: String, CodingKey {
        case totalMemories = "total_memories"
        case totalSessions = "total_sessions"
        case domains
    }
}

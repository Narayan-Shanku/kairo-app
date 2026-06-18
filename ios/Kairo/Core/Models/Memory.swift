import Foundation

/// A stored memory chunk returned by the backend.
struct Memory: Codable, Identifiable, Hashable {
    let chunkId: String
    let text: String
    let domains: [String]
    let timestamp: String
    let sourceType: String

    var id: String { chunkId }
    var primaryDomain: String { domains.first ?? "General" }

    enum CodingKeys: String, CodingKey {
        case chunkId = "chunk_id"
        case text, domains, timestamp
        case sourceType = "source_type"
    }
}

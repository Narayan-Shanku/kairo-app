import Foundation

/// The entire on-device memory store — memories (with embeddings), review cards
/// (with SM-2 state), review history, and small key/value prefs — persisted as a
/// single JSON file in Documents. No server, no database engine.
@MainActor
final class OnDeviceStore {
    struct StoredMemory: Codable {
        var chunkId: String
        var text: String
        var domains: [String]
        var timestamp: String      // ISO-8601
        var sourceType: String
        var embedding: [Double]
        var asMemory: Memory {
            Memory(chunkId: chunkId, text: text, domains: domains,
                   timestamp: timestamp, sourceType: sourceType)
        }
    }

    struct StoredCard: Codable {
        var cardId: String
        var type: String
        var front: String
        var back: String
        var domain: String
        var createdAt: String
        var dueDate: String        // ISO-8601
        var ease: Double
        var intervalDays: Double
        var repetitions: Int
        var lapses: Int
        var lastReviewed: String?
        var asCard: Card {
            Card(cardId: cardId, type: type, front: front, back: back, domain: domain)
        }
    }

    private struct Snapshot: Codable {
        var memories: [StoredMemory] = []
        var cards: [StoredCard] = []
        var reviewDates: [String] = []
        var checkInDates: [String] = []
        var prefs: [String: String] = [:]

        init() {}

        // Tolerate missing keys so older on-device stores (and any future field
        // additions) decode cleanly instead of wiping the user's data.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            memories = try c.decodeIfPresent([StoredMemory].self, forKey: .memories) ?? []
            cards = try c.decodeIfPresent([StoredCard].self, forKey: .cards) ?? []
            reviewDates = try c.decodeIfPresent([String].self, forKey: .reviewDates) ?? []
            checkInDates = try c.decodeIfPresent([String].self, forKey: .checkInDates) ?? []
            prefs = try c.decodeIfPresent([String: String].self, forKey: .prefs) ?? [:]
        }
    }

    private var data = Snapshot()
    private let url: URL

    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.url = base.appendingPathComponent("kairo-store.json")
        }
        load()
    }

    // MARK: Memories
    var memories: [StoredMemory] { data.memories }
    var isEmpty: Bool { data.memories.isEmpty }
    func addMemory(_ m: StoredMemory) { data.memories.append(m); save() }

    // MARK: Cards
    var cards: [StoredCard] { data.cards }
    func addCard(_ c: StoredCard) { data.cards.append(c); save() }
    func card(_ id: String) -> StoredCard? { data.cards.first { $0.cardId == id } }
    func upsertCard(_ c: StoredCard) {
        if let i = data.cards.firstIndex(where: { $0.cardId == c.cardId }) { data.cards[i] = c }
        else { data.cards.append(c) }
        save()
    }

    // MARK: Reviews
    var reviewDates: [String] { data.reviewDates }
    func recordReview(_ date: String) { data.reviewDates.append(date); save() }

    // MARK: Check-ins (explicit, in addition to capture-days)
    var checkInDates: [String] { data.checkInDates }
    func addCheckIn(_ date: String) {
        guard !data.checkInDates.contains(date) else { return }
        data.checkInDates.append(date); save()
    }

    // MARK: Prefs
    func pref(_ key: String) -> String? { data.prefs[key] }
    func setPref(_ key: String, _ value: String) { data.prefs[key] = value; save() }

    // MARK: Persistence
    private func save() {
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: url, options: .atomic) }
    }
    private func load() {
        if let d = try? Data(contentsOf: url),
           let s = try? JSONDecoder().decode(Snapshot.self, from: d) { data = s }
    }
}

import Foundation

/// The entire on-device memory store — memories (with embeddings), review cards
/// (with SM-2 state), review history, and small key/value prefs — persisted as a
/// single JSON file in Documents. No server, no database engine.
@MainActor
final class OnDeviceStore {
    /// A retrieval unit within a memory — a sentence-ish slice with its own
    /// embedding, so long entries match at finer granularity.
    struct Chunk: Codable {
        var text: String
        var embedding: [Double]
    }

    struct StoredMemory: Codable {
        var chunkId: String
        var text: String
        var domains: [String]
        var timestamp: String      // ISO-8601
        var sourceType: String
        var embedding: [Double]           // whole-entry embedding (fallback + short entries)
        var chunks: [Chunk]? = nil        // finer-grained chunks (long entries); nil → use `embedding`
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
        var sourceMemoryId: String? = nil   // the memory this card was distilled from
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

    // MARK: Card-generation bookkeeping
    /// Memory ids we've already tried to distill into a card (whether or not one
    /// resulted), so generation never reprocesses the same memory.
    var cardAttempted: Set<String> {
        Set((data.prefs["card_attempted"] ?? "").split(separator: "\n").map(String.init))
    }
    func markCardAttempted(_ id: String) {
        var ids = cardAttempted
        ids.insert(id)
        data.prefs["card_attempted"] = ids.joined(separator: "\n")
        save()
    }
    /// Release a reservation after a TRANSIENT generation failure so the memory
    /// is retried on a later pass (definitive "not cardworthy" verdicts stay marked).
    func unmarkCardAttempted(_ id: String) {
        var ids = cardAttempted
        ids.remove(id)
        data.prefs["card_attempted"] = ids.joined(separator: "\n")
        save()
    }

    // MARK: Persistence
    private func save() {
        if let d = try? JSONEncoder().encode(data) { try? d.write(to: url, options: .atomic) }
    }
    private func load() {
        guard let d = try? Data(contentsOf: url) else { return }
        if let s = try? JSONDecoder().decode(Snapshot.self, from: d) {
            data = s
        } else {
            // Corrupt store: move the bytes aside for recovery. Without this, the
            // next save() would overwrite the user's entire history with an empty
            // snapshot — permanent data loss from a transient corruption.
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
        }
    }
}

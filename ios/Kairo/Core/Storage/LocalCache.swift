import Foundation

/// On-device cache backed by JSON files in the app's Caches directory.
///
/// Repositories write through here on successful fetches and read from here when
/// the backend is unreachable, so browsing + on-device search keep working
/// offline. (A plain file cache is the right tool for this small, key-less blob
/// store — no database needed.)
@MainActor
final class LocalCache {
    private let memoriesURL: URL
    private let cardsURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("KairoCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        memoriesURL = dir.appendingPathComponent("memories.json")
        cardsURL = dir.appendingPathComponent("cards.json")
    }

    // MARK: Memories

    func saveMemories(_ memories: [Memory]) {
        // Upsert by chunkId so limit-bound fetches don't drop other cached items.
        var byId: [String: Memory] = [:]
        for m in allMemories() { byId[m.chunkId] = m }
        for m in memories { byId[m.chunkId] = m }
        write(Array(byId.values), to: memoriesURL)
    }

    func allMemories() -> [Memory] {
        (read([Memory].self, from: memoriesURL) ?? [])
            .sorted { $0.timestamp > $1.timestamp }   // ISO8601 sorts chronologically
    }

    func loadMemories(domain: String?, limit: Int) -> [Memory] {
        var memories = allMemories()
        if let domain { memories = memories.filter { $0.domains.contains(domain) } }
        return Array(memories.prefix(limit))
    }

    // MARK: Cards

    func saveCards(_ cards: [Card]) { write(cards, to: cardsURL) }
    func loadCards() -> [Card] { read([Card].self, from: cardsURL) ?? [] }

    // MARK: File IO

    private func write<T: Encodable>(_ value: T, to url: URL) {
        if let data = try? encoder.encode(value) { try? data.write(to: url, options: .atomic) }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}

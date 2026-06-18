import Foundation

/// Data access for memories, capture, and retrieval. Reads write through to the
/// on-device cache and fall back to it when the backend is unreachable, so the
/// read/search experience keeps working offline.
protocol MemoryRepository {
    func stats() async throws -> Stats
    func recent(limit: Int) async throws -> [Memory]
    func memories(domain: String?, limit: Int) async throws -> [Memory]
    func captureText(_ text: String) async throws -> CaptureSummary
    func query(_ question: String) async throws -> RAGResponse
    func pinAnswer(question: String, answer: String) async throws -> Bool
    func seedDemo() async throws
    /// On-device semantic search over cached memories (offline fallback for Ask).
    func searchOffline(_ query: String, limit: Int) async -> [Memory]
}

struct DefaultMemoryRepository: MemoryRepository {
    let api: KairoAPI
    let cache: LocalCache?
    let search: OnDeviceSearch

    func stats() async throws -> Stats {
        do {
            return try await api.stats()
        } catch {
            // Offline: derive stats from the cache so Home still shows numbers.
            if let cache {
                let mems = await cache.allMemories()
                if !mems.isEmpty {
                    var domains: [String: Int] = [:]
                    for m in mems { for d in m.domains { domains[d, default: 0] += 1 } }
                    return Stats(totalMemories: mems.count, totalSessions: mems.count, domains: domains)
                }
            }
            throw error
        }
    }

    func recent(limit: Int) async throws -> [Memory] {
        do {
            let fresh = try await api.recentMemories(limit: limit)
            await cache?.saveMemories(fresh)
            return fresh
        } catch {
            if let cached = await cache?.loadMemories(domain: nil, limit: limit), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    func memories(domain: String?, limit: Int) async throws -> [Memory] {
        do {
            let fresh = try await api.memories(domain: domain, limit: limit)
            await cache?.saveMemories(fresh)
            return fresh
        } catch {
            if let cached = await cache?.loadMemories(domain: domain, limit: limit), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    func captureText(_ text: String) async throws -> CaptureSummary {
        try await api.captureText(text)
    }

    func query(_ question: String) async throws -> RAGResponse {
        try await api.query(question)
    }

    func pinAnswer(question: String, answer: String) async throws -> Bool {
        try await api.pin(front: question, back: answer)
    }

    func seedDemo() async throws { try await api.seedDemo() }

    func searchOffline(_ query: String, limit: Int) async -> [Memory] {
        guard let cache else { return [] }
        let all = await cache.allMemories()
        return search.rank(query: query, memories: all, limit: limit)
    }
}

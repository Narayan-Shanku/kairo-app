import Foundation
import NaturalLanguage

/// On-device semantic search using Apple's built-in `NLEmbedding` (no model
/// download). Used as the offline fallback for Ask: rank cached memories by
/// similarity to the question, entirely on the phone. Generation (a synthesized
/// answer) still needs the backend or a future on-device LLM — this returns the
/// most relevant memories, not a generated answer.
struct OnDeviceSearch {
    func rank(query: String, memories: [Memory], limit: Int) -> [Memory] {
        guard !memories.isEmpty else { return [] }

        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english),
              let queryVector = embedding.vector(for: query.lowercased()) else {
            return keywordRank(query: query, memories: memories, limit: limit)
        }

        let scored: [(memory: Memory, score: Double)] = memories.compactMap { memory in
            guard let v = embedding.vector(for: memory.text.lowercased()) else { return nil }
            return (memory, cosine(queryVector, v))
        }
        let ranked = scored.sorted { $0.score > $1.score }.prefix(limit).map(\.memory)
        return ranked.isEmpty ? keywordRank(query: query, memories: memories, limit: limit) : Array(ranked)
    }

    // MARK: - Helpers

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }

    /// Fallback when sentence embeddings are unavailable: token-overlap scoring.
    private func keywordRank(query: String, memories: [Memory], limit: Int) -> [Memory] {
        let terms = Set(tokenize(query))
        guard !terms.isEmpty else { return Array(memories.prefix(limit)) }
        let scored = memories
            .map { ($0, terms.intersection(tokenize($0.text)).count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
        return Array(scored)
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }
}

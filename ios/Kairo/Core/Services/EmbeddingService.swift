import Foundation
import NaturalLanguage

/// On-device sentence embeddings via Apple's built-in `NLEmbedding` (no download,
/// no network). Used for semantic retrieval over the local memory store.
struct EmbeddingService {
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    var isAvailable: Bool { embedding != nil }

    func embed(_ text: String) -> [Double]? {
        embedding?.vector(for: text.lowercased())
    }

    /// Cosine similarity between two equal-length vectors.
    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = na.squareRoot() * nb.squareRoot()
        return denom == 0 ? 0 : dot / denom
    }
}

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

/// Splits an entry into sentence-ish chunks for finer-grained retrieval. Short
/// entries stay whole; tiny fragments are merged into their neighbour.
enum TextChunker {
    static func chunks(_ text: String, minChars: Int = 40, wholeUnder: Int = 200) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= wholeUnder else { return [trimmed] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            let s = trimmed[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return true
        }
        guard sentences.count > 1 else { return [trimmed] }

        // Merge tiny fragments (e.g. "Yes.") into the previous chunk.
        var merged: [String] = []
        for s in sentences {
            if let last = merged.last, last.count < minChars {
                merged[merged.count - 1] = last + " " + s
            } else {
                merged.append(s)
            }
        }
        return merged
    }
}

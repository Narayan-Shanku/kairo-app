import Foundation

/// A citation backing a grounded answer.
struct Source: Codable, Identifiable, Hashable {
    let chunkId: String
    let date: String
    let domain: String
    let snippet: String

    var id: String { chunkId }

    enum CodingKeys: String, CodingKey {
        case chunkId = "chunk_id"
        case date, domain, snippet
    }
}

/// A grounded answer from the RAG pipeline.
struct RAGResponse: Codable, Hashable {
    let answer: String
    let sources: [Source]
    let confidence: Double
}

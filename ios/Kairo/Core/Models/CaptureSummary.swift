import Foundation

/// Summary returned after a capture is ingested.
struct CaptureSummary: Codable, Hashable {
    let chunkCount: Int
    let wordCount: Int
    let domains: [String]
    let transcript: String?

    enum CodingKeys: String, CodingKey {
        case chunkCount = "chunk_count"
        case wordCount = "word_count"
        case domains, transcript
    }
}

/// Transcript returned by the transcribe-only endpoint / on-device transcriber.
struct Transcript: Codable, Hashable {
    let transcript: String
    let durationSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case transcript
        case durationSeconds = "duration_seconds"
    }
}

import Foundation

/// Live `KairoAPI` implementation backed by URLSession + async/await.
final class KairoAPIClient: KairoAPI {
    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL = AppConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: Request bodies
    private struct TextBody: Encodable { let text: String; let source: String }
    private struct QueryBody: Encodable { let question: String }
    private struct ReviewBody: Encodable { let rating: String; let reflection: String? }
    private struct PinBody: Encodable { let front: String; let back: String }
    private struct PinResult: Decodable { let pinned: Bool }
    private struct RecallBody: Encodable { let memory_id: String; let response: String? }
    private struct Empty: Decodable {}

    // MARK: Core helpers

    /// Builds a request URL. Note: we can't use `appendingPathComponent` because
    /// it percent-encodes "?" and breaks query strings — so we compose the raw
    /// absolute string instead.
    private func makeURL(_ path: String) -> URL {
        URL(string: baseURL.absoluteString + "/" + path)!
    }

    /// Attach the bearer token when the backend requires one.
    private func authorize(_ request: inout URLRequest) {
        if let token = AppConfig.apiToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = obj["detail"] as? String {
                throw APIError(message: detail)
            }
            throw APIError(message: "Server error (\(http.statusCode))")
        }
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: makeURL(path))
        authorize(&req)
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: Encodable?) async throws -> T {
        var req = URLRequest(url: makeURL(path))
        req.httpMethod = "POST"
        authorize(&req)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
        return try decoder.decode(T.self, from: data)
    }

    // MARK: KairoAPI
    func stats() async throws -> Stats { try await get("api/stats") }

    func recentMemories(limit: Int) async throws -> [Memory] {
        try await get("api/memories?limit=\(limit)")
    }

    func memories(domain: String?, limit: Int) async throws -> [Memory] {
        var path = "api/memories?limit=\(limit)"
        if let domain { path += "&domain=\(domain)" }
        return try await get(path)
    }

    func captureText(_ text: String) async throws -> CaptureSummary {
        try await post("api/capture/text", body: TextBody(text: text, source: "text"))
    }

    func query(_ question: String) async throws -> RAGResponse {
        try await post("api/query", body: QueryBody(question: question))
    }

    func transcribe(audioURL: URL) async throws -> Transcript {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: makeURL("api/transcribe"))
        req.httpMethod = "POST"
        authorize(&req)
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"audio\"; filename=\"checkin.m4a\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(try Data(contentsOf: audioURL))
        append("\r\n--\(boundary)--\r\n")

        let (data, resp) = try await session.upload(for: req, from: body)
        try check(resp, data)
        return try decoder.decode(Transcript.self, from: data)
    }

    func dueCards(limit: Int) async throws -> [Card] {
        try await get("api/cards/due?limit=\(limit)")
    }

    func cardStats() async throws -> CardStats { try await get("api/cards/stats") }

    func review(cardId: String, rating: Rating, reflection: String?) async throws -> ReviewResult {
        try await post("api/cards/\(cardId)/review",
                       body: ReviewBody(rating: rating.rawValue, reflection: reflection))
    }

    func pin(front: String, back: String) async throws -> Bool {
        let r: PinResult = try await post("api/cards/pin", body: PinBody(front: front, back: back))
        return r.pinned
    }

    func seedDemo() async throws {
        let _: Empty = try await post("api/demo/seed", body: nil)
    }

    // MARK: Proactive Engine
    func proactiveToday() async throws -> ProactiveToday {
        try await get("api/proactive/today")
    }

    func respondRecall(memoryId: String, response: String) async throws {
        let _: Empty = try await post("api/proactive/respond",
                                      body: RecallBody(memory_id: memoryId, response: response))
    }

    func dismissRecall(memoryId: String) async throws {
        let _: Empty = try await post("api/proactive/dismiss",
                                      body: RecallBody(memory_id: memoryId, response: nil))
    }

    func digest(refresh: Bool) async throws -> Digest {
        try await get("api/digest" + (refresh ? "?refresh=true" : ""))
    }
}

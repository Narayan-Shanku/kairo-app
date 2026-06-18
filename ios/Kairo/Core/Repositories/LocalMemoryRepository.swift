import Foundation

/// Fully on-device MemoryRepository: capture → embed (NLEmbedding) → store; query
/// → cosine search → grounded answer via Apple Foundation Models. No backend.
struct LocalMemoryRepository: MemoryRepository {
    let store: OnDeviceStore
    let embedding = EmbeddingService()
    let classifier = DomainClassifier()
    let generation = GenerationService()

    static func nowISO() -> String { ISO8601DateFormatter().string(from: Date()) }

    func stats() async throws -> Stats {
        let mems = await store.memories
        var domains: [String: Int] = [:]
        for m in mems { for d in m.domains { domains[d, default: 0] += 1 } }
        return Stats(totalMemories: mems.count, totalSessions: mems.count, domains: domains)
    }

    func recent(limit: Int) async throws -> [Memory] {
        let mems = await store.memories.sorted { $0.timestamp > $1.timestamp }
        return mems.prefix(limit).map(\.asMemory)
    }

    func memories(domain: String?, limit: Int) async throws -> [Memory] {
        var mems = await store.memories.sorted { $0.timestamp > $1.timestamp }
        if let domain { mems = mems.filter { $0.domains.contains(domain) } }
        return mems.prefix(limit).map(\.asMemory)
    }

    func captureText(_ text: String) async throws -> CaptureSummary {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let domains = classifier.classify(trimmed)
        let m = OnDeviceStore.StoredMemory(
            chunkId: UUID().uuidString, text: trimmed, domains: domains,
            timestamp: Self.nowISO(), sourceType: "text",
            embedding: embedding.embed(trimmed) ?? [])
        await store.addMemory(m)
        return CaptureSummary(chunkCount: 1, wordCount: trimmed.split(separator: " ").count,
                              domains: domains, transcript: nil)
    }

    func query(_ question: String) async throws -> RAGResponse {
        let mems = await store.memories
        guard !mems.isEmpty else {
            return RAGResponse(answer: "I don't have any memories yet — capture a check-in first.",
                               sources: [], confidence: 0)
        }
        let ranked = rank(question, mems, limit: 5)
        if let answer = await generation.generate(buildPrompt(question, ranked)) {
            return RAGResponse(answer: answer, sources: ranked.map(toSource), confidence: 1)
        }
        // Fallback (device without Apple Intelligence): extractive recall.
        let body = ranked.map { "• \(DateFormat.pretty($0.timestamp)): \($0.text)" }.joined(separator: "\n\n")
        return RAGResponse(
            answer: "On-device AI isn't available on this device — here are your most relevant memories:\n\n\(body)",
            sources: ranked.map(toSource), confidence: 0.5)
    }

    func pinAnswer(question: String, answer: String) async throws -> Bool {
        let now = Self.nowISO()
        await store.addCard(OnDeviceStore.StoredCard(
            cardId: UUID().uuidString, type: "pinned", front: question, back: answer,
            domain: "", createdAt: now, dueDate: now, ease: 2.5, intervalDays: 0,
            repetitions: 0, lapses: 0, lastReviewed: nil))
        return true
    }

    func searchOffline(_ query: String, limit: Int) async -> [Memory] {
        let mems = await store.memories
        return rank(query, mems, limit: limit).map(\.asMemory)
    }

    func seedDemo() async throws {
        await DemoData.seed(into: store, embedding: embedding)
    }

    // MARK: - Ranking & prompt

    private func rank(_ q: String, _ mems: [OnDeviceStore.StoredMemory], limit: Int) -> [OnDeviceStore.StoredMemory] {
        if let qv = embedding.embed(q) {
            let scored = mems.compactMap { m -> (OnDeviceStore.StoredMemory, Double)? in
                m.embedding.isEmpty ? nil : (m, EmbeddingService.cosine(qv, m.embedding))
            }
            let ranked = scored.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
            if !ranked.isEmpty { return Array(ranked) }
        }
        // Keyword fallback.
        let terms = Set(tokenize(q))
        let scored = mems.map { ($0, terms.intersection(tokenize($0.text)).count) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
        return Array(scored)
    }

    private func tokenize(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 2 })
    }

    private func toSource(_ m: OnDeviceStore.StoredMemory) -> Source {
        Source(chunkId: m.chunkId, date: DateFormat.pretty(m.timestamp),
               domain: m.domains.first ?? "General", snippet: String(m.text.prefix(200)))
    }

    private func buildPrompt(_ question: String, _ memories: [OnDeviceStore.StoredMemory]) -> String {
        var ctx = ""
        for (i, m) in memories.enumerated() {
            ctx += "[\(i + 1)] \(DateFormat.pretty(m.timestamp)) (\(m.domains.first ?? "General")): \(m.text)\n"
        }
        return """
        You are Kairō, a personal memory assistant. Answer ONLY using the memories below. \
        If they don't contain relevant info, say so. Cite the memories you use by their date. \
        Be concise and specific.

        MEMORIES:
        \(ctx)
        QUESTION: \(question)
        """
    }
}

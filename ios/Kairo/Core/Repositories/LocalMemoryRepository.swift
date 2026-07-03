import Foundation

/// Fully on-device MemoryRepository: capture → embed (NLEmbedding) → store; query
/// → cosine search → grounded answer via Apple Foundation Models. No backend.
struct LocalMemoryRepository: MemoryRepository {
    let store: OnDeviceStore
    let embedding = EmbeddingService()
    let classifier = DomainClassifier()
    let generation = GenerationService()
    let cloud = CloudGenerationService()   // used only when on-device is unavailable

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
        // Chunk long entries so retrieval matches at sentence granularity; short
        // entries stay whole (chunks == nil → the whole-entry embedding is used).
        let pieces = TextChunker.chunks(trimmed)
        let chunks: [OnDeviceStore.Chunk]? = pieces.count > 1
            ? pieces.map { OnDeviceStore.Chunk(text: $0, embedding: embedding.embed($0) ?? []) }
            : nil
        let m = OnDeviceStore.StoredMemory(
            chunkId: UUID().uuidString, text: trimmed, domains: domains,
            timestamp: Self.nowISO(), sourceType: "text",
            embedding: embedding.embed(trimmed) ?? [], chunks: chunks)
        await store.addMemory(m)
        return CaptureSummary(chunkCount: pieces.count, wordCount: trimmed.split(separator: " ").count,
                              domains: domains, transcript: nil)
    }

    func query(_ question: String) async throws -> RAGResponse {
        let mems = await store.memories
        guard !mems.isEmpty else {
            return RAGResponse(answer: "I don't have any memories yet — capture a check-in first.",
                               sources: [], confidence: 0)
        }
        // Relevance floor: if nothing plausibly matches, say so honestly rather
        // than forcing unrelated memories on the model.
        guard hasRelevant(question, mems) else {
            return RAGResponse(
                answer: "I don't have anything relevant to that yet. Capture a check-in about it, then ask again.",
                sources: [], confidence: 0)
        }
        let ranked = rank(question, mems, limit: 5)
        let prompt = buildPrompt(question, ranked)
        // On-device (Apple Foundation Models) first; on iPhones without Apple
        // Intelligence, fall back to the cloud proxy if one is configured.
        var answer = await generation.generate(prompt)
        if answer == nil { answer = await cloud.generate(prompt) }
        if let answer {
            return RAGResponse(answer: answer, sources: ranked.map(toSource), confidence: 1)
        }
        // Last resort (no on-device AI, no cloud proxy): extractive recall.
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

    /// Hybrid retrieval: semantic (best-matching chunk) + keyword overlap, fused
    /// via Reciprocal Rank Fusion so exact-term and semantic matches both count.
    private func rank(_ q: String, _ mems: [OnDeviceStore.StoredMemory], limit: Int) -> [OnDeviceStore.StoredMemory] {
        let qv = embedding.embed(q)
        let semantic: [OnDeviceStore.StoredMemory] = qv == nil ? [] : mems
            .map { ($0, bestChunkScore($0, query: qv!)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        let terms = Set(tokenize(q))
        let keyword: [OnDeviceStore.StoredMemory] = terms.isEmpty ? [] : mems
            .map { ($0, terms.intersection(tokenize($0.text)).count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        let fused = rrf(semantic, keyword)
        // Neither signal produced a hit (no embeddings + no term overlap): fall
        // back to most-recent so offline search still has something to show.
        let result = fused.isEmpty ? mems.sorted { $0.timestamp > $1.timestamp } : fused
        return Array(result.prefix(limit))
    }

    /// Best cosine over a memory's chunks (finer than whole-entry); falls back to
    /// the whole-entry embedding for memories captured before chunking existed.
    private func bestChunkScore(_ m: OnDeviceStore.StoredMemory, query: [Double]) -> Double {
        if let chunks = m.chunks, !chunks.isEmpty {
            return chunks.compactMap { $0.embedding.isEmpty ? nil : EmbeddingService.cosine(query, $0.embedding) }.max() ?? 0
        }
        return m.embedding.isEmpty ? 0 : EmbeddingService.cosine(query, m.embedding)
    }

    /// Reciprocal Rank Fusion (k = 60) over two ranked lists, keyed by memory id.
    private func rrf(_ a: [OnDeviceStore.StoredMemory], _ b: [OnDeviceStore.StoredMemory], k: Double = 60) -> [OnDeviceStore.StoredMemory] {
        var score: [String: Double] = [:]
        var byId: [String: OnDeviceStore.StoredMemory] = [:]
        for (i, m) in a.enumerated() { score[m.chunkId, default: 0] += 1 / (k + Double(i + 1)); byId[m.chunkId] = m }
        for (i, m) in b.enumerated() { score[m.chunkId, default: 0] += 1 / (k + Double(i + 1)); byId[m.chunkId] = m }
        return score.sorted { $0.value > $1.value }.compactMap { byId[$0.key] }
    }

    /// Whether any memory plausibly relates to the question — a keyword hit, or a
    /// semantic score above a conservative floor. Gates the "nothing relevant"
    /// short-circuit; the keyword OR keeps it from over-filtering good queries.
    private func hasRelevant(_ q: String, _ mems: [OnDeviceStore.StoredMemory]) -> Bool {
        let terms = Set(tokenize(q))
        if !terms.isEmpty, mems.contains(where: { !terms.intersection(tokenize($0.text)).isEmpty }) { return true }
        guard let qv = embedding.embed(q) else { return false }
        // Conservative floor: catch clearly-off-topic questions only. The grounding
        // prompt is the fine relevance filter, so we err toward letting the LLM judge.
        return mems.contains { bestChunkScore($0, query: qv) >= 0.15 }
    }

    private func tokenize(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter && !$0.isNumber }
            .map(String.init).filter { $0.count > 2 }.map(Self.stem))
    }

    /// Light suffix stemmer so morphological variants match (bloating/bloated →
    /// bloat, triggers → trigger). Mirrors the backend's keyword stemming.
    private static func stem(_ word: String) -> String {
        for suffix in ["ing", "edly", "ed", "ies", "es", "ment", "ly", "s"] {
            if word.count > suffix.count + 2, word.hasSuffix(suffix) {
                return String(word.dropLast(suffix.count))
            }
        }
        return word
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

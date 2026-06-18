import Foundation
import Observation

@MainActor
@Observable
final class AskViewModel {
    struct Exchange: Identifiable {
        let id = UUID()
        let question: String
        var answer: String?
        var sources: [Source] = []
        var pinned = false
    }

    private let memories: MemoryRepository

    var exchanges: [Exchange] = []
    var isBusy = false

    let suggestions = [
        "What triggers my bloating?",
        "What helps my afternoon focus?",
        "What did I learn this month?",
    ]

    init(memories: MemoryRepository) {
        self.memories = memories
    }

    func ask(_ raw: String) async {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        let exchange = Exchange(question: question)
        exchanges.append(exchange)
        isBusy = true
        do {
            let r = try await memories.query(question)
            update(exchange.id) { $0.answer = r.answer; $0.sources = r.sources }
        } catch {
            await fallbackOffline(question, exchangeId: exchange.id, error: error)
        }
        isBusy = false
    }

    /// When the backend is unreachable, search cached memories on-device and show
    /// the most relevant ones (no generated answer — that needs the server).
    private func fallbackOffline(_ question: String, exchangeId: UUID, error: Error) async {
        let related = await memories.searchOffline(question, limit: 3)
        guard !related.isEmpty else {
            update(exchangeId) { $0.answer = "Error: \(error.localizedDescription)" }
            return
        }
        let body = related
            .map { "• (\(DateFormat.pretty($0.timestamp))) \($0.text)" }
            .joined(separator: "\n\n")
        update(exchangeId) {
            $0.answer = "You're offline — here are related memories from your device:\n\n\(body)"
            $0.sources = related.map {
                Source(chunkId: $0.chunkId, date: DateFormat.pretty($0.timestamp),
                       domain: $0.primaryDomain, snippet: $0.text)
            }
        }
    }

    func pin(_ id: UUID) async {
        guard let ex = exchanges.first(where: { $0.id == id }), let answer = ex.answer else { return }
        if (try? await memories.pinAnswer(question: ex.question, answer: answer)) == true {
            update(id) { $0.pinned = true }
        }
    }

    private func update(_ id: UUID, _ mutate: (inout Exchange) -> Void) {
        guard let i = exchanges.firstIndex(where: { $0.id == id }) else { return }
        mutate(&exchanges[i])
    }
}

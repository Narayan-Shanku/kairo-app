import Foundation
import Observation

@MainActor
@Observable
final class ReviewViewModel {
    private let cards: CardRepository

    var queue: [Card] = []
    var revealed = false
    var reflection = ""
    var isLoading = true
    var errorMessage: String?

    init(cards: CardRepository) {
        self.cards = cards
    }

    var current: Card? { queue.first }

    func load() async {
        isLoading = true
        do {
            queue = try await cards.due(limit: 50)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reveal() { revealed = true }

    func rate(_ rating: Rating) async {
        guard let card = current else { return }
        let note = (card.isDecision && !reflection.trimmingCharacters(in: .whitespaces).isEmpty)
            ? reflection : nil
        try? await cards.review(cardId: card.id, rating: rating, reflection: note)
        if !queue.isEmpty { queue.removeFirst() }
        revealed = false
        reflection = ""
    }
}

import Testing
@testable import Kairo

@MainActor
struct ReviewViewModelTests {
    @Test func loadPopulatesQueue() async {
        let cards = MockCardRepository()
        let vm = ReviewViewModel(cards: cards)

        await vm.load()

        #expect(vm.queue.count == 1)
        #expect(vm.isLoading == false)
        #expect(vm.current?.id == "c1")
    }

    @Test func ratingAdvancesQueueAndResetsState() async {
        let cards = MockCardRepository()
        let vm = ReviewViewModel(cards: cards)
        await vm.load()

        vm.reveal()
        vm.reflection = "Yes, it stuck"
        await vm.rate(.good)

        #expect(vm.queue.isEmpty)
        #expect(vm.revealed == false)
        #expect(vm.reflection == "")
    }

    @Test func decisionReflectionIsForwarded() async {
        let cards = MockCardRepository()
        let vm = ReviewViewModel(cards: cards)
        await vm.load()
        vm.reveal()
        vm.reflection = "Held up well"

        await vm.rate(.easy)

        #expect(cards.reviews.first?.id == "c1")
        #expect(cards.reviews.first?.rating == .easy)
        #expect(cards.reviews.first?.reflection == "Held up well")
    }

    @Test func nonDecisionCardSendsNoReflection() async {
        let cards = MockCardRepository()
        cards.dueResult = [Card(cardId: "c2", type: "insight", front: "Q", back: "A", domain: "Health")]
        let vm = ReviewViewModel(cards: cards)
        await vm.load()
        vm.reveal()
        vm.reflection = "ignored for insight cards"

        await vm.rate(.good)

        #expect(cards.reviews.first?.reflection == nil)
    }
}

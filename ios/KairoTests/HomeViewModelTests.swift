import Testing
@testable import Kairo

@MainActor
struct HomeViewModelTests {
    private func makeVM(
        memories: MockMemoryRepository = MockMemoryRepository(),
        cards: MockCardRepository = MockCardRepository(),
        proactive: MockProactiveRepository = MockProactiveRepository()
    ) -> HomeViewModel {
        HomeViewModel(memories: memories, cards: cards, proactive: proactive)
    }

    @Test func loadPopulatesStatsRecentAndCards() async {
        let vm = makeVM()
        await vm.load()
        #expect(vm.stats?.totalMemories == 3)
        #expect(vm.stats?.activeDomainCount == 2)
        #expect(vm.recent.count == 1)
        #expect(vm.cardStats?.due == 2)
        #expect(vm.errorMessage == nil)
        #expect(vm.showSeedBanner == false)
    }

    @Test func showsSeedBannerWhenStoreEmpty() async {
        let memories = MockMemoryRepository()
        memories.statsResult = Stats(totalMemories: 0, totalSessions: 0, domains: [:])
        memories.recentResult = []
        let vm = makeVM(memories: memories)
        await vm.load()
        #expect(vm.showSeedBanner == true)
    }

    @Test func setsErrorMessageOnFailure() async {
        let memories = MockMemoryRepository()
        memories.throwError = APIError(message: "offline")
        let vm = makeVM(memories: memories)
        await vm.load()
        #expect(vm.errorMessage != nil)
    }

    @Test func seedDemoReloads() async {
        let memories = MockMemoryRepository()
        let vm = makeVM(memories: memories)
        await vm.seedDemo()
        #expect(memories.seeded == true)
        #expect(vm.isSeeding == false)
    }

    // MARK: Proactive Engine

    @Test func loadPopulatesProactive() async {
        let vm = makeVM()
        await vm.load()
        #expect(vm.today?.streak.current == 5)
        #expect(vm.today?.recall?.memoryId == "r1")
        #expect(vm.today?.nudges.count == 1)
    }

    @Test func submitRecallForwardsAndClears() async {
        let proactive = MockProactiveRepository()
        let vm = makeVM(proactive: proactive)
        await vm.load()
        vm.recallReply = "It got better after I cut lentils"
        await vm.submitRecall()
        #expect(proactive.responded.first?.id == "r1")
        #expect(proactive.responded.first?.text == "It got better after I cut lentils")
        #expect(vm.recallReply == "")
    }

    @Test func dismissRecallForwards() async {
        let proactive = MockProactiveRepository()
        let vm = makeVM(proactive: proactive)
        await vm.load()
        await vm.dismissRecall()
        #expect(proactive.dismissed.first == "r1")
    }
}

@MainActor
struct DigestViewModelTests {
    @Test func loadPopulatesDigest() async {
        let vm = DigestViewModel(proactive: MockProactiveRepository())
        await vm.load()
        #expect(vm.digest?.memoryCount == 9)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func setsErrorOnFailure() async {
        let proactive = MockProactiveRepository()
        proactive.throwError = APIError(message: "down")
        let vm = DigestViewModel(proactive: proactive)
        await vm.load()
        #expect(vm.errorMessage != nil)
    }
}

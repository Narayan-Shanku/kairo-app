import Testing
@testable import Kairo

struct OnDeviceSearchTests {
    private let fitness = Memory(chunkId: "1",
        text: "I went for a long morning run and felt energized all day",
        domains: ["Fitness"], timestamp: "2026-06-10T09:00:00Z", sourceType: "text")
    private let finance = Memory(chunkId: "2",
        text: "Reviewed the quarterly budget and cut two expenses",
        domains: ["Finance"], timestamp: "2026-06-09T09:00:00Z", sourceType: "text")

    @Test func ranksRelevantMemoryFirst() {
        let results = OnDeviceSearch().rank(
            query: "morning run and exercise energy",
            memories: [finance, fitness], limit: 2)
        #expect(results.first?.chunkId == "1")
    }

    @Test func emptyCorpusReturnsEmpty() {
        #expect(OnDeviceSearch().rank(query: "anything", memories: [], limit: 5).isEmpty)
    }
}

@MainActor
struct AskOfflineFallbackTests {
    @Test func fallsBackToOnDeviceSearchWhenQueryFails() async {
        let memories = MockMemoryRepository()
        memories.throwError = APIError(message: "offline")
        memories.offlineResults = [
            Memory(chunkId: "x", text: "Walked before work, focused all afternoon",
                   domains: ["Fitness"], timestamp: "2026-06-10T09:00:00Z", sourceType: "text")
        ]
        let vm = AskViewModel(memories: memories)

        await vm.ask("what helps my focus")

        #expect(vm.exchanges.first?.answer?.localizedCaseInsensitiveContains("offline") == true)
        #expect(vm.exchanges.first?.sources.count == 1)
    }

    @Test func showsErrorWhenOfflineAndNothingCached() async {
        let memories = MockMemoryRepository()
        memories.throwError = APIError(message: "offline")
        memories.offlineResults = []
        let vm = AskViewModel(memories: memories)

        await vm.ask("anything")

        #expect(vm.exchanges.first?.answer?.localizedCaseInsensitiveContains("error") == true)
    }
}

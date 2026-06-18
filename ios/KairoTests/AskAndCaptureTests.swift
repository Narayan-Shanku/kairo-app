import Testing
@testable import Kairo

@MainActor
struct AskViewModelTests {
    @Test func askAddsExchangeWithGroundedAnswer() async {
        let memories = MockMemoryRepository()
        let vm = AskViewModel(memories: memories)

        await vm.ask("why bloating?")

        #expect(vm.exchanges.count == 1)
        #expect(vm.exchanges.first?.answer == "Because lentils.")
        #expect(vm.exchanges.first?.sources.count == 1)
        #expect(vm.isBusy == false)
    }

    @Test func blankQuestionIsIgnored() async {
        let vm = AskViewModel(memories: MockMemoryRepository())
        await vm.ask("   ")
        #expect(vm.exchanges.isEmpty)
    }

    @Test func pinMarksExchangePinned() async {
        let memories = MockMemoryRepository()
        let vm = AskViewModel(memories: memories)
        await vm.ask("q")
        let id = vm.exchanges[0].id

        await vm.pin(id)

        #expect(vm.exchanges[0].pinned == true)
        #expect(memories.pinned.count == 1)
    }
}

@MainActor
struct CaptureViewModelTests {
    @Test func saveTextIngestsAndReportsStatus() async {
        let memories = MockMemoryRepository()
        let vm = CaptureViewModel(
            audio: MockAudioRecording(),
            transcription: MockTranscription(),
            memories: memories)

        await vm.saveText("Learned to batch my email")

        #expect(memories.captured.contains("Learned to batch my email"))
        #expect(vm.statusMessage?.contains("Saved") == true)
        #expect(vm.errorMessage == nil)
    }

    @Test func blankTextIsIgnored() async {
        let memories = MockMemoryRepository()
        let vm = CaptureViewModel(
            audio: MockAudioRecording(),
            transcription: MockTranscription(),
            memories: memories)

        await vm.saveText("   ")

        #expect(memories.captured.isEmpty)
    }
}

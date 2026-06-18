import Foundation
import Observation

/// Dependency-injection container. Built once at launch and injected into the
/// SwiftUI environment; ViewModels receive the repositories/services they need.
/// Tests build their own `AppEnvironment` (or call ViewModels directly) with mocks.
@MainActor
@Observable
final class AppEnvironment {
    let api: KairoAPI
    let memories: MemoryRepository
    let cards: CardRepository
    let proactive: ProactiveRepository
    let audio: AudioRecording
    let transcription: TranscriptionService

    init(
        api: KairoAPI,
        memories: MemoryRepository,
        cards: CardRepository,
        proactive: ProactiveRepository,
        audio: AudioRecording,
        transcription: TranscriptionService
    ) {
        self.api = api
        self.memories = memories
        self.cards = cards
        self.proactive = proactive
        self.audio = audio
        self.transcription = transcription
    }

    /// The production wiring.
    static func live() -> AppEnvironment {
        if AppConfig.standalone { return standalone() }
        let api = KairoAPIClient()

        // On-device JSON-file cache (offline reads + on-device search corpus).
        let cache = LocalCache()

        let remote = RemoteTranscription(api: api)
        // On-device WhisperKit when enabled, with the remote endpoint as fallback.
        let transcription: TranscriptionService = AppConfig.useOnDeviceTranscription
            ? WhisperKitTranscription(fallback: remote)
            : remote

        return AppEnvironment(
            api: api,
            memories: DefaultMemoryRepository(api: api, cache: cache, search: OnDeviceSearch()),
            cards: DefaultCardRepository(api: api, cache: cache),
            proactive: DefaultProactiveRepository(api: api),
            audio: AVAudioRecording(),
            transcription: transcription
        )
    }

    /// Fully on-device wiring — no backend. Embeddings via NLEmbedding, generation
    /// via Apple Foundation Models, storage local, transcription via Apple Speech.
    static func standalone() -> AppEnvironment {
        let store = OnDeviceStore()
        let memories = LocalMemoryRepository(store: store)
        let cards = LocalCardRepository(store: store, memories: memories)
        let proactive = LocalProactiveRepository(store: store, memories: memories)
        let transcription = AppleSpeechTranscription(
            fallback: WhisperKitTranscription(fallback: RemoteTranscription(api: KairoAPIClient())))
        return AppEnvironment(
            api: KairoAPIClient(),       // unused in standalone, kept for the type
            memories: memories,
            cards: cards,
            proactive: proactive,
            audio: AVAudioRecording(),
            transcription: transcription
        )
    }
}

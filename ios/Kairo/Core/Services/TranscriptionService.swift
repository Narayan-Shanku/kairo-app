import Foundation

/// Turns a recorded audio file into text. Two implementations:
///   • `RemoteTranscription` — uploads to the backend's `/api/transcribe`.
///   • `WhisperKitTranscription` — runs Whisper on-device (see WhisperKitTranscription.swift).
/// `CaptureViewModel` depends only on this protocol, so swapping on-device in is
/// a one-line change in the DI container.
protocol TranscriptionService {
    /// Human label for the active engine (shown in the UI).
    var engineName: String { get }
    func transcribe(audioURL: URL) async throws -> String
}

/// Transcribes by uploading to the Kairō backend.
struct RemoteTranscription: TranscriptionService {
    let api: KairoAPI
    var engineName: String { "server" }

    func transcribe(audioURL: URL) async throws -> String {
        try await api.transcribe(audioURL: audioURL).transcript
    }
}

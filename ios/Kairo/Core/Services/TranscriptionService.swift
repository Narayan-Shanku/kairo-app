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

/// Terminal fallback for standalone builds: there is no server, so if every
/// on-device engine failed, fail with a clear, actionable message instead of a
/// doomed network call surfacing a raw NSURLError.
struct UnavailableTranscription: TranscriptionService {
    var engineName: String { "on-device" }

    func transcribe(audioURL: URL) async throws -> String {
        throw APIError(message: "Couldn't transcribe this recording — check Speech "
            + "Recognition permission for Kairō in iOS Settings, or type your check-in instead.")
    }
}

import Foundation
import WhisperKit

/// On-device transcription via WhisperKit (Whisper running locally through Core ML).
///
/// The model is loaded lazily and cached (first use downloads the weights). If
/// anything goes wrong — model unavailable, no network for the first download,
/// empty result — it transparently falls back to the remote endpoint, so capture
/// always works. Swapping engines is invisible to the rest of the app.
final class WhisperKitTranscription: TranscriptionService {
    private let fallback: TranscriptionService
    private let modelName: String
    private var whisperKit: WhisperKit?
    private var loadTask: Task<WhisperKit, Error>?

    init(fallback: TranscriptionService, model: String = "base") {
        self.fallback = fallback
        self.modelName = model
    }

    var engineName: String { "on-device" }

    func transcribe(audioURL: URL) async throws -> String {
        do {
            let kit = try await loadModel()
            let results = try await kit.transcribe(audioPath: audioURL.path)
            let text = results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? try await fallback.transcribe(audioURL: audioURL) : text
        } catch {
            // On-device path failed — fall back to the server so capture still works.
            return try await fallback.transcribe(audioURL: audioURL)
        }
    }

    /// Loads and caches the WhisperKit model. A successful load is cached for
    /// the app's lifetime; a FAILED load (e.g. offline first download) clears the
    /// task so the next capture retries instead of being stuck on the failure.
    private func loadModel() async throws -> WhisperKit {
        if let whisperKit { return whisperKit }
        if let loadTask { return try await loadTask.value }
        let name = modelName   // avoid capturing self in the load task
        let task = Task { try await WhisperKit(model: name) }
        loadTask = task
        do {
            let kit = try await task.value
            whisperKit = kit
            return kit
        } catch {
            loadTask = nil
            throw error
        }
    }
}

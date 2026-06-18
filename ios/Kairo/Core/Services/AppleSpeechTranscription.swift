import Foundation
import Speech

/// On-device transcription via Apple's Speech framework (no model download when
/// on-device recognition is supported). Falls back to `fallback` (e.g. WhisperKit)
/// if speech auth/recognition isn't available.
struct AppleSpeechTranscription: TranscriptionService {
    let fallback: TranscriptionService
    var engineName: String { "on-device" }

    func transcribe(audioURL: URL) async throws -> String {
        guard await requestAuth(),
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            return try await fallback.transcribe(audioURL: audioURL)
        }
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        do {
            let text = try await recognize(recognizer, request)
            return text.isEmpty ? try await fallback.transcribe(audioURL: audioURL) : text
        } catch {
            return try await fallback.transcribe(audioURL: audioURL)
        }
    }

    private func recognize(_ recognizer: SFSpeechRecognizer,
                           _ request: SFSpeechURLRecognitionRequest) async throws -> String {
        let lock = NSLock()
        var finished = false
        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                lock.lock(); defer { lock.unlock() }
                if finished { return }
                if let error {
                    finished = true
                    cont.resume(throwing: error)
                } else if let result, result.isFinal {
                    finished = true
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private func requestAuth() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }
}

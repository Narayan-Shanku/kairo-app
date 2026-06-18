import Foundation
import Observation

@MainActor
@Observable
final class CaptureViewModel {
    private let audio: AudioRecording
    private let transcription: TranscriptionService
    private let memories: MemoryRepository

    var isRecording = false
    var elapsed = 0
    var isBusy = false
    var statusMessage: String?
    var errorMessage: String?

    private var timerTask: Task<Void, Never>?
    private let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("checkin.m4a")

    init(audio: AudioRecording, transcription: TranscriptionService, memories: MemoryRepository) {
        self.audio = audio
        self.transcription = transcription
        self.memories = memories
    }

    var elapsedLabel: String { String(format: "%d:%02d", elapsed / 60, elapsed % 60) }
    var engineName: String { transcription.engineName }

    func toggleRecord() async {
        errorMessage = nil
        if isRecording { await stopAndIngest() } else { await startRecording() }
    }

    private func startRecording() async {
        guard await audio.requestPermission() else {
            errorMessage = "Microphone permission denied. Enable it in Settings."
            return
        }
        do {
            try audio.start(url: fileURL)
            isRecording = true
            elapsed = 0
            statusMessage = nil
            startTimer()
        } catch {
            errorMessage = "Couldn't start recording: \(error.localizedDescription)"
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isRecording else { return }
                self.elapsed += 1
                if self.elapsed >= 300 { await self.stopAndIngest() }   // 5-minute cap
            }
        }
    }

    private func stopAndIngest() async {
        timerTask?.cancel()
        timerTask = nil
        audio.stop()
        isRecording = false
        isBusy = true
        statusMessage = "Transcribing (\(engineName))…"
        do {
            let text = try await transcription.transcribe(audioURL: fileURL)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                statusMessage = nil
                errorMessage = "No speech detected — try again."
                isBusy = false
                return
            }
            let summary = try await memories.captureText(text)
            statusMessage = "✓ Saved · \(summary.domains.joined(separator: ", "))\n“\(text)”"
        } catch {
            statusMessage = nil
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }

    func saveText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isBusy = true
        errorMessage = nil
        do {
            let summary = try await memories.captureText(trimmed)
            statusMessage = "✓ Saved · \(summary.domains.joined(separator: ", "))"
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}

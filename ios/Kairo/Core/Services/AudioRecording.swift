import AVFoundation

/// Records audio to a file. Kept deliberately "dumb" — no observable state — so
/// the owning ViewModel holds the timer/`isRecording` state (clean for SwiftUI)
/// and this stays trivially mockable in tests.
protocol AudioRecording {
    func requestPermission() async -> Bool
    func start(url: URL) throws
    func stop()
}

/// AVFoundation-backed recorder producing an AAC `.m4a` file.
final class AVAudioRecording: AudioRecording {
    private var recorder: AVAudioRecorder?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start(url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        try? FileManager.default.removeItem(at: url)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.record()
        recorder = rec
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

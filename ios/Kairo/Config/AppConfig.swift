import Foundation

/// App-wide configuration.
///
/// By default Kairō runs **fully on-device** (`standalone = true`) — no server.
/// The `baseURL` below is only used if you flip `standalone` to `false` to run
/// against the optional Kairō FastAPI backend (the same one the web app uses):
///   • iOS Simulator on this Mac → `http://localhost:8000` works as-is.
///   • Physical iPhone → set this to your Mac's LAN address, e.g.
///     `http://192.168.1.42:8000` (find it with `ipconfig getifaddr en0`),
///     with phone and Mac on the same Wi-Fi.
enum AppConfig {
    /// Only used when `standalone == false` (optional remote backend).
    static let baseURL = URL(string: "http://localhost:8000")!

    /// Prefer on-device transcription (WhisperKit) over the remote endpoint.
    static let useOnDeviceTranscription = true

    /// Standalone mode: run the ENTIRE app on-device (Apple Foundation Models +
    /// NLEmbedding + local store) with no backend. Set false to use the remote
    /// FastAPI backend instead.
    static let standalone = true

    /// Set when pointing at a secured/deployed backend (KAIRO_API_TOKEN). When
    /// nil (local), no auth header is sent.
    static let apiToken: String? = nil
}

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

    /// Stateless cloud-generation proxy, used ONLY when on-device generation
    /// (Apple Foundation Models) is unavailable — i.e. iPhones without Apple
    /// Intelligence (iPhone 11–14, SE, …). The phone still does capture,
    /// embedding, and retrieval locally; only the already-built prompt (the
    /// top-k retrieved snippets + the question) is sent here, and the proxy holds
    /// the LLM API key — never the app. Leave nil to stay fully on-device (older
    /// devices then degrade to extractive answers). Must be HTTPS.
    ///   e.g. URL(string: "https://kairo-generation-proxy.<you>.workers.dev")
    static let cloudGenerationURL: URL? = nil   // set to your deployed proxy URL (see proxy/README.md)

    /// Shared secret the proxy requires (must match the Worker's SHARED_TOKEN).
    /// This is a low-value abuse-control gate, NOT a real secret — it ships in
    /// the app binary, so the proxy's daily cap is the actual cost ceiling. Set
    /// to nil to send no auth header (only if the proxy has no SHARED_TOKEN).
    /// NOTE: keep the real URL/token as a local-only diff — never commit them.
    static let cloudGenerationToken: String? = nil
}

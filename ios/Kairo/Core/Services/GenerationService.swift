import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device text generation via Apple's built-in Foundation Models (iOS 26+,
/// Apple-Intelligence devices). No network, no model download. When the model
/// isn't available (older device, or the Simulator), `isAvailable` is false and
/// callers degrade gracefully (e.g. extractive search instead of a generated answer).
struct GenerationService {

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Generate a response to `prompt`. Returns nil if on-device generation is
    /// unavailable or fails, so callers can fall back.
    func generate(_ prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            do {
                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                return response.content
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }
}

/// Cloud-generation fallback for devices WITHOUT Apple Intelligence (iPhone 11–14,
/// SE, …). Mirrors `GenerationService.generate` so callers can chain them:
/// try on-device first, then cloud. Sends only the already-built prompt — the
/// top-k retrieved snippets + the question — to a stateless proxy that calls the
/// LLM and returns the completion. Raw memories never leave the device; the API
/// key lives on the proxy, not in the app. Returns nil (so callers degrade to the
/// extractive/template fallback) when no proxy is configured or the request fails.
struct CloudGenerationService {
    let endpoint: URL?

    init(endpoint: URL? = AppConfig.cloudGenerationURL) {
        self.endpoint = endpoint
    }

    /// User opt-out from Settings ("Use private cloud for answers"). Defaults on
    /// (missing key → true), so cloud fallback works until the user turns it off.
    private var userEnabled: Bool {
        UserDefaults.standard.object(forKey: "cloudAnswersEnabled") as? Bool ?? true
    }

    /// A proxy is configured AND the user hasn't opted out. When false, `generate`
    /// returns nil and callers stay fully on-device.
    var isConfigured: Bool { endpoint != nil && userEnabled }

    func generate(_ prompt: String) async -> String? {
        guard let endpoint, userEnabled else { return nil }

        struct Request: Encodable { let prompt: String }
        struct Reply: Decodable { let answer: String? }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AppConfig.cloudGenerationToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.timeoutInterval = 30

        do {
            req.httpBody = try JSONEncoder().encode(Request(prompt: prompt))
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return nil }
            let text = try JSONDecoder().decode(Reply.self, from: data).answer?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (text?.isEmpty == false) ? text : nil
        } catch {
            return nil
        }
    }
}

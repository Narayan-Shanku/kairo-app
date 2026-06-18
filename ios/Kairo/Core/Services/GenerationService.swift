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

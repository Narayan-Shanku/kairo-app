import Foundation
import Observation

@MainActor
@Observable
final class DigestViewModel {
    private let proactive: ProactiveRepository

    var digest: Digest?
    var isLoading = false
    var errorMessage: String?

    init(proactive: ProactiveRepository) {
        self.proactive = proactive
    }

    func load(refresh: Bool = false) async {
        isLoading = true
        do {
            digest = try await proactive.digest(refresh: refresh)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

import Foundation

enum DateFormat {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()
    private static let pretty: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Formats an ISO-8601 timestamp string as e.g. "Jun 15".
    static func pretty(_ iso: String) -> String {
        let date = isoFractional.date(from: iso) ?? self.iso.date(from: iso)
        guard let date else { return String(iso.prefix(10)) }
        return pretty.string(from: date)
    }
}

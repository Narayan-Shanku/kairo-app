import Foundation

/// Streak state the app shares with the home-screen widget through the App Group.
/// Small, Codable, written by the app and read by the widget's timeline provider.
struct StreakSnapshot: Codable, Hashable {
    var current: Int
    var longest: Int
    var checkedInToday: Bool
    var totalDays: Int
    /// `YYYY-MM-DD` of the most recent active day (capture or explicit check-in).
    var lastActiveISO: String?
    var updatedAt: Date

    static let empty = StreakSnapshot(current: 0, longest: 0, checkedInToday: false,
                                      totalDays: 0, lastActiveISO: nil, updatedAt: .distantPast)

    /// Sample used for widget previews / placeholders.
    static let preview = StreakSnapshot(current: 7, longest: 12, checkedInToday: true,
                                        totalDays: 24, lastActiveISO: SharedStore.todayISO(),
                                        updatedAt: Date())

    /// The streak to display as of `now`: still standing if the last active day was
    /// today or yesterday, otherwise broken (0).
    func displayStreak(asOf now: Date) -> Int {
        guard let last = lastActiveISO else { return 0 }
        return SunMood.dayGap(from: last, to: SharedStore.iso(now)) <= 1 ? current : 0
    }
}

/// App Group bridge between the app and the widget extension.
enum SharedStore {
    static let appGroup = "group.com.kairomemory.kairo"
    private static let key = "streak_snapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func save(_ snapshot: StreakSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> StreakSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(StreakSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    // MARK: Date helpers (shared by app + widget)
    static func iso(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func todayISO() -> String { iso(Date()) }
}

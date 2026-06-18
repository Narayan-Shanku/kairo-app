import Foundation

/// Streak math over a set of check-in dates (YYYY-MM-DD strings).
enum StreakCalc {
    private static func parse(_ dates: Set<String>) -> Set<DateComponents> {
        Set(dates.compactMap { iso -> DateComponents? in
            let parts = iso.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return DateComponents(year: parts[0], month: parts[1], day: parts[2])
        })
    }

    static func today() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func current(_ dates: Set<String>) -> Int {
        let cal = Calendar.current
        var day = Date()
        // If not checked in today, start the count from yesterday.
        if !dates.contains(iso(day)) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var streak = 0
        while dates.contains(iso(day)) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    static func longest(_ dates: Set<String>) -> Int {
        let cal = Calendar.current
        let sorted = dates.compactMap { date(from: $0) }.sorted()
        var longest = 0, run = 0
        var prev: Date?
        for d in sorted {
            if let p = prev, cal.date(byAdding: .day, value: 1, to: p).map({ cal.isDate($0, inSameDayAs: d) }) == true {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = d
        }
        return longest
    }

    private static func iso(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    private static func date(from iso: String) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
}

import Foundation
import UserNotifications

/// On-device check-in reminders. Schedules the next few evening nudges so the
/// streak doesn't break — fully local, no server. Streak state is read from
/// `UserDefaults.standard` (written by the proactive engine), so reminders work
/// even where the App Group/widget can't (e.g. a free-team device build).
enum NotificationService {
    private static let center = UNUserNotificationCenter.current()
    private static let ids = ["kairo-streak-0", "kairo-streak-1", "kairo-streak-2"]

    // Settings (backed by @AppStorage in SettingsView).
    static var remindersEnabled: Bool {
        UserDefaults.standard.object(forKey: "remindersEnabled") as? Bool ?? true
    }
    static var reminderHour: Int {
        UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 19
    }

    /// Snapshot of streak state for copy/skip logic, published by `publish(...)`.
    static func recordStreak(current: Int, lastActiveISO: String?) {
        let d = UserDefaults.standard
        d.set(current, forKey: "lastStreakCurrent")
        d.set(lastActiveISO ?? "", forKey: "lastActiveISO")
    }

    /// Ask for permission (once) if reminders are on, then (re)schedule.
    static func bootstrap() async {
        if remindersEnabled {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        refresh()
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Cancel and reschedule the next few evening reminders from current streak state.
    static func refresh() {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard remindersEnabled else { return }

        let d = UserDefaults.standard
        let current = d.integer(forKey: "lastStreakCurrent")
        let lastActive = d.string(forKey: "lastActiveISO") ?? ""
        let today = SharedStore.todayISO()
        let gap = lastActive.isEmpty ? 99 : SunMood.dayGap(from: lastActive, to: today)
        let checkedInToday = gap <= 0
        let streak = gap <= 1 ? current : 0   // still standing if active today/yesterday

        let cal = Calendar.current
        let now = Date()
        let hour = max(0, min(23, reminderHour))

        for offset in 0..<ids.count {
            guard let base = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: base)
            comps.hour = hour; comps.minute = 0
            guard let fireDate = cal.date(from: comps) else { continue }
            // Today: skip if already checked in or the time has already passed.
            if offset == 0 && (checkedInToday || fireDate <= now) { continue }

            let content = UNMutableNotificationContent()
            if streak > 0 {
                content.title = "Kairo's starting to set 🌅"
                content.body = "Check in to keep your \(streak)-day streak alive."
            } else {
                content.title = "Kairo misses you 🌙"
                content.body = "Capture a thought or check in to start a new streak."
            }
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false)
            center.add(UNNotificationRequest(identifier: ids[offset], content: content, trigger: trigger))
        }
    }

    static func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct StreakEntry: TimelineEntry {
    let date: Date
    let snapshot: StreakSnapshot
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        let snap = context.isPreview ? .preview : SharedStore.load()
        completion(StreakEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let snap = SharedStore.load()
        let now = Date()
        let cal = Calendar.current
        // Same snapshot, but several entries so Kairo's mood shifts through the day
        // (content → worried at dusk → asleep after midnight) without reopening the app.
        var entries = [StreakEntry(date: now, snapshot: snap)]
        if let dusk = cal.date(bySettingHour: 17, minute: 0, second: 0, of: now), dusk > now {
            entries.append(StreakEntry(date: dusk, snapshot: snap))
        }
        if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1),
                                       matchingPolicy: .nextTime) {
            entries.append(StreakEntry(date: midnight, snapshot: snap))
        }
        let refresh = cal.date(byAdding: .hour, value: 4, to: now) ?? now
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - View

struct KairoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        StreakWidgetContent(snapshot: entry.snapshot, asOf: entry.date,
                            medium: family != .systemSmall)
            .containerBackground(for: .widget) { WidgetPalette.background }
    }
}

// MARK: - Widget

struct KairoStreakWidget: Widget {
    let kind = "KairoStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            KairoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Kairō Streak")
        .description("Keep Kairo the sun shining — check in every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct KairoWidgetBundle: WidgetBundle {
    var body: some Widget { KairoStreakWidget() }
}

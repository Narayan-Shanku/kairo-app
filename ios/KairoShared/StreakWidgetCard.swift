import SwiftUI

/// The home-screen widget's foreground (mascot + streak text). Shared between the
/// WidgetKit extension and an in-app preview so both show exactly the same thing.
struct StreakWidgetContent: View {
    let snapshot: StreakSnapshot
    var asOf: Date = Date()
    var medium: Bool = false

    private var mood: SunMood { SunMood.from(snapshot, asOf: asOf) }
    private var streak: Int { snapshot.displayStreak(asOf: asOf) }

    var body: some View {
        if medium {
            HStack(spacing: 16) {
                KairoSun(mood: mood).frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline).font(.system(size: 22, weight: .bold)).foregroundStyle(WidgetPalette.text)
                    Text(caption).font(.system(size: 13)).foregroundStyle(WidgetPalette.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(spacing: 6) {
                KairoSun(mood: mood).frame(width: 64, height: 64)
                Text(headline).font(.system(size: 15, weight: .bold)).foregroundStyle(WidgetPalette.text)
                Text(caption).font(.system(size: 10)).foregroundStyle(WidgetPalette.dim)
                    .multilineTextAlignment(.center).lineLimit(2)
            }
        }
    }

    private var headline: String {
        switch mood {
        case .asleep: return "Streak asleep"
        default:      return streak == 1 ? "1-day streak" : "\(streak)-day streak"
        }
    }
    private var caption: String {
        switch mood {
        case .beaming: return "Checked in today — Kairo's beaming ☀️"
        case .content: return "Check in to keep Kairo shining"
        case .worried: return "Check in before midnight!"
        case .asleep:  return "Open Kairō to wake your streak"
        }
    }
}

enum WidgetPalette {
    static let text = Color(.sRGB, red: 0xEA/255, green: 0xF4/255, blue: 0xF2/255, opacity: 1)
    static let dim  = Color(.sRGB, red: 0x9F/255, green: 0xB8/255, blue: 0xB4/255, opacity: 1)
    static var background: LinearGradient {
        LinearGradient(colors: [Color(.sRGB, red: 0x12/255, green: 0x3A/255, blue: 0x3D/255, opacity: 1),
                                Color(.sRGB, red: 0x06/255, green: 0x18/255, blue: 0x1A/255, opacity: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// A self-contained, rounded preview of the widget (used inside the app).
struct StreakWidgetPreview: View {
    let snapshot: StreakSnapshot
    var asOf: Date = Date()
    var medium: Bool = false
    var body: some View {
        ZStack {
            WidgetPalette.background
            StreakWidgetContent(snapshot: snapshot, asOf: asOf, medium: medium).padding(12)
        }
        .frame(width: medium ? 320 : 150, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

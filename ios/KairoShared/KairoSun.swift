import SwiftUI

/// Kairo the sun's mood, derived from streak state.
enum SunMood {
    case beaming   // checked in today — bright, rays, big smile
    case content   // streak alive, not yet checked in (daytime)
    case worried   // streak alive, not checked in, evening — at risk tonight
    case asleep    // no streak / broken — a sleepy moon

    /// Derive the mood from a snapshot as of `now`.
    static func from(_ s: StreakSnapshot, asOf now: Date) -> SunMood {
        guard let last = s.lastActiveISO else { return .asleep }
        let gap = dayGap(from: last, to: SharedStore.iso(now))
        if gap <= 0 { return .beaming }          // active today
        if gap == 1 {                             // active yesterday, today still open
            let hour = Calendar.current.component(.hour, from: now)
            return hour >= 17 ? .worried : .content
        }
        return .asleep                            // 2+ days → streak lost
    }

    /// Whole-day gap between two `YYYY-MM-DD` strings (to − from).
    static func dayGap(from: String, to: String) -> Int {
        let cal = Calendar.current
        guard let a = date(from), let b = date(to) else { return 99 }
        return cal.dateComponents([.day], from: cal.startOfDay(for: a),
                                  to: cal.startOfDay(for: b)).day ?? 99
    }
    private static func date(_ iso: String) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
}

/// Kairō's mascot — the brand half-disc ◐ given a face. A coral sun that beams
/// when you're on a streak, dims and sets as you drift, and becomes a sleepy moon
/// once the streak breaks. Drawn entirely in SwiftUI so the app and the widget
/// share one source of truth.
struct KairoSun: View {
    var mood: SunMood

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(bodyTop)
                    .frame(width: bodyD(s) * 1.7, height: bodyD(s) * 1.7)
                    .opacity(mood == .asleep ? 0.10 : 0.18)
                    .blur(radius: s * 0.07)
                if mood == .worried { horizon(s) }
                rays(s)
                celestial(s)
                face(s)
                if mood == .asleep { sleepZs(s) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: Body
    private func bodyD(_ s: CGFloat) -> CGFloat { s * 0.60 }

    private var bodyTop: Color {
        switch mood {
        case .beaming, .content: return hex(0xFFC9A8)
        case .worried:           return hex(0xFFB08A)
        case .asleep:            return hex(0xCFE0E8)
        }
    }
    private var bodyBottom: Color {
        switch mood {
        case .beaming, .content: return hex(0xFF8C6B)
        case .worried:           return hex(0xE8623F)
        case .asleep:            return hex(0x9FB8B4)
        }
    }

    @ViewBuilder private func celestial(_ s: CGFloat) -> some View {
        let d = bodyD(s)
        let grad = LinearGradient(colors: [bodyTop, bodyBottom],
                                  startPoint: .top, endPoint: .bottom)
        if mood == .asleep {
            // crescent moon: carve a circle out of a circle
            ZStack {
                Circle().fill(grad)
                Circle().fill(.black).offset(x: d * 0.30, y: -d * 0.05)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: d, height: d)
        } else {
            Circle().fill(grad).frame(width: d, height: d)
        }
    }

    // MARK: Rays (beaming only; faint for content)
    @ViewBuilder private func rays(_ s: CGFloat) -> some View {
        if mood == .beaming || mood == .content {
            let d = bodyD(s)
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(bodyBottom)
                    .opacity(mood == .beaming ? 0.9 : 0.28)
                    .frame(width: s * 0.020, height: s * 0.085)
                    .offset(y: -(d * 0.5 + s * 0.085))
                    .rotationEffect(.degrees(Double(i) / 12 * 360))
            }
        }
    }

    // MARK: Horizon line for the setting (worried) sun
    private func horizon(_ s: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [.clear, hex(0xE8623F).opacity(0.55), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: s * 0.92, height: s * 0.022)
            .offset(y: bodyD(s) * 0.34)
    }

    // MARK: Face
    private func face(_ s: CGFloat) -> some View {
        let d = bodyD(s)
        let ink = mood == .asleep ? hex(0x33525A) : hex(0x3A1C12)
        return ZStack {
            eye(d, ink).offset(x: -d * 0.17, y: -d * 0.06)
            eye(d, ink).offset(x:  d * 0.17, y: -d * 0.06)
            mouth(d, ink).offset(y: d * 0.17)
        }
        .offset(x: mood == .asleep ? -d * 0.12 : 0)   // sit on the lit crescent
    }

    @ViewBuilder private func eye(_ d: CGFloat, _ ink: Color) -> some View {
        switch mood {
        case .beaming:
            Arc(up: true).stroke(ink, style: .init(lineWidth: d * 0.045, lineCap: .round))
                .frame(width: d * 0.20, height: d * 0.11)
        case .asleep:
            Arc(up: false).stroke(ink, style: .init(lineWidth: d * 0.04, lineCap: .round))
                .frame(width: d * 0.18, height: d * 0.07)
        case .content, .worried:
            Circle().fill(ink).frame(width: d * 0.095, height: d * 0.095)
        }
    }

    @ViewBuilder private func mouth(_ d: CGFloat, _ ink: Color) -> some View {
        switch mood {
        case .beaming:
            Arc(up: true).stroke(ink, style: .init(lineWidth: d * 0.05, lineCap: .round))
                .frame(width: d * 0.34, height: d * 0.20)
        case .content:
            Arc(up: true).stroke(ink, style: .init(lineWidth: d * 0.045, lineCap: .round))
                .frame(width: d * 0.22, height: d * 0.09)
        case .worried:
            Arc(up: false).stroke(ink, style: .init(lineWidth: d * 0.045, lineCap: .round))
                .frame(width: d * 0.24, height: d * 0.11)
        case .asleep:
            Circle().stroke(ink, lineWidth: d * 0.035)
                .frame(width: d * 0.10, height: d * 0.10)
        }
    }

    // MARK: Zzz
    private func sleepZs(_ s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: -s * 0.01) {
            Text("z").font(.system(size: s * 0.15, weight: .heavy))
            Text("z").font(.system(size: s * 0.10, weight: .heavy)).offset(x: s * 0.07)
        }
        .foregroundStyle(hex(0x9FB8B4))
        .offset(x: s * 0.24, y: -s * 0.26)
    }

    private func hex(_ v: UInt) -> Color {
        Color(.sRGB, red: Double((v >> 16) & 0xFF) / 255,
              green: Double((v >> 8) & 0xFF) / 255,
              blue: Double(v & 0xFF) / 255, opacity: 1)
    }
}

/// A simple smile/frown arc used for eyes and mouths.
private struct Arc: Shape {
    var up: Bool   // true = smile (opens up), false = frown/closed (opens down)
    func path(in r: CGRect) -> Path {
        var p = Path()
        let depth = r.height * (up ? 1 : -1)
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY),
                       control: CGPoint(x: r.midX, y: r.midY + depth))
        return p
    }
}

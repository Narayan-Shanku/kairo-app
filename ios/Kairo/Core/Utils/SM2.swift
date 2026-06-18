import Foundation

/// SM-2 spaced-repetition scheduler (Swift port of the backend's algorithm).
/// Ratings map to quality: again→2, hard→3, good→4, easy→5; q<3 lapses.
enum SM2 {
    static let defaultEase = 2.5
    static let minEase = 1.3

    struct State {
        var ease = defaultEase
        var intervalDays = 0.0
        var repetitions = 0
        var lapses = 0
    }

    static func schedule(_ s: State, rating: Rating) -> State {
        let q: Int = [.again: 2, .hard: 3, .good: 4, .easy: 5][rating] ?? 4
        var ease = s.ease + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        ease = max(minEase, ease)

        if q < 3 {
            return State(ease: ease, intervalDays: 1, repetitions: 0, lapses: s.lapses + 1)
        }
        let interval: Double
        switch s.repetitions {
        case 0: interval = 1
        case 1: interval = 6
        default: interval = (s.intervalDays * ease).rounded()
        }
        return State(ease: ease, intervalDays: interval,
                     repetitions: s.repetitions + 1, lapses: s.lapses)
    }
}

import Foundation

/// On-device domain tagging via keyword matching (instant, no model). Mirrors the
/// backend's 7-domain taxonomy.
struct DomainClassifier {
    static let keywords: [String: [String]] = [
        "Health": ["food", "sleep", "symptom", "medication", "energy", "pain",
                   "doctor", "bloat", "stomach", "headache", "diet", "sick"],
        "Career": ["job", "interview", "resume", "salary", "manager", "promotion",
                   "linkedin", "networking", "career", "meeting"],
        "Learning": ["study", "course", "concept", "practice", "tutorial",
                     "module", "textbook", "lab", "learn", "read"],
        "Projects": ["build", "code", "deploy", "bug", "feature", "deadline",
                     "sprint", "hackathon", "project", "ship"],
        "Fitness": ["workout", "run", "gym", "reps", "sets", "cardio", "walk",
                    "lift", "exercise", "stretch"],
        "Finance": ["budget", "savings", "investment", "expense", "income",
                    "rent", "loan", "money", "spend"],
        "Relationships": ["family", "friend", "partner", "conversation", "conflict",
                          "support", "social", "mentor", "wife", "husband"],
    ]

    func classify(_ text: String) -> [String] {
        let low = text.lowercased()
        let hits = Self.keywords.compactMap { domain, words in
            words.contains(where: { low.contains($0) }) ? domain : nil
        }
        return hits.isEmpty ? ["Learning"] : hits.sorted()
    }
}

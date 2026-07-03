import Foundation
import WidgetKit

/// On-device Proactive Engine: streak, Day-3 recall, nudges, weekly digest — all
/// computed locally, with generated text via Apple Foundation Models (template
/// fallback when unavailable).
struct LocalProactiveRepository: ProactiveRepository {
    let store: OnDeviceStore
    let memories: MemoryRepository
    let generation = GenerationService()
    let cloud = CloudGenerationService()   // used only when on-device is unavailable

    func today() async throws -> ProactiveToday {
        let mems = await store.memories
        // A "check-in day" = any day you captured a memory OR tapped Check in.
        // Convert UTC timestamps to the user's local day so evening captures in
        // behind-UTC timezones still count toward today's streak.
        let dates = Set(mems.map { StreakCalc.localDay(fromISO: $0.timestamp) })
            .union(await store.checkInDates)
        let streak = Streak(current: StreakCalc.current(dates),
                            longest: StreakCalc.longest(dates),
                            checkedInToday: dates.contains(StreakCalc.today()),
                            totalDays: dates.count)
        publish(streak, lastActive: dates.max())
        return ProactiveToday(streak: streak,
                              recall: await todaysRecall(mems),
                              nudges: nudges(mems, streak: streak))
    }

    func checkIn() async throws -> ProactiveToday {
        await store.addCheckIn(StreakCalc.today())
        return try await today()
    }

    /// Share the streak with the home-screen widget + reminders, and refresh both.
    private func publish(_ streak: Streak, lastActive: String?) {
        SharedStore.save(StreakSnapshot(current: streak.current,
                                        longest: streak.longest,
                                        checkedInToday: streak.checkedInToday,
                                        totalDays: streak.totalDays,
                                        lastActiveISO: lastActive,
                                        updatedAt: Date()))
        WidgetCenter.shared.reloadAllTimelines()
        NotificationService.recordStreak(current: streak.current, lastActiveISO: lastActive)
        NotificationService.refresh()
    }

    func respondRecall(memoryId: String, response: String) async throws {
        let r = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if !r.isEmpty { _ = try? await memories.captureText(r) }
        await store.setPref("recall_response:\(memoryId)", "answered")
    }

    func dismissRecall(memoryId: String) async throws {
        await store.setPref("recall_response:\(memoryId)", "dismissed")
    }

    func digest(refresh: Bool) async throws -> Digest {
        let now = Date()
        let weekStart = day(now.addingTimeInterval(-6 * 86400))
        let weekEnd = StreakCalc.today()
        if !refresh, let cached = await store.pref("digest:\(weekStart)"),
           let d: Digest = decode(cached) { return d }

        let recent = (await store.memories).filter { age(of: $0.timestamp) <= 7 }
        guard !recent.isEmpty else {
            return Digest(weekStart: weekStart, weekEnd: weekEnd,
                          digestText: "No memories captured this week yet — check in to build your digest.",
                          memoryCount: 0)
        }
        // On-device (Apple Foundation Models) first; cloud proxy if configured
        // (older devices); template as the final offline fallback.
        let prompt = digestPrompt(recent)
        var generated = await generation.generate(prompt)
        if generated == nil { generated = await cloud.generate(prompt) }
        let text = generated ?? templateDigest(recent)
        let d = Digest(weekStart: weekStart, weekEnd: weekEnd, digestText: text, memoryCount: recent.count)
        if let s = encode(d) { await store.setPref("digest:\(weekStart)", s) }
        return d
    }

    // MARK: - Recall

    private func todaysRecall(_ mems: [OnDeviceStore.StoredMemory]) async -> RecallCard? {
        let today = StreakCalc.today()
        if let cached = await store.pref("recall:\(today)"), let card: RecallCard = decode(cached) {
            if await store.pref("recall_response:\(card.memoryId)") != nil { return nil }
            return card
        }
        var surfaced = Set<String>()
        if let s = await store.pref("recall_surfaced"), let ids: [String] = decode(s) { surfaced = Set(ids) }

        let candidate = mems
            .filter { (2...5).contains(age(of: $0.timestamp)) && !surfaced.contains($0.chunkId) }
            .sorted { $0.text.count > $1.text.count }
            .first
        guard let chosen = candidate else { return nil }

        let card = RecallCard(memoryId: chosen.chunkId,
                              prompt: await recallPrompt(chosen.text),
                              date: DateFormat.pretty(chosen.timestamp),
                              snippet: String(chosen.text.prefix(200)),
                              domain: chosen.domains.first ?? "General")
        if let s = encode(card) { await store.setPref("recall:\(today)", s) }
        surfaced.insert(chosen.chunkId)
        if let s = encode(Array(surfaced)) { await store.setPref("recall_surfaced", s) }
        return card
    }

    private func recallPrompt(_ text: String) async -> String {
        let prompt = "A few days ago someone wrote this journal note: \"\(text.prefix(400))\". "
            + "Write ONE short, warm follow-up question (max 20 words) checking in on it. Output only the question."
        if let g = await generation.generate(prompt) {
            return g.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? g
        }
        return "A few days ago you noted: “\(text.prefix(80))…”. How did that turn out?"
    }

    // MARK: - Nudges

    private func nudges(_ mems: [OnDeviceStore.StoredMemory], streak: Streak) -> [Nudge] {
        var out: [Nudge] = []
        if !streak.checkedInToday && streak.current > 0 {
            out.append(Nudge(type: "streak",
                             message: "You haven't checked in today — keep your \(streak.current)-day streak alive.",
                             domain: nil))
        }
        var counts: [String: Int] = [:]
        for m in mems where age(of: m.timestamp) <= 14 {
            for d in m.domains { counts[d, default: 0] += 1 }
        }
        for (domain, n) in counts.sorted(by: { $0.value > $1.value }).prefix(2) where n >= 3 {
            let msg = domain == "Health"
                ? "You've logged \(n) Health notes lately — ask Kairō what patterns it sees."
                : "\(n) recent entries in \(domain) — worth reviewing for a pattern?"
            out.append(Nudge(type: "pattern", message: msg, domain: domain))
        }
        return Array(out.prefix(3))
    }

    // MARK: - Digest text

    private func digestPrompt(_ mems: [OnDeviceStore.StoredMemory]) -> String {
        var byDomain: [String: [String]] = [:]
        for m in mems { byDomain[m.domains.first ?? "General", default: []].append(m.text) }
        var ctx = ""
        // Cap each memory's contribution so a heavy week can't blow the context window.
        for (d, texts) in byDomain { ctx += "\n[\(d)]\n" + texts.map { "- \($0.prefix(400))" }.joined(separator: "\n") }
        return """
        You are Kairō writing someone's weekly reflection. Below are this week's memories by domain. \
        Write a warm, concise digest: a one-line opener, 1–2 sentences per domain, one cross-domain \
        pattern, and 1–2 open questions. Ground it ONLY in these memories.

        MEMORIES BY DOMAIN:\(ctx)
        """
    }

    private func templateDigest(_ mems: [OnDeviceStore.StoredMemory]) -> String {
        var byDomain: [String: Int] = [:]
        for m in mems { byDomain[m.domains.first ?? "General", default: 0] += 1 }
        let lines = byDomain.sorted { $0.value > $1.value }.map { domain, n in
            "• \(domain): \(n) " + (n == 1 ? "memory" : "memories")
        }
        return "Your week in review (\(mems.count) memories):\n\n" + lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func age(of iso: String) -> Int {
        guard let d = ISO8601DateFormatter().date(from: iso) else { return 999 }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 999
    }
    private func day(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    private func encode<T: Encodable>(_ v: T) -> String? {
        (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) }
    }
    private func decode<T: Decodable>(_ s: String) -> T? {
        s.data(using: .utf8).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

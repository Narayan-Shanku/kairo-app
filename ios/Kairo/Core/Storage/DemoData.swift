import Foundation

/// Seeds a realistic on-device memory set + review cards (idempotent), so a
/// first-time user sees Kairō populated. Embeddings are computed on-device.
enum DemoData {
    // (text, domains, daysAgo)
    private static let memories: [(String, [String], Int)] = [
        ("Had a rough stomach today, felt bloated after lunch. Had dal and rice again. Didn't sleep well last night — up past 1am.", ["Health"], 2),
        ("Bloated again this evening after heavy lentils for dinner, and only got five hours of sleep.", ["Health"], 9),
        ("Slept a full eight hours and skipped the lentils — felt light and clear all day. Noticing a pattern.", ["Health"], 5),
        ("Skipped breakfast before back-to-back meetings and crashed hard around 3pm.", ["Health", "Career"], 15),
        ("Realized I should frame my resume around impact metrics, not responsibilities.", ["Career"], 20),
        ("Manager 1:1 went smoothly when I led with a short written agenda. Keeping that habit.", ["Career"], 12),
        ("Finally cracked SQL window functions in the lab — PARTITION BY was the missing piece.", ["Learning"], 8),
        ("Re-read my notes on RAG re-ranking. Reciprocal Rank Fusion finally clicked.", ["Learning"], 3),
        ("Fixed the persistence bug — needed the storage path set explicitly.", ["Projects"], 6),
        ("Shipped the voice capture flow end to end. Felt great to see the first grounded answer.", ["Projects"], 1),
        ("Morning walk before work again — my afternoon focus is noticeably better on walk days.", ["Fitness", "Health"], 4),
        ("Recalculated the monthly budget after the rent increase. Cutting two subscriptions.", ["Finance"], 18),
        ("Good call with my mentor about whether to go deeper on product or stay analytics-focused.", ["Relationships", "Career"], 11),
    ]

    // (type, front, back, domain)
    private static let cards: [(String, String, String, String)] = [
        ("insight", "What's your strongest bloating trigger?", "Dal / heavy lentils within a few hours — especially on under-6-hour-sleep nights.", "Health"),
        ("insight", "What reliably improves your afternoon focus?", "A morning walk before work — you're noticeably sharper on walk days.", "Fitness"),
        ("decision", "You decided to lead every 1:1 with a written agenda. Did it hold up?", "Decision: lead 1:1s with a short written agenda.", "Career"),
        ("insight", "What was the missing piece for SQL window functions?", "PARTITION BY — that's what made window functions click.", "Learning"),
        ("decision", "You planned to cut two unused subscriptions. Did you follow through?", "Decision: trim two unused subscriptions to rebalance the budget.", "Finance"),
    ]

    @MainActor
    static func seed(into store: OnDeviceStore, embedding: EmbeddingService) {
        guard store.pref("demo_seeded") != "1" else { return }
        let now = Date()
        let iso = ISO8601DateFormatter()

        for (i, (text, domains, daysAgo)) in memories.enumerated() {
            let ts = iso.string(from: now.addingTimeInterval(Double(-daysAgo) * 86400 - 3600))
            store.addMemory(OnDeviceStore.StoredMemory(
                chunkId: UUID().uuidString, text: text, domains: domains, timestamp: ts,
                sourceType: i % 2 == 0 ? "voice" : "text", embedding: embedding.embed(text) ?? []))
        }

        let cardTs = iso.string(from: now.addingTimeInterval(-86400))
        for (type, front, back, domain) in cards {
            store.addCard(OnDeviceStore.StoredCard(
                cardId: UUID().uuidString, type: type, front: front, back: back, domain: domain,
                createdAt: cardTs, dueDate: cardTs, ease: 2.5, intervalDays: 0,
                repetitions: 0, lapses: 0, lastReviewed: nil))
        }
        store.setPref("demo_seeded", "1")
    }
}

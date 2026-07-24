// Demo data for testing — DEBUG builds only, triggered from the archive's
// debug footer (the iOS twin of the web preview's "Seed demo / Clear").
// A deterministic seeded RNG makes every run identical: roughly a year of
// writing, 4–7 sessions on written days, occasional skipped days and a few
// dry stretches so the dot matrices look lived-in. Topics recur on purpose —
// the future reflection layer needs a corpus with actual threads in it.

#if DEBUG
import Foundation
import SwiftData

/// SplitMix64 — tiny, deterministic, good enough for demo data.
private struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func int(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func chance(_ p: Double) -> Bool {
        Double(next() % 10_000) / 10_000 < p
    }

    mutating func pick<T>(_ array: [T]) -> T {
        array[int(0...(array.count - 1))]
    }
}

enum DebugSeed {

    // Sentence pools, loosely grouped so words recur across days the way a
    // real notebook's do. Content is filler; the recurrence is the point.
    private static let pools: [[String]] = [
        [ // work
            "Long day at the studio and the project is still fighting me.",
            "Shipped the draft I'd been circling for a week. Lighter already.",
            "Meetings ate the morning. The afternoon was mine and I wasted it.",
            "The project turned a corner today. Small corner, but a corner.",
            "Said no to a thing I would have said yes to a year ago.",
        ],
        [ // running / body
            "Ran the long loop before breakfast. Legs heavy, head clear.",
            "Skipped the run. Regretted it by ten.",
            "The run was terrible and I'm glad I went.",
            "New shoes, same hill. The hill is undefeated.",
            "Slept badly and felt it all day. Short fuse.",
        ],
        [ // the boat (the classic Vellum demo thread)
            "Spent an hour on the boat after dinner. The hull needs more work than I thought.",
            "Ordered the paint for the boat. Committing to the color felt bigger than it is.",
            "The boat again. I keep going back to it like a question I haven't answered.",
            "Sanded the hull until my arms gave out. Good tired.",
        ],
        [ // family / people
            "Called Mom. She told the story about the lake house again and I let her.",
            "Dinner with June. We talked about moving and didn't decide anything.",
            "The kids were loud and the house felt full in the good way.",
            "Old friend in town. Three hours felt like twenty minutes.",
        ],
        [ // noticing
            "The light on the kitchen wall at six was worth writing down. So here it is.",
            "Rain all day. The kind that makes the house feel like a boat.",
            "First cold morning. Summer left without saying anything.",
            "Nothing happened today, which is its own kind of thing to notice.",
            "Read on the porch until the light went. Didn't check my phone once.",
        ],
        [ // inner weather
            "Tired, but the honest kind of tired that comes from doing the thing.",
            "Anxious about the fall. Wrote it down to make it smaller.",
            "Caught myself hurrying for no reason. Slowed down on purpose.",
            "Grateful, mostly. Trying not to inspect it too hard.",
        ],
    ]

    private static let closers = [
        "More tomorrow.",
        "That's all for now.",
        "Worth remembering.",
        "We'll see.",
        "Enough for today.",
    ]

    /// One session's text: one line to a few paragraphs, length varied hard.
    private static func sessionText(_ rng: inout SeededRNG) -> String {
        let paragraphCount = rng.chance(0.55) ? 1 : rng.int(2...3)
        var paragraphs: [String] = []
        for _ in 0..<paragraphCount {
            let sentences = rng.int(1...4)
            var pool = pools[rng.int(0...(pools.count - 1))]
            var lines: [String] = []
            for _ in 0..<sentences {
                if pool.isEmpty { pool = pools[rng.int(0...(pools.count - 1))] }
                let i = rng.int(0...(pool.count - 1))
                lines.append(pool.remove(at: i))
            }
            paragraphs.append(lines.joined(separator: " "))
        }
        if rng.chance(0.25) { paragraphs[paragraphs.count - 1] += " " + closers[rng.int(0...(closers.count - 1))] }
        return paragraphs.joined(separator: "\n\n")
    }

    static func seed(in context: ModelContext) {
        clear(in: context)
        var rng = SeededRNG(seed: 0x5EED_0F_0E11)

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var dryStretch = 0   // occasional multi-day silences

        for back in stride(from: 365, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -back, to: today) else { continue }

            if dryStretch > 0 { dryStretch -= 1; continue }
            if rng.chance(0.03) { dryStretch = rng.int(2...6); continue }  // a quiet week now and then
            if rng.chance(0.12) { continue }                                // ordinary skipped days
            // Today itself stays unwritten — the page should greet you blank.
            if back == 0 { continue }

            // 4–7 sessions, spread through the day, always > 30 min apart so
            // they read as distinct sections.
            let sessions = rng.int(4...7)
            var minuteOfDay = rng.int(6 * 60...8 * 60)   // first session in the morning
            for _ in 0..<sessions {
                guard minuteOfDay < 23 * 60 else { break }
                let at = cal.date(byAdding: .minute, value: minuteOfDay, to: day)!
                let entry = Entry(dayKey: DayFormat.key(for: at), at: at, text: sessionText(&rng))
                context.insert(entry)
                minuteOfDay += rng.int(45...210)         // 45 min – 3.5 h between sessions
            }
        }
        try? context.save()
    }

    /// Debug-only escape hatch — the app itself has no delete path, by design.
    /// Also resets reflection + reminder state so the consent card and
    /// pre-prompt choreography can be exercised again.
    static func clear(in context: ModelContext) {
        try? context.delete(model: Entry.self)
        try? context.save()
        ReflectionStore.shared.resetAll()
        UserDefaults.standard.removeObject(forKey: AppKeys.reminder)
    }
}
#endif

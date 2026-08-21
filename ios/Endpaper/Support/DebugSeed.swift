// Demo data for testing — DEBUG and TestFlight builds, triggered from the
// archive's demo footer (the iOS twin of the web preview's "Seed demo /
// Clear"). A deterministic seeded RNG makes every run identical: roughly a
// year of writing, 4–7 sessions on written days, occasional skipped days and
// a few dry stretches so the dot matrices look lived-in. Topics recur on
// purpose — the reflection layer needs a corpus with actual threads in it.
//
// Seeded entries are tracked by id so Clear removes ONLY them — a tester's
// real writing is never touched (permanence is the product; the demo tools
// must not be a delete path for it).

import Foundation
import SwiftData

/// Which build is this? App Store builds hide the demo tools; DEBUG and
/// TestFlight (sandbox receipt) show them.
enum AppEnv {
    static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
    static var demoControls: Bool {
        #if DEBUG
        return true
        #else
        return isTestFlight
        #endif
    }
}

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

    // Sentence pools, grouped so words recur across days the way a real
    // notebook's do — the recurrence is what the reflection engine reads.
    // The threads are deliberately the ones most people carry (sleep,
    // attention, the person they live with, money) so anyone opening the
    // demo recognises their own week rather than admiring someone else's.
    private static let pools: [[String]] = [
        [ // sleep — the four a.m. thread
            "Woke at four again with my jaw already clenched. Nothing was wrong.",
            "Third night falling asleep with the phone in my hand. That isn't sleep, it's lying down with the lights off.",
            "Slept seven hours and woke up steady. One night doesn't prove anything, but I'll take it.",
            "Tired in a way that sleep doesn't fix. Naming it here so it's somewhere other than my chest.",
            "Left the phone charging in the kitchen overnight. Slept through until six.",
        ],
        [ // attention
            "Read the same paragraph four times and gave up. I used to sit with a book for an hour.",
            "Put the phone in the other room for two hours and got more done than the whole day before it.",
            "Checked my phone through most of dinner. Nobody said anything, which was worse.",
            "Focus came back for about ninety minutes this afternoon. I remember this feeling.",
            "The thing I'm avoiding takes twenty minutes. I've now spent four days not doing twenty minutes.",
        ],
        [ // Sam — the person across the table
            "Sam said I've been somewhere else all week. I wanted to argue and couldn't.",
            "Snapped at Sam about the dishes. It was never about the dishes.",
            "Sam made coffee without asking and left it by the laptop. I noticed and said nothing.",
            "Sam asked what I actually want this year and I gave an answer I've given before.",
            "Better evening with Sam. We didn't fix anything, we just stopped circling.",
        ],
        [ // money and work
            "Worried about money in a way that has nothing to do with the number in the account.",
            "Anxious all morning about a meeting that lasted nine minutes and went fine.",
            "Money is fine this month. I checked the balance four times anyway.",
            "Ran into an old coworker and performed being happy for eleven minutes. Exhausting.",
            "Said the thing in the meeting and it landed. I still replayed it the whole way home.",
        ],
        [ // noticing
            "Told my therapist I'm fine and heard how fast I said it.",
            "A quiet day, nothing to report. I notice I don't entirely trust quiet days.",
            "Walked instead of taking the bus. Those twenty minutes were the only ones that were mine.",
            "Wrote the worry down and it got about ten percent smaller. Apparently that's the trick.",
        ],
        [ // inner weather — the questions and the tone words
            "Am I anxious about the work, or about what people will decide about me because of it?",
            "Why do I keep replaying what Sam said on Sunday?",
            "When did I stop being able to read for twenty minutes?",
            "Steady today. Not happy exactly — steady. That seems worth protecting.",
            "Anxious morning, ordinary afternoon. The gap between them is where I live.",
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

    private static let seededIDsKey = "endpaper.demo.seededIDs"

    static func seed(in context: ModelContext) {
        clear(in: context)   // removes a previous demo batch only
        var seededIDs: [String] = []
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
                seededIDs.append(entry.id.uuidString)
                minuteOfDay += rng.int(45...210)         // 45 min – 3.5 h between sessions
            }
        }
        try? context.save()
        UserDefaults.standard.set(seededIDs, forKey: seededIDsKey)
    }

    /// Production safety: a TestFlight tester who seeded demo data and then
    /// moved to the App Store build would be stuck with a year of fake
    /// entries in a journal that can't delete — with the demo controls
    /// hidden. On production launches, silently remove any leftover seeded
    /// batch (entries only; reflection/reminder state is left alone).
    static func sweepProductionLeftovers(in context: ModelContext) {
        guard !AppEnv.demoControls else { return }
        let ids = Set(UserDefaults.standard.stringArray(forKey: seededIDsKey) ?? [])
        guard !ids.isEmpty else { return }
        let all = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        for entry in all where ids.contains(entry.id.uuidString) {
            context.delete(entry)
        }
        try? context.save()
        UserDefaults.standard.removeObject(forKey: seededIDsKey)
    }

    /// Removes the seeded batch — and nothing else. The app itself has no
    /// delete path, by design; real entries stay untouchable even here.
    /// Also resets reflection + reminder state so the consent card and
    /// pre-prompt choreography can be exercised again.
    static func clear(in context: ModelContext) {
        let ids = Set(UserDefaults.standard.stringArray(forKey: seededIDsKey) ?? [])
        if !ids.isEmpty {
            let all = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
            for entry in all where ids.contains(entry.id.uuidString) {
                context.delete(entry)
            }
            try? context.save()
        }
        UserDefaults.standard.removeObject(forKey: seededIDsKey)
        ReflectionStore.shared.resetAll()
        UserDefaults.standard.removeObject(forKey: AppKeys.reminder)
    }
}

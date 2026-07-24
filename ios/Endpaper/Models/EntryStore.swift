// Endpaper — the append-only store, ported from js/store.js.
// A pause under 30 minutes continues the same timestamped section; a longer
// gap starts a new one. There is no update or delete API on purpose.

import Foundation
import SwiftData

enum EntryStore {

    static let sessionGap: TimeInterval = 30 * 60

    /// Commit a piece of writing. Merges into the day's last session when the
    /// gap is under 30 minutes, exactly like the prototype.
    @discardableResult
    static func commit(_ text: String, at: Date = .now, in context: ModelContext) -> Entry {
        let key = DayFormat.key(for: at)
        let day = entries(forDay: key, in: context)

        if let last = day.last, at.timeIntervalSince(last.lastAt) < sessionGap {
            last.text += "\n\n" + text
            last.lastAt = at
            try? context.save()
            return last
        }

        let entry = Entry(dayKey: key, at: at, text: text)
        context.insert(entry)
        try? context.save()
        return entry
    }

    static func entries(forDay key: String, in context: ModelContext) -> [Entry] {
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { $0.dayKey == key },
            sortBy: [SortDescriptor(\.at)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// All day keys that have entries, newest first.
    static func daysWithEntries(in context: ModelContext) -> [String] {
        let all = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        return Set(all.map(\.dayKey)).sorted(by: >)
    }

    static func hasEntries(forDay key: String, in context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Distinct written days — the reminder pre-prompt's ≥2-days trigger.
    static func distinctDayCount(in context: ModelContext) -> Int {
        daysWithEntries(in: context).count
    }
}

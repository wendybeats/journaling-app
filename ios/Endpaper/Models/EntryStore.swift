// Endpaper — the append-only store, ported from js/store.js.
// A pause under 30 minutes continues the same timestamped section; a longer
// gap starts a new one.
//
// The permanence boundary is the day: while a day is still today, its
// sections may be revised (text and, through the line classifier, format).
// At midnight the day archives and becomes permanent. There is no delete
// API anywhere, ever.

import Foundation
import SwiftData

enum EntryStore {

    static let sessionGap: TimeInterval = 30 * 60

    /// Commit a piece of writing. Merges into the day's last session when the
    /// gap is under 30 minutes, exactly like the prototype. Captured sections
    /// (spoken / scanned / imported) stand alone: they never merge into a
    /// typed session and typed writing never merges into them — each arrival
    /// is its own block on the page.
    /// `at` is when the writing STARTED (the draft's first keystroke), not
    /// when it committed — the page sorts by `at`, and a voice note taken
    /// mid-draft must land after the words that were already in progress
    /// (QA 2026-08-20: the idle-commit delay put spoken sections above
    /// older typed ones). `lastAt` is when the writing ended.
    @discardableResult
    static func commit(_ text: String, at: Date = .now, lastAt: Date? = nil,
                       origin: String = "", in context: ModelContext) -> Entry {
        let key = DayFormat.key(for: at)
        let day = entries(forDay: key, in: context)

        if origin.isEmpty,
           let last = day.last, last.origin.isEmpty,
           at.timeIntervalSince(last.lastAt) < sessionGap {
            last.text += "\n\n" + text
            last.lastAt = lastAt ?? at
            try? context.save()
            return last
        }

        let entry = Entry(dayKey: key, at: at, text: text, origin: origin)
        entry.lastAt = lastAt ?? at
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// Editable while its day is still today; permanent after midnight.
    static func isEditable(_ entry: Entry, now: Date = .now) -> Bool {
        entry.dayKey == DayFormat.key(for: now)
    }

    /// Same-day revision — the only mutation besides the session append.
    /// Guarded here, not just in the UI, so no surface can edit the past.
    /// `lastAt` is left alone: revising at 11 PM must not pull a morning
    /// section into the evening's session-merge window.
    static func revise(_ entry: Entry, to text: String, in context: ModelContext) {
        guard isEditable(entry) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        entry.text = trimmed
        try? context.save()
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

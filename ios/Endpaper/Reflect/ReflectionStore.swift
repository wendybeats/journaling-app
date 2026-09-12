// Reflection state — consent, seen, archived — persisted as one Codable
// blob under the same key the web prototype uses (endpaper.reflection.v1),
// plus the pending/eligibility logic from js/reflect.js and the corpus
// bridge from SwiftData.

import Foundation
import SwiftData

/// An archived reflection: the whole signal persists, so reopening an old
/// card never recomputes (and never re-rolls) it.
enum ArchivedReflection: Codable {
    case weekly(WeeklySignal)
    case monthly(MonthlySignal)

    var id: String {
        switch self {
        case .weekly(let s): return s.id
        case .monthly(let s): return s.id
        }
    }

    /// The date the card rests at in the Notebook: the period's last day.
    func boundaryKey(calendar: Calendar = .current) -> String {
        switch self {
        case .weekly(let s):
            let start = DayFormat.date(fromKey: s.startKey)
            return DayFormat.key(for: calendar.date(byAdding: .day, value: 6, to: start)!)
        case .monthly(let s):
            let first = calendar.date(from: DateComponents(year: s.year, month: s.month, day: 1))!
            let count = calendar.range(of: .day, in: .month, for: first)!.count
            return String(format: "%04d-%02d-%02d", s.year, s.month, count)
        }
    }
}

final class ReflectionStore {
    static let shared = ReflectionStore()

    private struct State: Codable {
        var consent: String? = nil          // "yes" | "no" | nil (never asked)
        var seen: [String: Bool] = [:]
        var archived: [String: ArchivedReflection] = [:]
        var deferred: [String: String]? = nil   // reflection id → day key it was put off (optional: older state decodes)
    }

    private var state: State
    private let key = AppKeys.reflection

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(State.self, from: data) {
            state = decoded
        } else {
            state = State()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: Consent

    var consent: String? { state.consent }

    func setConsent(_ value: String) {
        state.consent = value
        persist()
    }

    // MARK: Corpus bridge

    static func corpus(from context: ModelContext) -> Corpus {
        let all = (try? context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.at)]))) ?? []
        var byDay: [String: [String]] = [:]
        var sessions: [String: [RSession]] = [:]
        for entry in all {
            byDay[entry.dayKey, default: []].append(entry.text)
            sessions[entry.dayKey, default: []].append(
                RSession(text: entry.text, at: entry.at, lastAt: entry.lastAt, origin: entry.origin))
        }
        return Corpus(byDay: byDay, sessions: sessions)
    }

    // MARK: Pending arrivals (one per visit; monthly wins — reflection.js)

    /// The consent moment appears as soon as there is any writing at all —
    /// early enough that the user knows what's coming at the end of the
    /// week, not a surprise after one. (Beta feedback July 2026; the web
    /// prototype waited for a sufficient week.)
    func consentEligible(corpus: Corpus, now: Date = .now) -> Bool {
        guard state.consent == nil else { return false }
        return !corpus.byDay.isEmpty
    }

    /// The weekly reflection waiting to be shown, or nil (no consent /
    /// already seen / insufficient week — silence). Install-anchored
    /// (QA 2026-09-11): the week is the reader's own seven days, and until
    /// a first weekly has been read the bar is lowered to two written
    /// days and 150 words so day 7 has something to hand back.
    func pendingWeekly(corpus: Corpus, now: Date = .now) -> WeeklySignal? {
        guard state.consent == "yes",
              let start = ReflectionCadence.lastCompletedWeekStart(now: now) else { return nil }
        var signal = Reflect.weeklySignal(start: start, corpus: corpus)
        guard state.seen[signal.id] != true else { return nil }
        if !signal.sufficient, !weeklySeenEver, Self.thinBar(signal) { signal.sufficient = true }
        guard signal.sufficient else { return nil }
        return signal
    }

    /// Has any weekly ever been read on this device?
    var weeklySeenEver: Bool {
        state.archived.values.contains { if case .weekly = $0 { return true } else { return false } }
    }

    private static func thinBar(_ s: WeeklySignal) -> Bool { s.days >= 2 && s.words >= 150 }

    /// Day 7 with nothing to hand back: the first week missed even the
    /// lowered bar. Returns the date the first reflection moves to; shown
    /// once per week boundary (dismissing marks it seen).
    func pendingThinWeek(corpus: Corpus, now: Date = .now) -> Date? {
        guard state.consent == "yes", !weeklySeenEver,
              let start = ReflectionCadence.lastCompletedWeekStart(now: now) else { return nil }
        guard state.seen[Self.thinID(start)] != true else { return nil }
        let signal = Reflect.weeklySignal(start: start, corpus: corpus)
        guard !signal.sufficient, !Self.thinBar(signal) else { return nil }
        return ReflectionCadence.followingReflectionDate(now: now)
    }

    func markThinSeen(now: Date = .now) {
        guard let start = ReflectionCadence.lastCompletedWeekStart(now: now) else { return }
        state.seen[Self.thinID(start)] = true
        persist()
    }

    private static func thinID(_ start: Date) -> String { "thin-" + DayFormat.key(for: start) }

    /// The previous month's recap, or nil (no consent / already seen /
    /// a month with no writing at all stays silent).
    func pendingMonthly(corpus: Corpus, now: Date = .now, calendar: Calendar = .current) -> MonthlySignal? {
        guard state.consent == "yes" else { return nil }
        let prev = calendar.date(byAdding: .month, value: -1, to: now)!
        let c = calendar.dateComponents([.year, .month], from: prev)
        let signal = Reflect.monthlySignal(year: c.year!, month: c.month!, corpus: corpus)
        guard state.seen[signal.id] != true, signal.days > 0 else { return nil }
        guard state.deferred?[signal.id] != DayFormat.key(for: now) else { return nil }
        return signal
    }

    /// "Later" on a recap: out of the slot for the rest of today.
    func deferMonthly(id: String, now: Date = .now) {
        var d = state.deferred ?? [:]
        d[id] = DayFormat.key(for: now)
        state.deferred = d
        persist()
    }

    // MARK: Archive

    func markSeen(_ reflection: ArchivedReflection) {
        state.seen[reflection.id] = true
        state.archived[reflection.id] = reflection
        persist()
    }

    func removeReflection(id: String) {
        state.archived.removeValue(forKey: id)
        persist()
    }

    /// Archived reflections, newest boundary first.
    func archived() -> [ArchivedReflection] {
        state.archived.values.sorted { $0.boundaryKey() > $1.boundaryKey() }
    }

    /// Wipes consent/seen/archived state. Reached only from the demo tools
    /// (DEBUG + TestFlight builds); App Store builds surface no path to it.
    func resetAll() {
        state = State()
        persist()
    }
}

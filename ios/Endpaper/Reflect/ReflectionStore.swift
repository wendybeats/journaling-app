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

    // MARK: Reflections on/off (rev. 2026-09-12: ON by default — no consent
    // card; Settings turns them off, and "no" is remembered)

    var consent: String? { state.consent }
    var reflectionsOn: Bool { state.consent != "no" }

    func setConsent(_ value: String) {
        state.consent = value
        persist()
    }

    // MARK: Corpus bridge

    /// The corpus is cached between commits (perf 2026-09-12: Today was
    /// fetching the whole notebook five times per appearance — five
    /// seconds on a year of iCloud entries). A cheap row count catches
    /// entries that arrive from iCloud in the background; local writes
    /// and edits call `invalidateCorpus()`; a short TTL covers the rest.
    private static var cached: (count: Int, at: Date, corpus: Corpus)? = nil

    static func invalidateCorpus() { cached = nil }

    static func corpus(from context: ModelContext) -> Corpus {
        let count = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? -1
        if let c = cached, c.count == count, count >= 0, Date().timeIntervalSince(c.at) < 120 {
            return c.corpus
        }
        let built = build(from: context)
        cached = (count, Date(), built)
        return built
    }

    private static func build(from context: ModelContext) -> Corpus {
        let all = (try? context.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.at)]))) ?? []
        var byDay: [String: [String]] = [:]
        var sessions: [String: [RSession]] = [:]
        for entry in all {
            byDay[entry.dayKey, default: []].append(entry.text)
            sessions[entry.dayKey, default: []].append(
                RSession(text: entry.text, at: entry.at, lastAt: entry.lastAt, origin: entry.origin))
        }
        var c = Corpus(byDay: byDay, sessions: sessions)
        c.token = "\(all.count)-\(Int(Date().timeIntervalSince1970))"
        return c
    }

    // MARK: Signals — computed once per corpus, off the main thread

    /// Everything the page might need, computed in one pass over a
    /// corpus snapshot (perf 2026-09-13: the previous month's recap was
    /// being recomputed on the main thread on every Today appearance).
    /// Pure — safe to run detached; ReflectionFlow caches the result by
    /// corpus token + day.
    struct Signals {
        var monthly: MonthlySignal?      // the previous calendar month
        var lastWeek: WeeklySignal?      // the last completed anchored week (nil before day 7)
        var currentWeek: WeeklySignal    // the week being written (gates the notes)
        var lastYear: YearlySignal?      // January only
    }

    static func computeSignals(corpus: Corpus, now: Date = .now, calendar: Calendar = .current) -> Signals {
        let prev = calendar.date(byAdding: .month, value: -1, to: now)!
        let c = calendar.dateComponents([.year, .month], from: prev)
        let monthly = Reflect.monthlySignal(year: c.year!, month: c.month!, corpus: corpus)
        let lastWeek = ReflectionCadence.lastCompletedWeekStart(now: now, calendar: calendar)
            .map { Reflect.weeklySignal(start: $0, corpus: corpus, calendar: calendar) }
        let currentWeek = Reflect.weeklySignal(start: ReflectionCadence.currentWeekStart(now: now, calendar: calendar),
                                               corpus: corpus, calendar: calendar)
        var lastYear: YearlySignal? = nil
        if calendar.component(.month, from: now) == 1 {
            let y = Reflect.yearlySignal(year: calendar.component(.year, from: now) - 1, corpus: corpus)
            if y.days > 0 { lastYear = y }
        }
        return Signals(monthly: monthly.days > 0 ? monthly : nil, lastWeek: lastWeek,
                       currentWeek: currentWeek, lastYear: lastYear)
    }

    // MARK: Pending arrivals — cheap guards over precomputed signals

    private static func thinBar(_ s: WeeklySignal) -> Bool { s.days >= 2 && s.words >= 150 }

    /// The weekly reflection waiting to be shown, or nil (reflections off /
    /// already seen / insufficient week — silence). Until a first weekly
    /// has been read the bar is lowered to two written days and 150 words
    /// so day 7 has something to hand back.
    func pendingWeekly(from signals: Signals) -> WeeklySignal? {
        guard reflectionsOn, var signal = signals.lastWeek else { return nil }
        guard state.seen[signal.id] != true else { return nil }
        if !signal.sufficient, !weeklySeenEver, Self.thinBar(signal) { signal.sufficient = true }
        guard signal.sufficient else { return nil }
        return signal
    }

    /// Has any weekly ever been read on this device?
    var weeklySeenEver: Bool {
        state.archived.values.contains { if case .weekly = $0 { return true } else { return false } }
    }

    /// Day 7 with nothing to hand back: the first week missed even the
    /// lowered bar. Returns the date the first reflection moves to; shown
    /// once per week boundary (dismissing marks it seen).
    func pendingThinWeek(from signals: Signals, now: Date = .now) -> Date? {
        guard reflectionsOn, !weeklySeenEver, let signal = signals.lastWeek else { return nil }
        guard state.seen[Self.thinID(signal.startKey)] != true else { return nil }
        guard !signal.sufficient, !Self.thinBar(signal) else { return nil }
        return ReflectionCadence.followingReflectionDate(now: now)
    }

    func markThinSeen(now: Date = .now) {
        guard let start = ReflectionCadence.lastCompletedWeekStart(now: now) else { return }
        state.seen[Self.thinID(DayFormat.key(for: start))] = true
        persist()
    }

    private static func thinID(_ startKey: String) -> String { "thin-" + startKey }

    /// The previous month's recap, or nil (reflections off / already seen /
    /// deferred today / a month with no writing at all stays silent).
    func pendingMonthly(from signals: Signals, now: Date = .now) -> MonthlySignal? {
        guard reflectionsOn, let signal = signals.monthly else { return nil }
        guard state.seen[signal.id] != true else { return nil }
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

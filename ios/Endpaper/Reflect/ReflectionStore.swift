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
    /// already seen / insufficient week — silence).
    func pendingWeekly(corpus: Corpus, now: Date = .now) -> WeeklySignal? {
        guard state.consent == "yes" else { return nil }
        let signal = Reflect.weeklySignal(start: Reflect.lastCompletedWeekStart(now: now), corpus: corpus)
        guard state.seen[signal.id] != true, signal.sufficient else { return nil }
        return signal
    }

    /// The previous month's recap, or nil (no consent / already seen /
    /// a month with no writing at all stays silent).
    func pendingMonthly(corpus: Corpus, now: Date = .now, calendar: Calendar = .current) -> MonthlySignal? {
        guard state.consent == "yes" else { return nil }
        let prev = calendar.date(byAdding: .month, value: -1, to: now)!
        let c = calendar.dateComponents([.year, .month], from: prev)
        let signal = Reflect.monthlySignal(year: c.year!, month: c.month!, corpus: corpus)
        guard state.seen[signal.id] != true, signal.days > 0 else { return nil }
        return signal
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

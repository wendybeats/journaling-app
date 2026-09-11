// The reflection week is anchored on the reader's first day, not the
// calendar (QA 2026-09-11): days 0–6 are the seven ghost prompts, day 7
// is the first reflection over days 0–6, then every seven days on that
// same weekday — the new-user week is the same whatever day they start.
// Nothing here touches the engine: Reflect.swift stays parity-pure and
// its Sunday helpers remain for the JS suite.

import Foundation

enum ReflectionCadence {
    /// The first day — stamped by RootView on first-ever open. Before the
    /// stamp exists (never for a running app) today is the anchor.
    static func anchor(now: Date = .now, calendar: Calendar = .current) -> Date {
        if let key = UserDefaults.standard.string(forKey: AppKeys.firstDay) {
            return calendar.startOfDay(for: DayFormat.date(fromKey: key))
        }
        return calendar.startOfDay(for: now)
    }

    static func daysSinceAnchor(now: Date = .now, calendar: Calendar = .current) -> Int {
        let a = anchor(now: now, calendar: calendar)
        let d = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: a, to: d).day ?? 0)
    }

    /// 7 on day 0, counting down to 0 on every seventh day.
    static func daysUntilReflection(now: Date = .now, calendar: Calendar = .current) -> Int {
        let d = daysSinceAnchor(now: now, calendar: calendar)
        if d == 0 { return 7 }
        return (7 - d % 7) % 7
    }

    /// The start of the week now being written (anchor + 7k).
    static func currentWeekStart(now: Date = .now, calendar: Calendar = .current) -> Date {
        let d = daysSinceAnchor(now: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: (d / 7) * 7, to: anchor(now: now, calendar: calendar))!
    }

    /// The start of the most recent completed seven-day week — nil before
    /// day 7, when no week has completed yet.
    static func lastCompletedWeekStart(now: Date = .now, calendar: Calendar = .current) -> Date? {
        let d = daysSinceAnchor(now: now, calendar: calendar)
        guard d >= 7 else { return nil }
        return calendar.date(byAdding: .day, value: (d / 7 - 1) * 7, to: anchor(now: now, calendar: calendar))
    }

    /// The reflection after the one due now (or the next one, when none is
    /// due today) — where a thin first week moves to.
    static func followingReflectionDate(now: Date = .now, calendar: Calendar = .current) -> Date {
        let until = daysUntilReflection(now: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: until == 0 ? 7 : until, to: calendar.startOfDay(for: now))!
    }

    /// Weekday (1 = Sunday) reflections arrive on — the anchor's weekday.
    static func reflectionWeekday(calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: anchor(calendar: calendar))
    }
}

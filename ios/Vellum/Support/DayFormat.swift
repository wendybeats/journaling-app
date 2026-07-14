// Date and metadata formatting — everything the mono register displays.
// Ported from js/format.js; day keys stay "YYYY-MM-DD" in local time so the
// corpus shape matches the web prototype byte for byte.

import Foundation

enum DayFormat {

    /// Local-timezone day key, e.g. "2026-07-05".
    static func key(for date: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func date(fromKey key: String, calendar: Calendar = .current) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .now }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? .now
    }

    private static let months = ["January", "February", "March", "April", "May", "June",
                                 "July", "August", "September", "October", "November", "December"]
    private static let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// "Tuesday" — bare weekday, used for quote stamps.
    static func weekdayName(_ date: Date, calendar: Calendar = .current) -> String {
        days[calendar.component(.weekday, from: date) - 1]
    }

    /// "Saturday, July 5" — the editorial day heading.
    static func dayHeading(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.weekday, .month, .day], from: date)
        return "\(days[c.weekday! - 1]), \(months[c.month! - 1]) \(c.day!)"
    }

    /// "July 5, 2026" (the mono register applies the uppercase).
    static func dayMetaDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(months[c.month! - 1]) \(c.day!), \(c.year!)"
    }

    /// "9:41 AM"
    static func timeOfDay(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let mer = c.hour! >= 12 ? "PM" : "AM"
        var h = c.hour! % 12
        if h == 0 { h = 12 }
        return String(format: "%d:%02d %@", h, c.minute!, mer)
    }

    /// "July 5, 2026 · 3 entries · 4 min" — reading time only where asked for
    /// (Today keeps it; archive meta rows drop it).
    static func dayMetaRow(_ date: Date, entries: [Entry], withMin: Bool = true) -> String {
        var parts = [dayMetaDate(date)]
        if !entries.isEmpty {
            parts.append("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
            if withMin {
                let words = entries.reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
                parts.append("\(max(1, Int((Double(words) / 200).rounded()))) min")
            }
        }
        return parts.joined(separator: " · ")
    }

    /// "June 29 – July 5"
    static func weekRangeLabel(start: Date, end: Date, calendar: Calendar = .current) -> String {
        func one(_ d: Date) -> String {
            let c = calendar.dateComponents([.month, .day], from: d)
            return "\(months[c.month! - 1]) \(c.day!)"
        }
        return "\(one(start)) – \(one(end))"
    }

    static func monthName(_ m: Int) -> String { months[m - 1] }
    static func monthAbbr(_ m: Int) -> String { String(months[m - 1].prefix(3)) }
}

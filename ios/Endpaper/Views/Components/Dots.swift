// Endpaper — dots, the signature. Filled = a day written; the ringed dot is
// today. Sizes come straight from the token sheet: 7 base / 11 today,
// 5 year register, 36/44 week register. Dots are for writing — nothing else
// ever earns one.

import SwiftUI

/// One dot in the base register.
struct VDot: View {
    var filled: Bool
    var isToday = false

    var body: some View {
        let size = isToday ? Tokens.DotSize.today : Tokens.DotSize.base
        Circle()
            .fill(filled ? Tokens.Dot.filled : Tokens.Dot.empty)
            .frame(width: size, height: size)
            .overlay {
                if isToday {
                    Circle()
                        .strokeBorder(Tokens.Dot.today, lineWidth: Tokens.DotSize.todayRing)
                        .padding(-(Tokens.DotSize.todayRing + Tokens.DotSize.todayRingOffset))
                }
            }
    }
}

/// A month of days as the 7-column dot grid (the tutorial's demo moment and
/// the calendar's month register).
struct MonthDotGrid: View {
    var year: Int
    var month: Int
    var writtenDays: Set<Int>        // day-of-month numbers with entries
    var todayDay: Int? = nil
    var onTapDay: ((Int) -> Void)? = nil

    private var dayCount: Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(Tokens.DotSize.today), spacing: Tokens.DotSize.gap),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: Tokens.DotSize.gap) {
            ForEach(1...dayCount, id: \.self) { day in
                VDot(filled: writtenDays.contains(day), isToday: day == todayDay)
                    .frame(width: Tokens.DotSize.today, height: Tokens.DotSize.today)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapDay?(day) }
                    .accessibilityLabel(dayLabel(day))
                    .accessibilityAddTraits(writtenDays.contains(day) ? .isButton : [])
            }
        }
    }

    /// Dots need spoken meaning: "July 5, written" / "July 6".
    private func dayLabel(_ day: Int) -> String {
        var label = "\(DayFormat.monthName(month)) \(day)"
        if day == todayDay { label += ", today" }
        if writtenDays.contains(day) { label += ", written" }
        return label
    }
}

/// The year register: a month as a compact 5px matrix (used twelve-up).
struct YearMonthMatrix: View {
    var year: Int
    var month: Int
    var writtenDays: Set<Int>

    private var dayCount: Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(.fixed(Tokens.DotSize.year), spacing: Tokens.DotSize.gapYear),
            count: Tokens.DotSize.gridCols
        )
        LazyVGrid(columns: columns, spacing: Tokens.DotSize.gapYear) {
            ForEach(1...dayCount, id: \.self) { day in
                Circle()
                    .fill(writtenDays.contains(day) ? Tokens.Dot.filled : Tokens.Dot.empty)
                    .frame(width: Tokens.DotSize.year, height: Tokens.DotSize.year)
            }
        }
        // 365 tiny dots would drown VoiceOver — the enclosing view carries
        // one meaningful label instead.
        .accessibilityHidden(true)
    }
}

/// One day in the week register.
struct WeekDay: Identifiable {
    let date: Date
    let written: Bool
    let isToday: Bool
    var id: Date { date }
}

/// The week register: seven large tappable dots, today enlarged.
struct WeekDotRow: View {
    var days: [WeekDay]
    var onTap: (Date) -> Void

    var body: some View {
        HStack(spacing: Tokens.DotSize.gapWeek) {
            ForEach(days) { day in
                let size = day.isToday ? Tokens.DotSize.weekToday : Tokens.DotSize.week
                Circle()
                    .fill(day.written ? Tokens.Dot.filled : Tokens.Dot.empty)
                    .frame(width: size, height: size)
                    .onTapGesture { if day.written { onTap(day.date) } }
                    .accessibilityLabel(DayFormat.dayHeading(day.date)
                        + (day.written ? ", written" : "")
                        + (day.isToday ? ", today" : ""))
                    .accessibilityAddTraits(day.written ? .isButton : [])
            }
        }
    }
}

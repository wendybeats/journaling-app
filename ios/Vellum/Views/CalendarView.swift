// Calendar — one morphing experience: year matrices → the tapped year's
// twelve months → a month's weekly breakdown (one expanded at a time, the
// large 36/44 dot register) → a day's page. The web prototype moves dots
// physically between layouts with FLIP; here matchedGeometryEffect is the
// native equivalent, applied to the month grids.

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Namespace private var morph

    // written day numbers per "YYYY-MM"
    @State private var writtenByMonth: [String: Set<Int>] = [:]
    @State private var years: [Int] = []
    @State private var openMonth: (year: Int, month: Int)? = nil
    @State private var expandedWeek: Int? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                if let open = openMonth {
                    monthDetail(year: open.year, month: open.month)
                } else {
                    ForEach(years, id: \.self) { year in
                        yearSection(year)
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Surface.page)
        .navigationDestination(item: $navigateDay) { key in
            DayPageView(key: key)
        }
        .onAppear(perform: load)
    }

    // MARK: - Year register (twelve compact matrices)

    private func yearSection(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text(String(year)).typeMeta()

            let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.md, alignment: .topLeading), count: 3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Space.lg) {
                ForEach(1...12, id: \.self) { month in
                    let written = writtenByMonth["\(monthKey(year, month))"] ?? []
                    VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                        YearMonthMatrix(year: year, month: month, writtenDays: written)
                            .matchedGeometryEffect(id: monthKey(year, month), in: morph)
                        Text(DayFormat.monthAbbr(month)).typeMetaSmall()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !written.isEmpty || isCurrentMonth(year, month) else { return }
                        withAnimation(Tokens.Motion.base) { openMonth = (year, month) }
                    }
                }
            }
        }
    }

    // MARK: - Month detail (weeks, the large dot register)

    private func monthDetail(year: Int, month: Int) -> some View {
        let written = writtenByMonth[monthKey(year, month)] ?? []
        let weeks = weeksOf(year: year, month: month)

        return VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            Button {
                withAnimation(Tokens.Motion.base) { openMonth = nil; expandedWeek = nil }
            } label: {
                Text("← \(year)").typeMeta()
            }

            Text("\(DayFormat.monthName(month)) \(String(year))")
                .typeTitle()

            MonthDotGrid(
                year: year, month: month,
                writtenDays: written,
                todayDay: todayDay(year, month)
            )
            .matchedGeometryEffect(id: monthKey(year, month), in: morph)

            VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    weekRow(index: index, week: week, written: written, year: year, month: month)
                }
            }
            .padding(.top, Tokens.Space.md)
        }
    }

    private func weekRow(index: Int, week: [Date], written: Set<Int>, year: Int, month: Int) -> some View {
        let cal = Calendar.current
        let expanded = expandedWeek == index

        return VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Button {
                // One expanded at a time — opening a week closes the others.
                withAnimation(Tokens.Motion.base) { expandedWeek = expanded ? nil : index }
            } label: {
                Text(DayFormat.weekRangeLabel(start: week.first!, end: week.last!))
                    .typeMetaSmall()
            }
            if expanded {
                WeekDotRow(
                    days: week.map { date in
                        let day = cal.component(.day, from: date)
                        let inMonth = cal.component(.month, from: date) == month
                        return WeekDay(
                            date: date,
                            written: inMonth && written.contains(day),
                            isToday: DayFormat.key(for: date) == DayFormat.key()
                        )
                    },
                    onTap: { date in navigateDay = DayFormat.key(for: date) }
                )
                .transition(.opacity)
            }
        }
    }

    @State private var navigateDay: String? = nil

    // MARK: - Data

    private func load() {
        var byMonth: [String: Set<Int>] = [:]
        var yearSet = Set<Int>()
        for key in EntryStore.daysWithEntries(in: context) {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            byMonth[monthKey(parts[0], parts[1]), default: []].insert(parts[2])
            yearSet.insert(parts[0])
        }
        yearSet.insert(Calendar.current.component(.year, from: .now))
        writtenByMonth = byMonth
        years = yearSet.sorted(by: >)
    }

    private func monthKey(_ year: Int, _ month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }

    private func isCurrentMonth(_ year: Int, _ month: Int) -> Bool {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return c.year == year && c.month == month
    }

    private func todayDay(_ year: Int, _ month: Int) -> Int? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return (c.year == year && c.month == month) ? c.day : nil
    }

    /// The month's days grouped into Sunday-start weeks (weeks may spill
    /// across month edges; spill days render but never fill).
    private func weeksOf(year: Int, month: Int) -> [[Date]] {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let dayCount = cal.range(of: .day, in: .month, for: first)!.count

        var weeks: [[Date]] = []
        var cursor = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: first))!
        let monthEnd = cal.date(byAdding: .day, value: dayCount - 1, to: first)!
        while cursor <= monthEnd {
            let week = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: cursor) }
            weeks.append(week)
            cursor = cal.date(byAdding: .day, value: 7, to: cursor)!
        }
        return weeks
    }
}

/// A past day, read-only — the page as it was.
struct DayPageView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let key: String

    var body: some View {
        let date = DayFormat.date(fromKey: key)
        let entries = EntryStore.entries(forDay: key, in: context)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("← Back").typeMeta()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.top, Tokens.Space.sm)

                Text(DayFormat.dayHeading(date))
                    .typeDisplay()
                    .padding(.top, Tokens.Space.xl)
                Text(DayFormat.dayMetaRow(date, entries: entries, withMin: false))
                    .typeMeta()
                    .padding(.top, Tokens.Space.sm)
                Rectangle()
                    .fill(Tokens.Line.rule)
                    .frame(height: Tokens.lineWeight)
                    .padding(.top, Tokens.Space.md)

                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    ForEach(entries, id: \.id) { entry in
                        EntrySection(entry: entry)
                    }
                }
                .padding(.top, Tokens.Space.lg)
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Tokens.Surface.page)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

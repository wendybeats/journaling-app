// Calendar — dynamic by how much has been written (July 27 gameplan):
//   < 1 month of entries  → one big month calendar, nothing else
//   more months           → the year breakdown (twelve mini matrices)
//   a year or more        → year sections stack (months over days)
//
// The morph (July 28): every day-dot is its own matchedGeometryEffect pair,
// so tapping a month sends each dot flying from its mini-matrix position to
// its month-grid position while growing 5 → 34 px. A deterministic per-dot
// delay staggers the flight — dots pulled magnetically, not moved as one
// block. The month register is a scrollable list of the year's months,
// landing on the tapped month with its neighbors above and below.

import SwiftUI
import SwiftData

private struct MonthRef: Hashable {
    let year: Int
    let month: Int
    var key: String { String(format: "%04d-%02d", year, month) }
}

// MARK: - The shared dot (both registers match on "yyyy-MM-d")

private struct CalDot: View {
    let ref: MonthRef
    let day: Int
    let size: CGFloat
    let written: Bool
    let isToday: Bool
    let count: Int          // shown faintly on the big register only
    let ns: Namespace.ID

    var body: some View {
        ZStack {
            Circle()
                .fill(written ? Tokens.Dot.filled : Tokens.Dot.empty)
                .overlay {
                    if isToday && size > 20 {
                        Circle()
                            .strokeBorder(Tokens.Dot.today, lineWidth: Tokens.DotSize.todayRing)
                            .padding(-(Tokens.DotSize.todayRing + Tokens.DotSize.todayRingOffset))
                    }
                }
            if written && count > 0 && size > 20 {
                Text("\(count)")
                    .font(.custom(EndpaperFont.meta, size: 9))
                    .foregroundStyle(Tokens.Text.onInverted.opacity(0.75))
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .matchedGeometryEffect(id: "\(ref.key)-\(day)", in: ns)
        // The magnetic stagger: each dot keeps the house curve but departs
        // a beat apart, deterministically per day.
        .transaction { t in
            if t.animation != nil {
                t.animation = Tokens.Motion.base.delay(Double((day * 131 + ref.month * 17) % 89) / 89.0 * 0.12)
            }
        }
    }
}

// MARK: - The calendar

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Namespace private var morph

    // "yyyy-MM" → day-of-month → entry count
    @State private var monthCounts: [String: [Int: Int]] = [:]
    @State private var years: [Int] = []
    @State private var anchor: MonthRef? = nil       // nil = year register
    @State private var singleMonthRoot = false
    @State private var scrolledMonth: String? = nil
    @State private var navigateDay: String? = nil
    @State private var wrappedSignal: YearlySignal? = nil

    var body: some View {
        ScrollView {
            Group {
                if let a = anchor {
                    monthsList(year: a.year)
                        .transition(.opacity)
                } else {
                    yearsList
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Tokens.Space.screenX)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollPosition(id: $scrolledMonth, anchor: .top)
        .background(Tokens.Surface.page)
        .navigationDestination(item: $navigateDay) { key in
            DayPageView(key: key)
        }
        .fullScreenCover(item: $wrappedSignal) { signal in
            WrappedView(signal: signal) { wrappedSignal = nil }
        }
        .onAppear(perform: load)
    }

    private func open(_ ref: MonthRef) {
        scrolledMonth = ref.key                      // land the list on the tapped month
        withAnimation(Tokens.Motion.base) { anchor = ref }
    }

    private func close() {
        scrolledMonth = nil
        withAnimation(Tokens.Motion.base) { anchor = nil }
    }

    // MARK: Year register

    private var yearsList: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            ForEach(years, id: \.self) { year in
                yearSection(year)
            }
        }
    }

    private func yearSection(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text(String(year)).typeMeta()
                Spacer()
                if ReflectionStore.shared.consent == "yes" {
                    Button {
                        let corpus = ReflectionStore.corpus(from: context)
                        wrappedSignal = Reflect.yearlySignal(year: year, corpus: corpus)
                    } label: {
                        Text("Your year →").typeMetaSmall()
                    }
                    .buttonStyle(.plain)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.md, alignment: .topLeading), count: 3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Space.lg) {
                ForEach(1...12, id: \.self) { month in
                    let ref = MonthRef(year: year, month: month)
                    miniMonth(ref)
                }
            }
        }
    }

    private func miniMonth(_ ref: MonthRef) -> some View {
        let counts = monthCounts[ref.key] ?? [:]
        let mini = Tokens.DotSize.year
        let gap = Tokens.DotSize.gapYear
        let columns = Array(repeating: GridItem(.fixed(mini), spacing: gap), count: Tokens.DotSize.gridCols)

        return VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(1...daysIn(ref), id: \.self) { day in
                    CalDot(ref: ref, day: day, size: mini,
                           written: counts[day] != nil,
                           isToday: false, count: 0, ns: morph)
                }
            }
            .accessibilityHidden(true)
            Text(DayFormat.monthAbbr(ref.month)).typeMetaSmall()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !counts.isEmpty || isCurrentMonth(ref) else { return }
            open(ref)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DayFormat.monthName(ref.month)) \(String(ref.year)), \(counts.count) days written")
        .accessibilityAddTraits(counts.isEmpty && !isCurrentMonth(ref) ? [] : .isButton)
    }

    // MARK: Month register — the year's months, scrollable, anchored

    private func monthsList(year: Int) -> some View {
        LazyVStack(alignment: .leading, spacing: Tokens.Space.xxl) {
            if !singleMonthRoot {
                Button(action: close) {
                    Text("← \(String(year))").typeMeta()
                }
                .buttonStyle(.plain)
            }
            ForEach(1...12, id: \.self) { month in
                let ref = MonthRef(year: year, month: month)
                bigMonth(ref)
                    .id(ref.key)
            }
        }
        .scrollTargetLayout()
    }

    private func bigMonth(_ ref: MonthRef) -> some View {
        let counts = monthCounts[ref.key] ?? [:]
        let cell: CGFloat = 42
        let columns = Array(repeating: GridItem(.fixed(cell), spacing: Tokens.Space.xs), count: Tokens.DotSize.gridCols)
        let today = todayDay(ref)

        return VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("\(DayFormat.monthName(ref.month)) \(String(ref.year))")
                .typeTitle()

            LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
                ForEach(1...daysIn(ref), id: \.self) { day in
                    let count = counts[day] ?? 0
                    let isToday = day == today
                    CalDot(ref: ref, day: day,
                           size: isToday ? 40 : 34,
                           written: count > 0,
                           isToday: isToday, count: count, ns: morph)
                        .frame(width: cell, height: cell)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if count > 0 {
                                navigateDay = String(format: "%04d-%02d-%02d", ref.year, ref.month, day)
                            }
                        }
                        .accessibilityLabel(dayLabel(ref, day: day, count: count, isToday: isToday))
                        .accessibilityAddTraits(count > 0 ? .isButton : [])
                }
            }
        }
    }

    // MARK: Data

    private func load() {
        var counts: [String: [Int: Int]] = [:]
        var yearSet = Set<Int>()
        for key in EntryStore.daysWithEntries(in: context) {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let mk = String(format: "%04d-%02d", parts[0], parts[1])
            counts[mk, default: [:]][parts[2]] = EntryStore.entries(forDay: key, in: context).count
            yearSet.insert(parts[0])
        }
        let now = Calendar.current.dateComponents([.year, .month], from: .now)
        yearSet.insert(now.year!)
        monthCounts = counts
        years = yearSet.sorted(by: >)

        // The dynamic register: with less than a month of entries, the big
        // single month IS the calendar — no daunting empty year behind it.
        if counts.keys.count <= 1 {
            let ref = counts.keys.first
                .flatMap { k -> MonthRef? in
                    let p = k.split(separator: "-").compactMap { Int($0) }
                    return p.count == 2 ? MonthRef(year: p[0], month: p[1]) : nil
                } ?? MonthRef(year: now.year!, month: now.month!)
            singleMonthRoot = true
            anchor = ref
            scrolledMonth = ref.key
        } else {
            singleMonthRoot = false
        }
    }

    private func daysIn(_ ref: MonthRef) -> Int {
        let cal = Calendar.current
        let date = cal.date(from: DateComponents(year: ref.year, month: ref.month, day: 1))!
        return cal.range(of: .day, in: .month, for: date)!.count
    }

    private func isCurrentMonth(_ ref: MonthRef) -> Bool {
        let c = Calendar.current.dateComponents([.year, .month], from: .now)
        return c.year == ref.year && c.month == ref.month
    }

    private func todayDay(_ ref: MonthRef) -> Int? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return (c.year == ref.year && c.month == ref.month) ? c.day : nil
    }

    private func dayLabel(_ ref: MonthRef, day: Int, count: Int, isToday: Bool) -> String {
        var label = "\(DayFormat.monthName(ref.month)) \(day)"
        if isToday { label += ", today" }
        if count > 0 { label += ", \(count) \(count == 1 ? "entry" : "entries")" }
        return label
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